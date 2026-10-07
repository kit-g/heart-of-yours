import 'dart:async';

import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/presentation/navigation/commands.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show SetTypeCopy;
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

  /// The preferences read, the active workout known, and the rest a killed
  /// process left running picked up (#141): a command judged before any of
  /// these — the feature not yet read, no rest yet — would be dropped wrongly.
  bool get _ready {
    return Preferences.of(context).isInitialized &&
        (_workouts?.hasResolvedActiveWorkout ?? false) &&
        (_alarms?.hasRestored ?? true);
  }

  void _onCommand(WatchCommand command) {
    if (!mounted) return;
    if (!_ready) {
      _waiting.add(command);
      return;
    }
    if (!Preferences.of(context).isOn(.watchApp)) return;

    final outcome = applyWorkoutCommand(context, command);
    // a tick, landed or not, may be the first of a late batch (#206)
    if (command is WatchComplete) _landed(command, ticked: outcome == .ticked);
    switch (outcome) {
      // the finish's own flow answers: the summary, and "no workout" next
      case .finished:
        _landed(command);
      // whatever happened, the watch is waiting to hear it — even "nothing"
      case .applied || .ticked || .stale:
        _resend();
    }
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

  /// The unit [exercise] is shown in: its own override, or the app's.
  MeasurementUnit _unit(WorkoutExercise exercise) => unitOf(context, exercise);

  /// Whether [exercise]'s sets take a weight, and whether they take a count.
  (bool weighted, bool counted) _measures(WorkoutExercise exercise) {
    final weighted = switch (exercise.exercise.category) {
      // a carry's or a hold's load goes on the crown; its distance or time is
      // the phone's, as a run's is
      .barbell ||
      .dumbbell ||
      .machine ||
      .assistedBodyWeight ||
      .weightedBodyWeight ||
      .weightedDistance ||
      .weightedDuration => true,
      .repsOnly || .cardio || .duration => false,
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
                mark: _mark(exercise, index, l),
                type: _type(exercise, index, l),
                position: _position(exercise, index, l),
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

    if (_waiting.isNotEmpty && _ready) {
      final waiting = [..._waiting];
      _waiting.clear();
      // off the build this may have been called from (a dependency changed):
      // applying a command repaints the app
      scheduleMicrotask(() => waiting.forEach(_onCommand));
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
          // off, or at the pause limit, the watch shows no Pause; Resume while
          // paused, whatever the limit
          pausable:
              Preferences.of(context).isOn(.pauseWorkout) &&
              ((_workouts?.isPaused ?? false) || (_workouts?.canPause ?? false)),
          pauses: [
            for (final pause in _workouts?.activeWorkout?.pauses ?? const <WorkoutPause>[])
              (start: pause.start, end: pause.end),
          ],
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
        position: _position(exercise, number - 1, l),
      );
    }
    return null;
  }

  /// The set at [index] in [exercise] as the phone's set column marks it
  /// (#236): a plain set by its number among the plain ones, any other by its
  /// letter — W, 1, 2, F.
  String _mark(WorkoutExercise exercise, int index, L l) {
    return switch (exercise.elementAt(index).setType) {
      .normal => '${_plainBefore(exercise, index) + 1}',
      SetType type => type.letter(l),
    };
  }

  /// What kind of set it is, spelled out for VoiceOver; null for a plain one.
  String? _type(WorkoutExercise exercise, int index, L l) {
    return switch (exercise.elementAt(index).setType) {
      .normal => null,
      SetType type => type.copy(l),
    };
  }

  /// "Set 2 of 3", counting plain sets as the phone numbers them, or the
  /// type's name for a warm-up, drop or failure set.
  String _position(WorkoutExercise exercise, int index, L l) {
    return switch (exercise.elementAt(index).setType) {
      .normal => l.watchSetPosition(
        _plainBefore(exercise, index) + 1,
        exercise.where((each) => each.setType == .normal).length,
      ),
      SetType type => type.copy(l),
    };
  }

  int _plainBefore(WorkoutExercise exercise, int index) {
    return exercise.take(index).where((each) => each.setType == .normal).length;
  }

  /// The same set in the last session, as the phone's "Previous" column holds
  /// it — labelled "last time" on the watch, where "previous" would read as the
  /// set before this one. Null for anything but weights and reps, or when there
  /// was no last time.
  String? _lastTime(WorkoutExercise exercise, int index, {required bool weighted, required String unit, required L l}) {
    final prefs = Preferences.of(context);
    final value = PreviousExercises.of(context).matching(exercise, index);
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
      pause: l.watchPause,
      resume: l.watchResume,
      paused: l.workoutPaused,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
