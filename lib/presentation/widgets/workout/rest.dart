import 'package:flutter/widgets.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';

/// Schedules the "rest complete" notification for a rest that ends at [when],
/// naming the set that comes next. [exercise] is the one just worked — the
/// fallback when nothing is left to do.
Future<void> scheduleRestNotification(BuildContext context, WorkoutExercise exercise, DateTime when) {
  final L(:restComplete, :restCompleteBody, :weightedSetRepresentation, :kg, :lbs) = L.of(context);
  final prefs = Preferences.of(context);
  final next = Workouts.of(context).nextIncomplete;
  // Honour the next exercise's per-exercise unit, falling back to the global
  // weight setting — the notification used to always emit the raw metric
  // value with an "lbs" label regardless of preference.
  final unit = switch (next?.$1.exercise.id) {
    String id => Exercises.of(context).unitFor(id) ?? prefs.weightUnit,
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
void startRest(BuildContext context, WorkoutExercise exercise) {
  final total = Timers.of(context)[exercise.exercise.id];
  if (total == null) return;

  final alarms = Alarms.of(context);
  if (alarms.remainsInActiveExercise != null && alarms.activeExerciseId == exercise.id) return;

  alarms.startActiveExerciseTimer(
    total,
    exerciseId: exercise.id,
    scheduleNotification: (when) => scheduleRestNotification(context, exercise, when),
  );
}
