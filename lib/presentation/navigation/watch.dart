import 'dart:async';

import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart/presentation/widgets/workout/rest.dart';
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
    _sync();
  }

  @override
  void dispose() {
    _events?.cancel();
    _commands?.cancel();
    _workouts?.removeListener(_sync);
    _alarms?.removeListener(_sync);
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
      case WatchComplete(:final setId, :final weight, :final reps):
        _complete(workouts, workout, setId, weight: weight, reps: reps);
      case WatchSkipRest():
        Alarms.of(context).stopActiveExerciseTimer();
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
  void _complete(Workouts workouts, Workout workout, String setId, {double? weight, int? reps}) {
    final found = workout
        .expand((exercise) => exercise.map((set) => (exercise, set)))
        .where((pair) => pair.$2.id == setId)
        .firstOrNull;
    // gone, or ticked already (a double tap, or the phone got there first)
    if (found case (WorkoutExercise exercise, ExerciseSet set) when !set.isCompleted) {
      if (weight != null || reps != null) {
        final unit = Exercises.of(context).unitFor(exercise.exercise.id) ?? Preferences.of(context).weightUnit;
        workouts.markEdited(set);
        set.setMeasurements(
          weight: switch ((weight, unit)) {
            (double weight, .imperial) => weight.asKilograms,
            (double weight, .metric) => weight,
            (null, _) => set.weight,
          },
          reps: reps ?? set.reps,
          duration: set.duration,
          distance: set.distance,
        );
        // the set row's field listeners do this on the phone; ticking stores
        // only the tick
        workouts.storeMeasurements(set);
      }
      if (set.canBeCompleted) {
        workouts.markSetAsComplete(exercise, set);
        startRest(context, exercise);
      }
    }
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
      final prefs = Preferences.of(context);
      final unit = Exercises.of(context).unitFor(exercise.exercise.id) ?? prefs.weightUnit;
      final weighted = switch (exercise.exercise.category) {
        .barbell || .dumbbell || .machine || .assistedBodyWeight || .weightedBodyWeight => true,
        _ => false,
      };
      final counted = weighted || exercise.exercise.category == .repsOnly;
      final unitLabel = switch (unit) {
        .imperial => l.lbs,
        .metric => l.kg,
      };

      return (
        exerciseId: exercise.id,
        setId: set.id,
        weight: switch ((weighted, set.weight)) {
          (true, double weight) => prefs.weightValue(weight, unit: unit),
          (true, null) => 0,
          (false, _) => null,
        },
        reps: switch (counted) {
          true => set.reps ?? 0,
          false => null,
        },
        unit: switch (weighted) {
          true => unitLabel,
          false => null,
        },
        step: switch (unit) {
          .imperial => 5,
          .metric => 2.5,
        },
        previous: _previous(exercise, number - 1, weighted: weighted, unit: unitLabel, l: l),
      );
    }
    return null;
  }

  /// The same set in the last session, as the phone's "Previous" column shows
  /// it; null for anything but weights and reps, or when there was none.
  String? _previous(WorkoutExercise exercise, int index, {required bool weighted, required String unit, required L l}) {
    final prefs = Preferences.of(context);
    final override = Exercises.of(context).unitFor(exercise.exercise.id);
    final value = PreviousExercises.of(context).at(exercise.exercise.id, index);
    return switch ((weighted, value)) {
      (true, {'reps': int reps, 'weight': num weight}) =>
        '${l.previous}: ${prefs.weight(weight, unit: override)} $unit x $reps',
      (false, {'reps': int reps}) => '${l.previous}: $reps ${l.reps}',
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
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
