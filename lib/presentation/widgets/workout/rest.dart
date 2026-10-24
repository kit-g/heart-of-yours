import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// How long [exercise] rests after a set, in seconds: the user's own timer for
/// it, otherwise what its program session plans (#349) while Programs is on,
/// and otherwise its kind's default rest (#174) while that is on. The user's
/// word wins: a timer they set is a choice, a plan a default, and the default
/// rest the most general of all.
///
/// Every surface that starts or shows a rest reads it here — the countdown,
/// the lock screen, the Live Activity, the watch — so the default reaches them
/// all.
int? restFor(BuildContext context, WorkoutExercise exercise, {bool listen = false}) {
  final timers = Provider.of<Timers>(context, listen: listen);
  final preferences = Provider.of<Preferences>(context, listen: listen);
  final planned = switch (preferences.isOn(.programs)) {
    true => exercise.rest,
    false => null,
  };
  return timers[exercise.exercise.id] ?? planned ?? _defaultRestFor(preferences, exercise.exercise);
}

/// [exercise]'s default rest (#174), in seconds: null while the feature is
/// off, and for a kind the user set to no rest.
int? _defaultRestFor(Preferences preferences, Exercise exercise) {
  if (!preferences.isOn(.defaultRest)) return null;
  return switch (preferences.defaultRest(restKindOf(exercise))) {
    0 => null,
    final seconds => seconds,
  };
}

/// How long the rest after a set of [exercise] is, in seconds, in the active
/// workout. In a superset (#159) there is none while the round goes on, and
/// the round's rest is its last member's — where a plan puts it — or, without
/// one there, [exercise]'s own. Otherwise [restFor].
int? restAfter(BuildContext context, WorkoutExercise exercise) {
  final workout = Workouts.of(context).activeWorkout;
  return switch (workout) {
    Workout workout when workout.contains(exercise) => switch (workout.restsAs(exercise)) {
      WorkoutExercise last => restFor(context, last) ?? restFor(context, exercise),
      null => null,
    },
    _ => restFor(context, exercise),
  };
}

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

/// Starts [exercise]'s rest, if it has one ([restAfter]), the way ticking a set on
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
  final timer = restAfter(context, exercise);
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
