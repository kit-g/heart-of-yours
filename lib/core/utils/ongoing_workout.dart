import 'package:heart_models/heart_models.dart';

/// Where the user is in a workout: the exercise they are on and the set they
/// are about to do, for surfaces that summarise a session at a glance (the
/// lock screen, #133).
///
/// [number] is the set's 1-based position within its exercise, as the set
/// rows show it. [set] is null once every set in the workout is ticked —
/// [exercise] then stays on the one worked last.
typedef UpNext = ({WorkoutExercise exercise, ExerciseSet? set, int number});

/// Resolves [UpNext] for [workout], or null when it has no exercises.
///
/// Reads forward from [after], the set ticked last (`Workouts.latestMarkedSet`),
/// the way `Workouts.nextIncomplete` — the rest notification's "Next:" — does,
/// so the two agree: the next open set in that exercise, else the first open
/// set in a later exercise. Two differences, both about being right where the
/// notification only has to be plausible:
///
/// - a later exercise contributes its first *open* set, not its first set;
/// - when nothing is open after [after] it wraps to the first open set
///   anywhere — a set skipped earlier is still the next thing to do.
///
/// Without [after] (nothing ticked yet, or a cold start: the anchor lives in
/// memory, and a set's `completedAt` is never stamped by the app) it is the
/// first open set in workout order.
UpNext? upNextIn(Workout workout, {(WorkoutExercise, ExerciseSet)? after}) {
  final exercises = workout.toList();
  if (exercises.isEmpty) return null;

  UpNext? open(WorkoutExercise exercise, {int from = 0}) {
    final sets = exercise.toList();
    final index = sets.indexWhere((set) => !set.isCompleted, from);
    return switch (index) {
      -1 => null,
      _ => (exercise: exercise, set: sets[index], number: index + 1),
    };
  }

  // the anchor may belong to an exercise removed since it was ticked
  final anchor = switch (after) {
    (WorkoutExercise exercise, ExerciseSet set) when exercises.contains(exercise) => (exercise, set),
    _ => null,
  };

  final forward = switch (anchor) {
    (WorkoutExercise exercise, ExerciseSet set) => [
      ?open(exercise, from: exercise.toList().indexOf(set) + 1),
      ...exercises.skip(exercises.indexOf(exercise) + 1).map(open).nonNulls,
    ].firstOrNull,
    null => null,
  };

  final last = anchor?.$1 ?? exercises.last;
  return forward ?? exercises.map(open).nonNulls.firstOrNull ?? (exercise: last, set: null, number: last.length);
}
