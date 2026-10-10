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
  final prefs = Preferences.of(context);
  final workouts = Workouts.of(context);
  final watch = switch (prefs.isOn(.watchApp)) {
    true => watchLink(Theme.of(context).platform),
    _ => null,
  };
  final copy = restNotificationCopy(context, exercise, next: workouts.nextIncomplete);
  // and one scheduled before the watch took over must not fire either
  if (workouts.activeWorkout?.id case String id when await watch?.measures(id) ?? false) {
    return cancelExerciseNotification();
  }
  return scheduleExerciseNotification(
    copy.exerciseId,
    when,
    title: copy.title,
    body: copy.body,
    subtitle: copy.subtitle,
  );
}

/// The "rest complete" notification's words: the title, the set that comes
/// [next] as its body (null with nothing to say), and a subtitle naming the
/// exercise it is for — "Next: …" the next one, or [exercise] just worked,
/// by its name alone, when nothing is left. Also what the lock screen schedules itself when its Done button
/// starts a rest with the app gone (#246).
({String exerciseId, String title, String? body, String subtitle}) restNotificationCopy(
  BuildContext context,
  WorkoutExercise exercise, {
  (WorkoutExercise, ExerciseSet)? next,
}) {
  final L(:restComplete, :restCompleteBody, :weightedSetRepresentation, :kg, :lbs) = L.of(context);
  final prefs = Preferences.of(context);
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
  return (
    exerciseId: nextExercise.id,
    title: restComplete,
    body: body,
    // "Next:" only when something is next: with every set done, the exercise
    // just worked is named as itself
    subtitle: switch (next) {
      (WorkoutExercise(:final exercise), _) => restCompleteBody(exercise.name),
      null => exercise.exercise.name,
    },
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
