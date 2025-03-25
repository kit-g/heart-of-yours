import '../models/act.dart';
import '../models/exercise.dart';

abstract interface class ExerciseService {
  Future<(DateTime?, Iterable<Exercise>)> getExercises();

  Future<void> storeExercises(Iterable<Exercise> exercises);

  Future<Iterable<ExerciseAct>> getExerciseHistory(String userId, Exercise exercise, {int? pageSize, String? anchor});

  Future<Map?> getRecord(String userId, Exercise exercise);
}
