import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalStatsService] the [Stats] notifier
/// wants — the same joining [LocalGoals] does, for the same reason: the app is
/// the one place that sees `heart_db` and `heart_state` at once.
class LocalStats implements LocalStatsService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<WorkoutAggregation> getWorkoutSummary({int? weeksBack = 8, String? userId}) {
    return _db.getWorkoutSummary(weeksBack: weeksBack, userId: userId);
  }

  @override
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId}) {
    return _db.getWeeklyWorkoutCount(d, userId: userId);
  }

  @override
  Future<int> getMonthlyWorkoutCount(DateTime d, {String? userId}) {
    return _db.getMonthlyWorkoutCount(d, userId: userId);
  }

  @override
  Future<int> getTotalWorkoutCount({String? userId}) => _db.getTotalWorkoutCount(userId: userId);
}
