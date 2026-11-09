import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as where a program workout's plan waits (#566).
/// Pure delegation, as `LocalPrograms` is: `heart_state` depends on
/// interfaces, not on `heart_db`.
class LocalWorkoutPlans implements LocalWorkoutPlanService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<void> storeWorkoutPlan(String workoutId, String userId, Map<String, dynamic> plan) {
    return _db.storeWorkoutPlan(workoutId, userId, plan);
  }

  @override
  Future<List<({String workoutId, Map<String, dynamic> plan})>> getUnsentWorkoutPlans(String userId) {
    return _db.getUnsentWorkoutPlans(userId);
  }

  @override
  Future<void> markWorkoutPlanSent(String workoutId) => _db.markWorkoutPlanSent(workoutId);
}

/// Presents [Api] as the route that takes a workout's plan (#566).
class RemoteWorkoutPlans implements RemoteWorkoutPlanService {
  final Api _api;

  const new(this._api);

  @override
  Future<void> saveWorkoutPlan(String workoutId, WorkoutPlan plan) => _api.saveWorkoutPlan(workoutId, plan);
}
