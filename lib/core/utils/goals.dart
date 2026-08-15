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

  const new(this._db);

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) {
    return _db.getTargetUserGoals(
      requesterId: requesterId,
      targetUserId: targetUserId,
      archived: archived,
    );
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) => _db.createGoal(goal, userId);

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) => _db.updateGoal(goalId, goal, userId);

  @override
  Future<void> deleteGoal(String goalId, String userId) => _db.deleteGoal(goalId, userId);

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) {
    return _db.markStageAchieved(goalId, stageId, userId, achievedAt, achievedBy: achievedBy);
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId, {bool archived = false}) {
    return _db.storeGoals(goals, userId, archived: archived);
  }

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
/// [without] excludes the session that started at that instant from a recurring
/// goal's period — asking what the week was worth before a given workout, which
/// is how the summary tells whether *this* session carried it over the line.
///
/// Null where it cannot be answered *correctly* rather than approximately:
///
/// - a whole-workout goal is [workoutCount] over the goal's own period, which
///   for a milestone (no cadence) is every workout there has ever been;
/// - a per-exercise milestone is its best observed value — a milestone is a
///   ratchet, so a lighter session does not undo one;
/// - a per-exercise goal with a cadence is its sessions inside the current
///   period, folded the way that dimension folds — see
///   [ChartDimension.periodAggregate].
Future<num?> currentGoalValue(
  Goal goal, {
  required Exercises exercises,
  Future<int> Function(GoalCadence? period)? workoutCount,
  DateTime? asOf,
  DateTime? without,
}) async {
  // Every period is the same question asked of a different window, including
  // the unbounded one — a "do 8 workouts" milestone used to fall past the week
  // and month cases and answer null, which drew an empty bar and, because
  // observeProgress skips a goal it cannot measure, never announced the 8th.
  if (goal.metric.isWholeWorkout) return await workoutCount?.call(goal.cadence);

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
        if (!at.isBefore(from) && at.isBefore(to))
          // [without] drops one session, so a caller can ask what the period
          // was worth before it — the difference is what a single workout did
          if (without == null || !at.isAtSameMomentAs(without)) value,
    ];

    return switch (inPeriod.isEmpty) {
      // Nothing logged yet is genuinely zero for anything you accumulate — "0
      // of 2000 kg this week" is the honest reading. Not for pace, where zero
      // sits below the target and would render as though it had been met.
      true => goal.metric.lowerIsBetter ? null : 0,
      false => metric.periodAggregate.of(inPeriod),
    };
  }

  // A milestone asks whether the target has *ever* been reached, so the reading
  // is the best session rather than the most recent one. Reading the latest
  // made the number walk backwards after every lighter day — a goal of 3000 lb
  // on an exercise topping out at 2880 showed 2025, because that was simply the
  // last session logged — and it contradicted the rungs beside it, which stay
  // stamped once cleared.
  final history = await exercises.getChartExerciseMetics(metric, exercise.name, limit: _milestoneHistory);
  final values = [for (final (value, _) in history ?? const <(num, DateTime)>[]) value];
  if (values.isEmpty) return null;

  return values.reduce(
    switch (goal.metric.lowerIsBetter) {
      true => (a, b) => a < b ? a : b,
      false => (a, b) => a > b ? a : b,
    },
  );
}

//   git diff -- lib/core/utils/goals.dart shared/heart_state/lib/src/goals.dart test/goal_period_test.dart shared/heart_state/test/goals_test.dart
/// How many sessions of one exercise to pull when folding a period.
///
/// The queries are ordered newest first and bounded by count, not by date, so
/// this only has to outrun a single period — far more sessions of one exercise
/// than a week or a month of training ever contains.
const _sessionsPerPeriod = 60;

/// How far back a milestone looks for its best session.
///
/// A bound rather than a window: the answer wanted is the best there has ever
/// been, and this only keeps the scan from being unbounded. One exercise
/// trained twice a week takes five years to reach it.
const _milestoneHistory = 500;

/// Counts workouts over whichever window a goal measures.
///
/// One resolver so the three periods cannot drift apart, and so a goal without
/// a cadence is answered rather than skipped.
Future<int> Function(GoalCadence?) workoutCounter(Stats stats, {DateTime? asOf}) {
  return (period) {
    final now = asOf ?? DateTime.now();
    return switch (period) {
      .week => stats.getWeeklyWorkoutCount(now),
      .month => stats.getMonthlyWorkoutCount(now),
      null => stats.getTotalWorkoutCount(),
    };
  };
}

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
