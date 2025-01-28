import '../models/exercise_set.dart';
import '../models/workout.dart';

abstract interface class WorkoutService {
  Future<void> startWorkout(String workoutId, DateTime start, {String? name});

  Future<void> deleteWorkout(String workoutId);

  Future<void> finishWorkout(Workout workout);

  Future<void> startExercise(String workoutId, WorkoutExercise exercise);

  Future<void> removeExercise(WorkoutExercise exercise);

  Future<void> addSet(WorkoutExercise exercise, ExerciseSet set);

  Future<void> removeSet(ExerciseSet set);

  Future<void> storeMeasurements(ExerciseSet set);

  Future<void> markSetAsComplete(ExerciseSet set);

  Future<void> markSetAsIncomplete(ExerciseSet set);

  Future<Workout?> getActiveWorkout();

  Future<void> storeWorkoutHistory(Iterable<Workout> history);
}
