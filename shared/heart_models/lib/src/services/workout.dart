import '../models/exercise_set.dart';
import '../models/workout.dart';

abstract interface class WorkoutService {
  Future<void> startWorkout(Workout workout, String userId);

  Future<void> deleteWorkout(String workoutId);

  Future<void> finishWorkout(Workout workout, String userId);

  Future<void> startExercise(String workoutId, WorkoutExercise exercise);

  Future<void> removeExercise(WorkoutExercise exercise);

  Future<void> addSet(WorkoutExercise exercise, ExerciseSet set);

  Future<void> removeSet(ExerciseSet set);

  Future<void> storeMeasurements(ExerciseSet set);

  Future<void> markSetAsComplete(ExerciseSet set);

  Future<void> markSetAsIncomplete(ExerciseSet set);

  Future<Workout?> getActiveWorkout(String? userId);

  Future<Workout?> getWorkout(String? userId, String workoutId);

  Future<void> storeWorkoutHistory(Iterable<Workout> history, String userId);

  Future<Iterable<Workout>?> getWorkoutHistory(String userId);

  Future<void> renameWorkout({required String workoutId, required String name});
}
