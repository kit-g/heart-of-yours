import 'package:flutter/material.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Keeps the active workout on the lock screen (#133): the iOS Live Activity
/// and Dynamic Island, Android's ongoing notification. Only when the user has
/// turned it on (`Preferences.lockScreenWorkout`, off by default).
///
/// Sits below Localizations (MaterialApp's builder) because everything it
/// sends is finished copy. It speaks only when the summary *changes* — a set
/// ticked, a rest started, adjusted or over, the language or theme switched —
/// never on a tick: both platforms count the clocks themselves. Workouts
/// notifies on every keystroke in a set row, so the summary is compared
/// before anything crosses the platform channel.
class OngoingWorkoutPresenter extends StatefulWidget {
  final Widget child;

  /// Where the workout is shown; null turns this into a pass-through (web,
  /// desktop, tests, a build with local notifications off).
  final OngoingWorkoutSurface? surface;

  const new({super.key, required this.child, required this.surface});

  @override
  State<OngoingWorkoutPresenter> createState() => _OngoingWorkoutPresenterState();
}

class _OngoingWorkoutPresenterState extends State<OngoingWorkoutPresenter> {
  Workouts? _workouts;
  Alarms? _alarms;

  /// What the surface is showing, as far as this process knows.
  OngoingWorkout? _shown;

  /// Whether [OngoingWorkoutSurface.end] has run since the last show. Starts
  /// false: a previous process may have left a workout on the lock screen,
  /// and the first time there is definitely no active workout it goes.
  bool _ended = false;

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
    _workouts?.removeListener(_sync);
    _alarms?.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final surface = widget.surface;
    if (surface == null || !mounted) return;

    switch (_snapshot()) {
      case OngoingWorkout workout when workout != _shown:
        _shown = workout;
        _ended = false;
        surface.show(workout);
      case OngoingWorkout():
        break;
      case null when _shown != null || (!_ended && (_workouts?.hasResolvedActiveWorkout ?? false)):
        _shown = null;
        _ended = true;
        surface.end();
      case null:
        break;
    }
  }

  OngoingWorkout? _snapshot() {
    // opt-in: off reads as "no workout", which also takes down one already up
    if (!Preferences.of(context).lockScreenWorkout) return null;
    final workout = _workouts?.activeWorkout;
    if (workout == null) return null;

    final l = L.of(context);
    final upNext = upNextIn(workout, after: _workouts?.latestMarkedSet);

    return (
      workoutId: workout.id,
      startedAt: workout.start,
      title: switch (workout.name) {
        String name when name.isNotEmpty => name,
        _ => l.defaultWorkoutName(),
      },
      exercise: upNext?.exercise.exercise.name ?? '',
      next: switch (upNext) {
        (set: ExerciseSet set, :int number, exercise: _) => switch (_describe(set, l)) {
          String detail => l.ongoingWorkoutNextSetDetail(number, detail),
          null => l.ongoingWorkoutNextSet(number),
        },
        (set: null, number: _, exercise: _) => l.ongoingWorkoutAllDone,
        null => '',
      },
      rest: switch ((_alarms?.activeExerciseEnd, _alarms?.activeExerciseTotal)) {
        (DateTime end, num total) => (
          start: end.subtract(Duration(seconds: total.toInt())),
          end: end,
          label: l.ongoingWorkoutRest,
          over: l.restComplete,
        ),
        _ => null,
      },
      preset: AppTheme.of(context).preset,
      channel: l.ongoingWorkoutChannel,
    );
  }

  /// What the next set holds, in the units its exercise is shown in; null
  /// when nothing is filled in yet.
  String? _describe(ExerciseSet set, L l) {
    final formats = RecordFormats(
      l: l,
      prefs: Preferences.of(context),
      unit: Exercises.of(context).unitFor(set.exercise.id),
    );
    final weight = switch (set.weight) {
      double weight when weight > 0 => formats.weight(weight),
      _ => null,
    };
    final reps = switch (set.reps) {
      int reps when reps > 0 => reps,
      _ => null,
    };
    final distance = switch (set.distance) {
      double distance when distance > 0 => formats.distance(distance),
      _ => null,
    };
    final duration = switch (set.duration) {
      int seconds when seconds > 0 => formats.time(seconds),
      _ => null,
    };

    return switch ((weight, reps, distance, duration)) {
      (String weight, int reps, _, _) => l.weightedSetRepresentation(weight, reps),
      (String weight, null, _, _) => weight,
      (null, int reps, _, _) => '× $reps',
      (null, null, String distance, String duration) => '$distance · $duration',
      (null, null, String distance, null) => distance,
      (null, null, null, String duration) => duration,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
