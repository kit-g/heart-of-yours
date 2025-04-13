import '../models/exercise.dart';
import '../models/template.dart';

abstract interface class RemoteConfigService {
  Future<Map> getRemoteConfig();

  Future<Iterable<Template>> getSampleTemplates(ExerciseLookup lookForExercise);
}
