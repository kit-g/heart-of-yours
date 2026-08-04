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
