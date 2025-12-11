import '../models/exercise.dart';
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

  Future<Workout?> getActiveWorkout(String? userId, ExerciseLookup lookup);

  Future<Workout?> getWorkout(String? userId, String workoutId, ExerciseLookup lookup);

  Future<void> storeWorkoutHistory(Iterable<Workout> history, String userId);

  Future<Iterable<Workout>?> getWorkoutHistory(String userId, ExerciseLookup lookup);

  Future<void> renameWorkout({required String workoutId, required String name});
}

abstract interface class RemoteWorkoutService implements FileUploadService {
  Future<Iterable<Workout>?> getWorkouts(ExerciseLookup lookForExercise, {int? pageSize, String? since});

  Future<bool> saveWorkout(Workout workout);

  Future<bool> deleteWorkout(String workoutId);

  Future<(({String url, Map<String, String> fields})?, String?)> getWorkoutUploadLink(
    String workoutId, {
    String? imageMimeType,
  });
}
