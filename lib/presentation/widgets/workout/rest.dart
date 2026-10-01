import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Schedules the "rest complete" notification for a rest that ends at [when],
/// naming the set that comes next. [exercise] is the one just worked — the
/// fallback when nothing is left to do.
///
/// Skipped while the watch measures this workout (#185): its workout session
/// keeps it awake to tap the wrist itself, and iOS would forward this
/// notification to the same wrist as a second tap. One owner per rest.
Future<void> scheduleRestNotification(BuildContext context, WorkoutExercise exercise, DateTime when) async {
  final L(:restComplete, :restCompleteBody, :weightedSetRepresentation, :kg, :lbs) = L.of(context);
  final prefs = Preferences.of(context);
  final workouts = Workouts.of(context);
  final next = workouts.nextIncomplete;
  final watch = switch (prefs.isOn(.watchApp)) {
    true => watchLink(Theme.of(context).platform),
    _ => null,
  };
  final exercises = Exercises.of(context);
  // Honour the next exercise's per-exercise unit, falling back to the global
  // weight setting — the notification used to always emit the raw metric
  // value with an "lbs" label regardless of preference.
  final unit = switch (next?.$1.exercise.id) {
    String id => exercises.unitFor(id) ?? prefs.weightUnit,
    null => prefs.weightUnit,
  };
  final body = switch (next?.$2) {
    ExerciseSet(:double weight, :int reps) => weightedSetRepresentation(
      '${prefs.weight(weight, unit: unit)} ${unit == MeasurementUnit.imperial ? lbs : kg}',
      reps,
    ),
    _ => null,
  };
  final nextExercise = next?.$1 ?? exercise;
  // and one scheduled before the watch took over must not fire either
  if (workouts.activeWorkout?.id case String id when await watch?.measures(id) ?? false) {
    return cancelExerciseNotification();
  }
  return scheduleExerciseNotification(
    nextExercise.id,
    when,
    title: restComplete,
    body: body,
    subtitle: restCompleteBody(nextExercise.exercise.name),
  );
}

/// Starts [exercise]'s rest, if it has a rest timer, the way ticking a set on
/// the phone does — minus the countdown dialog, for a tick that came from
/// somewhere the dialog cannot be seen (the watch, #183).
///
/// A rest already counting for this exercise is left alone; one owned by
/// another exercise is replaced, the most recent set winning — the same rule
/// as `Countdown`.
///
/// [since] is when the set was ticked, for a tick that arrives late — sent from
/// a watch while the phone was out of reach (#206): only what is left of the
/// rest runs, and a rest already over by now does not start at all.
void startRest(BuildContext context, WorkoutExercise exercise, {DateTime? since}) {
  final timer = Timers.of(context)[exercise.exercise.id];
  if (timer == null) return;
  final total = switch (since) {
    DateTime since => timer - DateTime.now().difference(since).inSeconds.clamp(0, timer),
    null => timer,
  };
  if (total <= 0) return;

  final alarms = Alarms.of(context);
  if (alarms.remainsInActiveExercise != null && alarms.activeExerciseId == exercise.id) return;

  alarms.startActiveExerciseTimer(
    total,
    exerciseId: exercise.id,
    scheduleNotification: (when) => scheduleRestNotification(context, exercise, when),
  );
}
