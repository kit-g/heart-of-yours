import 'dart:async';

import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart/presentation/widgets/workout/rest.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show finishWorkout;
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the watch app showing the active workout (#182), and applies what the
/// user does on it (#183).
///
/// Opt-in, and the ask is the watch itself (`docs/opt-in.md`): opening Heart on
/// the watch for the first time is the yes. Until then [Feature.watchApp] is
/// unasked and nothing is sent — a watch app that Automatic App Install
/// put there on its own hears nothing from the phone. Switched off, the watch
/// is told once, so it can say so instead of showing a stale workout.
///
/// The phone is the only writer. A tick on the watch is a request that lands
/// here and goes through the same `Workouts` calls a tick on the phone does;
/// the watch learns the outcome from the state sent back, never by guessing.
///
/// Like the lock screen it speaks only when what the watch shows *changes*;
/// the rest countdown ticks on the watch.
class WatchPresenter extends StatefulWidget {
  final Widget child;

  /// Null turns this into a pass-through (Android, web, tests).
  final WatchLink? link;

  const new({super.key, required this.child, required this.link});

  @override
  State<WatchPresenter> createState() => _WatchPresenterState();
}

class _WatchPresenterState extends State<WatchPresenter> {
  Workouts? _workouts;
  Alarms? _alarms;
  StreamSubscription<WatchEvent>? _events;
  StreamSubscription<WatchCommand>? _commands;

  /// What the watch was last sent, as far as this process knows.
  WatchState? _sent;

  /// Commands that arrived before the active workout was loaded — a cold start
  /// woken by the watch — applied once it is.
  final _waiting = <WatchCommand>[];

  /// What the watch logged while the phone was out of reach (#206) arrives as
  /// a batch once it is back, maybe while nobody is looking at the watch. It is
  /// told apart by age — every command says when it happened — and the user is
  /// told it is coming, then what came.
  static const _late = Duration(seconds: 10);

  /// How long a batch is quiet before it counts as all in.
  static const _quiet = Duration(milliseconds: 1500);

  /// How long "catching up" waits for a batch the system said was coming.
  static const _patience = Duration(seconds: 30);

  /// Sets the batch so far ticked.
  int _arrived = 0;
  Timer? _settle;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _catchingUp;

  @override
  void initState() {
    super.initState();
    if (widget.link case WatchLink link) {
      _events = link.events.listen(_onEvent);
      _commands = link.commands.listen(_onCommand);
      // opened while the phone app wasn't running: the yes still counts
      link.takeOpened().then((opened) {
        if (opened) _onEvent(.opened);
      });
      link.takeCommands().then((commands) => commands.forEach(_onCommand));
      link.contentPending().then((pending) {
        if (pending) _catchUp();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final alarms = Alarms.of(context);
    if (!identical(alarms, _alarms)) {
      _alarms?.removeListener(_sync);
      _alarms = alarms..addListener(_sync);
    }
    // registered here so a language, theme or unit change re-sends the copy
    L.of(context);
    AppTheme.watch(context);
    Preferences.watch(context);
    // a rest timer set mid-workout is the rest the watch starts on its own
    Timers.watch(context);
    _sync();
  }

  @override
  void dispose() {
    _events?.cancel();
    _commands?.cancel();
    _workouts?.removeListener(_sync);
    _alarms?.removeListener(_sync);
    _settle?.cancel();
    super.dispose();
  }

  void _onEvent(WatchEvent event) {
    if (!mounted) return;
    switch (event) {
      case .opened:
        // the yes, if nothing was answered before; a no from Settings stands
        final preferences = Preferences.of(context);
        if (preferences.featureAnswer(.watchApp) == .unasked) {
          preferences.setFeature(.watchApp, on: true);
          Analytics.of(context).watchAppSwitched(on: true, fromWatch: true);
        }
        // heard live, so the note the native side keeps for a later launch is spent
        widget.link?.takeOpened();
        _resend();
      case .changed:
        break;
      case .catchingUp:
        _catchUp();
    }
  }

  void _onCommand(WatchCommand command) {
    if (!mounted || !Preferences.of(context).isOn(.watchApp)) return;
    if (!(_workouts?.hasResolvedActiveWorkout ?? false)) {
      _waiting.add(command);
      return;
    }

    final workouts = Workouts.of(context);
    final workout = workouts.activeWorkout;
    // a command about a workout that is over, or another one, changes nothing
    if (workout == null || workout.id != command.workoutId) return _resend();

    switch (command) {
      case WatchComplete(:final setId, :final weight, :final reps, :final at):
        final ticked = _complete(workouts, workout, setId, weight: weight, reps: reps, at: at);
        _landed(command, ticked: ticked);
      case WatchEditSet(:final setId, :final weight, :final reps):
        // new values for a set gone back to; it keeps its tick
        if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set)) {
          workouts.editSet(set, weight: _kilograms(exercise, weight), reps: reps);
        }
      case WatchUntickSet(:final setId):
        if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set) when set.isCompleted) {
          workouts.markSetAsIncomplete(exercise, set);
        }
      case WatchSkipRest():
        Alarms.of(context).stopActiveExerciseTimer();
      case WatchFinishWorkout(:final at):
        // the watch offers Finish only with nothing left to tick; if a set was
        // added on the phone since, that is the phone's to finish
        if (workout.isValid && upNextIn(workout, after: workouts.latestMarkedSet)?.set == null) {
          // the phone's own finish: it saves, writes Health, shows the summary,
          // and the state it leaves — no workout — is what the watch hears next
          // — ended when the user confirmed it, which a Finish queued while
          // the phone was out of reach (#206) says was a while ago
          _landed(command);
          finishWorkout(context, workouts, at: at);
          return;
        }
      case WatchAdjustRest(:final seconds):
        final alarms = Alarms.of(context);
        final resting = workout.where((exercise) => exercise.id == alarms.activeExerciseId).firstOrNull;
        alarms.adjustActiveExerciseTime(
          seconds,
          rescheduleNotification: switch (resting) {
            WorkoutExercise exercise => (when) => scheduleRestNotification(context, exercise, when),
            null => null,
          },
        );
    }
    // whatever happened, the watch is waiting to hear it — even "nothing"
    _resend();
  }

  /// Ticks [setId] the way the set row's tick does (`set_item.dart`): the
  /// values the watch showed become the set's, converted from the unit they
  /// were shown in, and the exercise's rest starts — without the countdown
  /// dialog, which nobody is looking at.
  bool _complete(Workouts workouts, Workout workout, String setId, {double? weight, int? reps, DateTime? at}) {
    // gone, or ticked already (a double tap, or the phone got there first)
    if (_find(workout, setId) case (WorkoutExercise exercise, ExerciseSet set) when !set.isCompleted) {
      if (weight != null || reps != null) {
        workouts.editSet(set, weight: _kilograms(exercise, weight), reps: reps);
      }
      if (set.canBeCompleted) {
        workouts.markSetAsComplete(exercise, set);
        startRest(context, exercise, since: at);
        return true;
      }
    }
    return false;
  }

  /// The system has watch content for the phone it has not delivered yet:
  /// say so until it lands, or until it plainly is not coming.
  void _catchUp() {
    if (_catchingUp != null || !mounted || !Preferences.of(context).isOn(.watchApp)) return;
    _catchingUp = ScaffoldMessenger.of(context).snack(L.of(context).watchCatchingUp, duration: _patience);
    _settle ??= Timer(_patience, _caughtUp);
  }

  /// A command landed; if it is a late one, the batch is not over yet.
  void _landed(WatchCommand command, {bool ticked = false}) {
    if (command.at case DateTime at when DateTime.now().difference(at) >= _late) {
      // the first of a batch nobody announced: say so while the rest lands
      _catchUp();
      if (ticked) _arrived++;
      _settle?.cancel();
      _settle = Timer(_quiet, _caughtUp);
    }
  }

  /// The batch is in: what came, in place of "catching up".
  void _caughtUp() {
    _settle = null;
    if (!mounted) return;
    _catchingUp?.close();
    _catchingUp = null;
    if (_arrived > 0) snack(context, L.of(context).watchSetsArrived(_arrived));
    _arrived = 0;
  }

  (WorkoutExercise, ExerciseSet)? _find(Workout workout, String setId) {
    return workout
        .expand((exercise) => exercise.map((set) => (exercise, set)))
        .where((pair) => pair.$2.id == setId)
        .firstOrNull;
  }

  /// The unit [exercise] is shown in: its own override, or the app's.
  MeasurementUnit _unit(WorkoutExercise exercise) {
    return Exercises.of(context).unitFor(exercise.exercise.id) ?? Preferences.of(context).weightUnit;
  }

  /// A weight the watch sent, in the unit it was shown in, as stored.
  double? _kilograms(WorkoutExercise exercise, double? weight) {
    return switch ((weight, _unit(exercise))) {
      (double weight, .imperial) => weight.asKilograms,
      (double weight, .metric) => weight,
      (null, _) => null,
    };
  }

  /// Whether [exercise]'s sets take a weight, and whether they take a count.
  (bool weighted, bool counted) _measures(WorkoutExercise exercise) {
    final weighted = switch (exercise.exercise.category) {
      .barbell || .dumbbell || .machine || .assistedBodyWeight || .weightedBodyWeight => true,
      _ => false,
    };
    return (weighted, weighted || exercise.exercise.category == .repsOnly);
  }

  String _unitLabel(WorkoutExercise exercise, L l) {
    return switch (_unit(exercise)) {
      .imperial => l.lbs,
      .metric => l.kg,
    };
  }

  /// One Digital Crown detent of weight: the smallest plate step in the unit.
  double _step(WorkoutExercise exercise) {
    return switch (_unit(exercise)) {
      .imperial => 5,
      .metric => 2.5,
    };
  }

  /// [set]'s weight as the watch shows it: in [exercise]'s unit, 0 when not
  /// filled in, null when the set takes none.
  double? _shownWeight(WorkoutExercise exercise, ExerciseSet set) {
    return switch ((_measures(exercise).$1, set.weight)) {
      (true, double weight) => Preferences.of(context).weightValue(weight, unit: _unit(exercise)),
      (true, null) => 0,
      (false, _) => null,
    };
  }

  int? _shownReps(WorkoutExercise exercise, ExerciseSet set) {
    return switch (_measures(exercise).$2) {
      true => set.reps ?? 0,
      false => null,
    };
  }

  /// The whole workout, for the watch's second page: every set, done or not.
  List<WatchExercise> _exercises(L l) {
    final workout = Workouts.of(context).activeWorkout;
    if (workout == null) return const [];
    return [
      for (final exercise in workout)
        (
          id: exercise.id,
          name: exercise.exercise.name,
          unit: switch (_measures(exercise).$1) {
            true => _unitLabel(exercise, l),
            false => null,
          },
          step: _step(exercise),
          weighted: _measures(exercise).$1,
          counted: _measures(exercise).$2,
          rest: Timers.of(context)[exercise.exercise.id],
          sets: [
            for (final (index, set) in exercise.indexed)
              (
                id: set.id,
                weight: _shownWeight(exercise, set),
                reps: _shownReps(exercise, set),
                done: set.isCompleted,
                position: l.watchSetPosition(index + 1, exercise.length),
                previous: _lastTime(
                  exercise,
                  index,
                  weighted: _measures(exercise).$1,
                  unit: _unitLabel(exercise, l),
                  l: l,
                ),
                next: nextSetLine(context, set, index + 1),
              ),
          ],
        ),
    ];
  }

  /// Sends the current state even if it is what was sent last: the watch asked,
  /// or is waiting on a command, and has nothing to show for it otherwise.
  void _resend() {
    _sent = null;
    _sync();
  }

  void _sync() {
    final link = widget.link;
    if (link == null || !mounted) return;

    if (_waiting.isNotEmpty && (_workouts?.hasResolvedActiveWorkout ?? false)) {
      final waiting = [..._waiting];
      _waiting.clear();
      waiting.forEach(_onCommand);
      return;
    }

    final state = _state();
    if (state == null || state == _sent) return;
    _sent = state;
    link.send(state);
  }

  WatchState? _state() {
    final l = L.of(context);
    return switch (Preferences.of(context).featureAnswer(.watchApp)) {
      // never opened on the watch: nothing is said to it at all
      .unasked || .pending => null,
      .off => WatchMessage.off(l.watchAppOff),
      .on => switch ((ongoingWorkoutOf(context), _workouts?.hasResolvedActiveWorkout ?? false)) {
        (var workout?, _) => WatchWorkout(
          workout,
          set: _upNext(l),
          exercises: _exercises(l),
          controls: _controls(l),
          activity: switch (_workouts?.activeWorkout) {
            Workout active => activityOf(active).name,
            null => null,
          },
        ),
        // "no workout" only once that is known, not while it is still loading
        (null, true) => WatchMessage.idle(l.watchAppIdle),
        (null, false) => null,
      },
    };
  }

  /// The set the watch acts on: the one "next" names, in the unit its
  /// exercise is shown in.
  WatchSet? _upNext(L l) {
    final workouts = Workouts.of(context);
    final workout = workouts.activeWorkout;
    if (workout == null) return null;
    if (upNextIn(workout, after: workouts.latestMarkedSet) case (
      :WorkoutExercise exercise,
      set: ExerciseSet set,
      :int number,
    )) {
      final (weighted, _) = _measures(exercise);
      final unitLabel = _unitLabel(exercise, l);
      return (
        exerciseId: exercise.id,
        setId: set.id,
        weight: _shownWeight(exercise, set),
        reps: _shownReps(exercise, set),
        unit: switch (weighted) {
          true => unitLabel,
          false => null,
        },
        step: _step(exercise),
        previous: _lastTime(exercise, number - 1, weighted: weighted, unit: unitLabel, l: l),
        position: l.watchSetPosition(number, exercise.length),
      );
    }
    return null;
  }

  /// The same set in the last session, as the phone's "Previous" column holds
  /// it — labelled "last time" on the watch, where "previous" would read as the
  /// set before this one. Null for anything but weights and reps, or when there
  /// was no last time.
  String? _lastTime(WorkoutExercise exercise, int index, {required bool weighted, required String unit, required L l}) {
    final prefs = Preferences.of(context);
    final value = PreviousExercises.of(context).at(exercise.exercise.id, index);
    return switch ((weighted, value)) {
      (true, {'reps': int reps, 'weight': num weight}) => l.watchLastTime(
        '${prefs.weight(weight, unit: _unit(exercise))} $unit × $reps',
      ),
      (false, {'reps': int reps}) => l.watchLastTime('$reps ${l.reps}'),
      _ => null,
    };
  }

  WatchControls _controls(L l) {
    return (
      done: l.watchSetDone,
      skip: l.skip,
      add: l.addSeconds,
      subtract: l.subtractSeconds,
      reps: l.reps,
      unreachable: l.watchPhoneUnreachable,
      heartRate: l.watchHeartRate,
      bpm: l.healthBpm,
      energy: l.healthActiveEnergy,
      kcal: l.healthKilocalories,
      finish: l.finish,
      finishTitle: l.finishWorkoutWarningTitle,
      finishConfirm: l.readyToFinish,
      finishCancel: l.notReadyToFinish,
      save: l.watchSave,
      notDone: l.watchSetNotDone,
      restLabel: l.ongoingWorkoutRest,
      restOver: l.restComplete,
      allDone: l.ongoingWorkoutAllDone,
      idle: l.watchAppIdle,
      sending: l.watchSending,
      finishedAway: l.watchFinishedAway,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
