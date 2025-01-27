import '../models/workout.dart';

abstract interface class WorkoutService {
  Future<void> startWorkout(String workoutId, DateTime start, {String? name});

  Future<void> deleteWorkout(String workoutId);

  Future<void> finishWorkout(Workout workout);

  Future<void> startExercise(String workoutId, WorkoutExercise exercise);
}
