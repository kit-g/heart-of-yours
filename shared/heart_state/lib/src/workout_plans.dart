import 'package:heart_models/heart_models.dart';

/// Where the plans of program workouts wait for the server (#566, #558).
/// The app adapts `LocalDatabase` onto it.
abstract interface class LocalWorkoutPlanService {
  /// Keeps [plan] for [workoutId] until the server has it.
  Future<void> storeWorkoutPlan(String workoutId, String userId, Map<String, dynamic> plan);

  /// The plans the server hasn't taken, of workouts it already has.
  Future<List<({String workoutId, Map<String, dynamic> plan})>> getUnsentWorkoutPlans(String userId);

  Future<void> markWorkoutPlanSent(String workoutId);
}

/// `PUT /workouts/:id/plan`: the server keeps the first plan it gets for a
/// workout. The app adapts `Api` onto it.
abstract interface class RemoteWorkoutPlanService {
  Future<void> saveWorkoutPlan(String workoutId, WorkoutPlan plan);
}
