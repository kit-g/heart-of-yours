import '../models/exercise.dart';

abstract interface class ExerciseService {
  Future<(DateTime?, Iterable<Exercise>)> getExercises();

  Future<void> storeExercises(Iterable<Exercise> exercises);
}
