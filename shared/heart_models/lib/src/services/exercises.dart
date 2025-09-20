import '../models/act.dart';
import '../models/exercise.dart';

abstract interface class ExerciseService {
  Future<(DateTime?, Iterable<Exercise>)> getExercises();

  Future<void> storeExercises(Iterable<Exercise> exercises);

  Future<Iterable<ExerciseAct>> getExerciseHistory(String userId, Exercise exercise, {int? pageSize, String? anchor});

  Future<Map?> getRecord(String userId, Exercise exercise);

  Future<List<(num, DateTime)>> getRepsHistory(String userId, Exercise exercise, {int? limit});

  Future<List<(num, DateTime)>> getWeightHistory(String userId, Exercise exercise, {int? limit});

  Future<List<(num, DateTime)>> getDistanceHistory(String userId, Exercise exercise, {int? limit});

  Future<List<(num, DateTime)>> getDurationHistory(String userId, Exercise exercise, {int? limit});
}

abstract interface class RemoteExerciseService {
  Future<Iterable<Exercise>> getExercises();

  Future<Iterable<Exercise>> getOwnExercises();

  Future<Exercise> makeExercise(Exercise exercise);

  Future<Exercise> editExercise(Exercise exercise);
}
