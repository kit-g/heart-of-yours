import 'dart:async';

import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/commands.dart';
import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

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
///
/// And it listens (#141): the rest buttons on the lock screen send the same
/// commands the watch does, applied by the same applier. The surface has
/// already shown what the button did; the snapshot sent after the command
/// confirms it, or corrects a command that turned out stale.
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
  StreamSubscription<WatchCommand>? _commands;

  /// Commands that arrived before the active workout was loaded — a cold
  /// start from a lock-screen button — applied once it is.
  final _waiting = <WatchCommand>[];

  /// What the surface is showing, as far as this process knows.
  OngoingWorkout? _shown;

  /// Whether [OngoingWorkoutSurface.end] has run since the last show. Starts
  /// false: a previous process may have left a workout on the lock screen,
  /// and the first time there is definitely no active workout it goes.
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    if (widget.surface case OngoingWorkoutSurface surface) {
      _commands = surface.commands.listen(_onCommand);
      surface.takeCommands().then((commands) => commands.forEach(_onCommand));
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
    _commands?.cancel();
    _workouts?.removeListener(_sync);
    _alarms?.removeListener(_sync);
    super.dispose();
  }

  /// A button on the lock screen (#141). Only while the lock screen is on —
  /// a button on a surface the user switched off since is a stray — and only
  /// once the active workout is known, before which it waits.
  void _onCommand(WatchCommand command) {
    if (!mounted || !Preferences.of(context).lockScreenWorkout) return;
    if (!(_workouts?.hasResolvedActiveWorkout ?? false)) {
      _waiting.add(command);
      return;
    }
    applyWorkoutCommand(context, command);
    // the surface showed the button's effect before asking; whatever came of
    // it, the state as the app has it is sent — including a stale one's
    // "nothing changed", which puts the surface right
    _shown = null;
    _sync();
  }

  void _sync() {
    final surface = widget.surface;
    if (surface == null || !mounted) return;

    if (_waiting.isNotEmpty && (_workouts?.hasResolvedActiveWorkout ?? false)) {
      final waiting = [..._waiting];
      _waiting.clear();
      waiting.forEach(_onCommand);
      return;
    }

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
    return ongoingWorkoutOf(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The active workout, summarised as finished copy for the surfaces outside the
/// app: the lock screen above, and the watch (`navigation/watch.dart`). Null
/// when there is no active workout. Reads, never watches — each caller decides
/// what it listens to.
OngoingWorkout? ongoingWorkoutOf(BuildContext context) {
  final workouts = Workouts.of(context);
  final workout = workouts.activeWorkout;
  if (workout == null) return null;

  final l = L.of(context);
  final alarms = Alarms.of(context);
  final stopwatch = workouts.stopwatch;
  final timing = Preferences.of(context).isOn(.setStopwatch) && stopwatch.isRunning;
  final timedExercise = timing ? workout.where((exercise) => exercise.any(stopwatch.isTiming)).firstOrNull : null;
  final upNext = switch (timedExercise) {
    WorkoutExercise exercise => (
      exercise: exercise,
      set: exercise.firstWhere(stopwatch.isTiming),
      number: exercise.toList().indexWhere(stopwatch.isTiming) + 1,
    ),
    null => upNextIn(workout, after: workouts.latestMarkedSet),
  };

  return (
    workoutId: workout.id,
    startedAt: workout.start,
    clockStart: workouts.clockStart ?? workout.start,
    pausedAt: workouts.pausedAt,
    pausedLabel: l.workoutPaused,
    title: switch (workout.name) {
      String name when name.isNotEmpty => name,
      _ => l.defaultWorkoutName(),
    },
    exercise: upNext?.exercise.exercise.name ?? '',
    next: switch (upNext) {
      // the stopwatch row names the set being timed; it is not "next"
      _ when timing => '',
      (set: ExerciseSet set, :int number, exercise: _) => nextSetLine(context, set, number),
      (set: null, number: _, exercise: _) => l.ongoingWorkoutAllDone,
      null => '',
    },
    stopwatch: switch ((timing, stopwatch.startedAt, upNext?.number)) {
      (true, DateTime start, int number) => (
        start: start,
        pausedAt: stopwatch.pausedAt,
        label: switch (stopwatch.isPaused) {
          true => '${l.ongoingWorkoutStopwatch(number)} · ${l.stopwatchPaused}',
          false => l.ongoingWorkoutStopwatch(number),
        },
      ),
      _ => null,
    },
    rest: switch ((timing, alarms.activeExerciseEnd, alarms.activeExerciseTotal)) {
      (false, DateTime end, num total) => (
        start: end.subtract(Duration(seconds: total.toInt())),
        end: end,
        label: l.ongoingWorkoutRest,
        over: l.restComplete,
        minus: l.subtractSeconds,
        plus: l.addSeconds,
        skip: l.skip,
      ),
      _ => null,
    },
    preset: AppTheme.of(context).preset,
    channel: l.ongoingWorkoutChannel,
  );
}

/// The "Next:" line for [set], the [number]th of its exercise: "Next: set 2 ·
/// 60 kg × 5". Also sent for every set to the watch (#206), which moves on by
/// itself while the phone is out of reach.
String nextSetLine(BuildContext context, ExerciseSet set, int number) {
  final l = L.of(context);
  return switch (_describe(context, set, l)) {
    String detail => l.ongoingWorkoutNextSetDetail(number, detail),
    null => l.ongoingWorkoutNextSet(number),
  };
}

/// What the next set holds, in the units its exercise is shown in; null
/// when nothing is filled in yet.
String? _describe(BuildContext context, ExerciseSet set, L l) {
  final formats = RecordFormats(
    l: l,
    prefs: Preferences.of(context),
    unit: Exercises.of(context).unitFor(set.exercise.id),
    category: set.exercise.category,
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
