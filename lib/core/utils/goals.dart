import 'package:heart/presentation/widgets/chart_dimension.dart';
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
  Future<Iterable<Goal>> getTargetUserGoals({required String requesterId, required String targetUserId}) {
    return _db.getTargetUserGoals(requesterId: requesterId, targetUserId: targetUserId);
  }

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
/// [asOf] is which moment "this period" is measured from, defaulting to now.
/// Passed explicitly by tests so a recurring goal's arithmetic does not depend
/// on the day the suite happens to run.
///
/// Null where it cannot be answered *correctly* rather than approximately:
///
/// - a whole-workout goal is answered from the aggregation the profile already
///   holds for a weekly cadence, and from [workoutsThisMonth] for a monthly one
///   — those buckets are weeks, and a week straddling the first of the month
///   belongs cleanly to neither;
/// - a per-exercise milestone is its latest observed value;
/// - a per-exercise goal with a cadence is its sessions inside the current
///   period, folded the way that dimension folds — see
///   [ChartDimension.periodAggregate].
Future<num?> currentGoalValue(
  Goal goal, {
  required Exercises exercises,
  required WorkoutAggregation workouts,
  Future<int> Function()? workoutsThisMonth,
  DateTime? asOf,
}) async {
  if (goal.metric.isWholeWorkout) {
    return switch (goal.cadence) {
      .week => workouts.isEmpty ? null : workouts.last.length,
      // costs a query, so it is asked for only when a goal is actually counting
      // months — and left unanswered rather than guessed if nobody supplied one
      .month => await workoutsThisMonth?.call(),
      _ => null,
    };
  }

  final metric = goal.metric.chart;
  final exercise = goalExercise(goal, exercises);
  if (metric == null || exercise == null) return null;

  if (goal.cadence case final GoalCadence cadence) {
    final (from, to) = goalPeriod(cadence, asOf ?? DateTime.now());
    // The metric queries return a row per session; the period is cut here
    // rather than in SQL so that what "per week" means for each dimension stays
    // in one readable place instead of spread across eleven statements.
    final history = await exercises.getChartExerciseMetics(metric, exercise.name, limit: _sessionsPerPeriod);
    final inPeriod = [
      for (final (value, at) in history ?? const <(num, DateTime)>[])
        if (!at.isBefore(from) && at.isBefore(to)) value,
    ];

    return switch (inPeriod.isEmpty) {
      // Nothing logged yet is genuinely zero for anything you accumulate — "0
      // of 2000 kg this week" is the honest reading. Not for pace, where zero
      // sits below the target and would render as though it had been met.
      true => goal.metric.lowerIsBetter ? null : 0,
      false => metric.periodAggregate.of(inPeriod),
    };
  }

  final history = await exercises.getChartExerciseMetics(metric, exercise.name, limit: 1);
  return switch (history) {
    [(final num value, _), ...] => value,
    _ => null,
  };
}

/// How many sessions of one exercise to pull when folding a period.
///
/// The queries are ordered newest first and bounded by count, not by date, so
/// this only has to outrun a single period — far more sessions of one exercise
/// than a week or a month of training ever contains.
const _sessionsPerPeriod = 60;

/// The half-open window a cadence goal is currently accumulating in.
///
/// Local, not UTC: a Monday-morning session belongs to the week the user is
/// living in. `getMonday` already normalises to midnight.
(DateTime, DateTime) goalPeriod(GoalCadence cadence, DateTime now) {
  return switch (cadence) {
    .week => (getMonday(now), getMonday(now).add(const Duration(days: 7))),
    .month => (DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
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
