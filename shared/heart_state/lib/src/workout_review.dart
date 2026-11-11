import 'package:heart_models/heart_models.dart';

/// How one set compares with what was asked of it (#559). Null on a
/// [ReviewedSet] means there was nothing to compare with.
enum SetOutcome {
  /// Done as planned, or more.
  asked,

  /// Done, at a lighter weight than planned.
  lighter,

  /// Done, with fewer reps than planned.
  fewer,

  /// Planned, and not done.
  skipped,

  /// Done, and not in the plan.
  added,
}

/// The numbers a set was asked for, in kilograms, seconds and kilometres; a
/// target's lower end where the plan gives a range.
typedef PlannedNumbers = ({num? weight, num? reps, num? duration, num? distance});

/// One planned set beside the set it became, or a set the plan never asked for.
final class ReviewedSet {
  final PlannedNumbers? planned;
  final ExerciseSet? done;
  final SetOutcome? outcome;

  const new({this.planned, this.done, this.outcome});
}

/// One exercise of a [WorkoutReview], in the plan's order, then the workout's.
final class ReviewedExercise {
  final String exerciseId;

  /// The exercise as the workout logged it; null for a planned one the
  /// workout never reached, which the app names from its own library.
  final Exercise? exercise;

  final List<ReviewedSet> sets;

  /// Whether the plan had it at all.
  final bool planned;

  const new({required this.exerciseId, required this.exercise, required this.sets, required this.planned});

  /// Planned, and not one set of it done.
  bool get skipped => planned && sets.isNotEmpty && sets.every((set) => set.outcome == .skipped);
}

/// A client's workout read against what it was asked to be (#559): "did they
/// do what I asked?", per exercise and per set, without opening anything
/// else.
///
/// The plan is the one the student's device recorded on saving (#566), each
/// planned set naming the set it became: what was asked can't be worked out
/// again later, since bases, waves and lighter weeks move on. A workout
/// without one compares with nothing and lists what was done.
final class WorkoutReview {
  final Workout workout;

  /// Whether there is a plan to compare with.
  final bool hasPlan;

  /// The week was a lighter one, so fewer sets were asked for.
  final bool lighterWeek;

  final List<ReviewedExercise> exercises;

  const new _({required this.workout, required this.hasPlan, required this.lighterWeek, required this.exercises});

  /// Only completed sets count as done.
  factory of(Workout workout, WorkoutPlan? plan) {
    final done = {
      for (final exercise in workout)
        for (final set in exercise)
          if (set.isCompleted) set.id: (exercise: exercise, set: set),
    };
    final planned = switch (plan?.plan['exercises']) {
      final List exercises => exercises.whereType<Map>().toList(),
      _ => null,
    };
    if (planned == null) {
      return WorkoutReview._(
        workout: workout,
        hasPlan: false,
        lighterWeek: false,
        exercises: [
          for (final exercise in workout)
            if (exercise.where((set) => set.isCompleted).toList() case final sets when sets.isNotEmpty)
              ReviewedExercise(
                exerciseId: exercise.exercise.id,
                exercise: exercise.exercise,
                planned: false,
                sets: [for (final set in sets) ReviewedSet(done: set)],
              ),
        ],
      );
    }

    final used = <String>{};
    final reached = <String>{};
    final exercises = <ReviewedExercise>[];
    for (final json in planned) {
      final exerciseId = json['exerciseId']?.toString() ?? '';
      WorkoutExercise? logged;
      final sets = <ReviewedSet>[];
      for (final set in (json['sets'] as List? ?? const []).whereType<Map>()) {
        final numbers = _numbers(set);
        final match = switch (set['setId']) {
          final String id => done[id],
          _ => null,
        };
        if (match == null) {
          sets.add(ReviewedSet(planned: numbers, outcome: .skipped));
          continue;
        }
        used.add(match.set.id);
        logged ??= match.exercise;
        sets.add(ReviewedSet(planned: numbers, done: match.set, outcome: _compare(numbers, match.set)));
      }
      logged ??= workout.where((each) => each.exercise.id == exerciseId && !reached.contains(each.id)).firstOrNull;
      if (logged != null) {
        reached.add(logged.id);
        // done in this exercise, and not asked for
        for (final set in logged) {
          if (set.isCompleted && used.add(set.id)) sets.add(ReviewedSet(done: set, outcome: .added));
        }
      }
      exercises.add(
        ReviewedExercise(exerciseId: exerciseId, exercise: logged?.exercise, sets: sets, planned: true),
      );
    }
    for (final exercise in workout) {
      if (reached.contains(exercise.id)) continue;
      final sets = [
        for (final set in exercise)
          if (set.isCompleted && used.add(set.id)) ReviewedSet(done: set, outcome: .added),
      ];
      if (sets.isEmpty) continue;
      exercises.add(
        ReviewedExercise(exerciseId: exercise.exercise.id, exercise: exercise.exercise, sets: sets, planned: false),
      );
    }
    return WorkoutReview._(
      workout: workout,
      hasPlan: true,
      lighterWeek: plan?.plan['lighter'] == true,
      exercises: exercises,
    );
  }

  /// Whether anything went other than asked.
  bool get offPlan => exercises.any((exercise) => exercise.sets.any((set) => set.outcome != .asked));
}

PlannedNumbers _numbers(Map set) {
  final target = switch (set['target']) {
    final Map target => SetTarget.fromJson(target),
    _ => null,
  };
  num? either(TargetMeasure measure, String key) => target?[measure]?.min ?? (set[key] as num?);
  return (
    // the weight the student was shown, on their plates, comes first
    weight: (set['weight'] as num?) ?? target?[.weight]?.min,
    reps: either(.reps, 'reps'),
    duration: either(.duration, 'duration'),
    distance: either(.distance, 'distance'),
  );
}

/// A hair under the plan is still the plan: plates round, units convert.
const _tolerance = 0.01;

SetOutcome _compare(PlannedNumbers planned, ExerciseSet done) {
  if ((planned.weight, done.weight) case (final num asked, final num lifted) when lifted < asked - _tolerance) {
    return .lighter;
  }
  if ((planned.reps, done.reps) case (final num asked, final num did) when did < asked) return .fewer;
  return .asked;
}
