import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalGoalService] the [Goals] notifier wants.
///
/// Pure delegation, and it exists only because of where the interfaces live:
/// `heart_state` deliberately depends on model interfaces rather than on
/// `heart_db`, and [LocalGoalService] cannot live in `heart_models` — that
/// package is the server's, and these three methods are local bookkeeping the
/// server has no notion of. With no package both sides already share, the app
/// is the one place that sees `heart_db` and `heart_state` at once, so it does
/// the joining.
class LocalGoals implements LocalGoalService {
  final LocalDatabase _db;

  const LocalGoals(this._db);

  @override
  Future<Iterable<Goal>> getGoals(String userId) => _db.getGoals(userId);

  @override
  Future<Goal> createGoal(Goal goal, String userId) => _db.createGoal(goal, userId);

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) => _db.updateGoal(goalId, goal, userId);

  @override
  Future<void> deleteGoal(String goalId, String userId) => _db.deleteGoal(goalId, userId);

  @override
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) {
    return _db.markStageAchieved(goalId, stageId, userId, achievedAt);
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId) => _db.storeGoals(goals, userId);

  @override
  Future<Iterable<Goal>> unsyncedGoals(String userId) => _db.unsyncedGoals(userId);

  @override
  Future<void> reconcileGoalId(String localId, Goal saved, String userId) {
    return _db.reconcileGoalId(localId, saved, userId);
  }
}

/// A goal's current value, in the units it is stored in.
///
/// One resolver for both readers, deliberately: the number the card shows and
/// the number [Goals.observeProgress] judges a rung against have to be the same
/// one, or the app can display a target as unmet while recording it as met.
///
/// Null where it cannot be answered *correctly* rather than approximately:
///
/// - a whole-workout goal is answered only for a weekly cadence, from the
///   aggregation the profile already holds;
/// - a per-exercise milestone is its latest observed value;
/// - a per-exercise goal with a cadence would need a period-bounded aggregate
///   that `heart_db/metrics.dart` does not provide, so it has no answer yet.
Future<num?> currentGoalValue(
  Goal goal, {
  required Exercises exercises,
  required WorkoutAggregation workouts,
}) async {
  if (goal.metric.isWholeWorkout) {
    return switch (goal.cadence) {
      .week => workouts.isEmpty ? null : workouts.last.length,
      _ => null,
    };
  }

  if (goal.cadence != null) return null;

  final metric = goal.metric.chart;
  final exercise = goalExercise(goal, exercises);
  if (metric == null || exercise == null) return null;

  final history = await exercises.getChartExerciseMetics(metric, exercise.name, limit: 1);
  return switch (history) {
    [(final num value, _), ...] => value,
    _ => null,
  };
}

/// Goals address an exercise by its server id while the app's catalog is keyed
/// by name, so this is a scan rather than a lookup.
Exercise? goalExercise(Goal goal, Exercises exercises) {
  if (goal.exerciseId case final String id) {
    for (final exercise in exercises) {
      if (exercise.id == id) return exercise;
    }
  }
  return null;
}
