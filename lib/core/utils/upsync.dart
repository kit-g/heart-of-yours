import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalUpsyncService] the [Upsync] notifier
/// wants.
///
/// Pure delegation, for the same reason `LocalGoals` exists: `heart_state`
/// depends on interfaces rather than on `heart_db`, and this one cannot live
/// in `heart_models` — a uid move and a replay ledger are bookkeeping the
/// server has no notion of. The one translation is the ledger's vocabulary:
/// the database stores names, the notifier reads enums.
class LocalUpsync implements LocalUpsyncService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<void> rekeyUser(String from, String to) => _db.rekeyUser(from, to);

  @override
  Future<void> owe(String userId) => _db.oweUpsync(userId);

  @override
  Future<bool> isOwed(String userId) => _db.isUpsyncOwed(userId);

  @override
  Future<Map<UpsyncResource, Map<String, UpsyncOutcome>>> ledger(String userId) async {
    final entries = await _db.upsyncLedger(userId);
    final ledger = <UpsyncResource, Map<String, UpsyncOutcome>>{};
    for (final (:resource, :id, :outcome) in entries) {
      // a name this build does not know is a row a newer build confirmed;
      // it stays in the table and out of this run's way
      final kind = UpsyncResource.values.asNameMap()[resource];
      final answer = UpsyncOutcome.values.asNameMap()[outcome];
      if (kind == null || answer == null) continue;
      ledger.putIfAbsent(kind, () => {})[id] = answer;
    }
    return ledger;
  }

  @override
  Future<void> record(String userId, UpsyncResource resource, String id, UpsyncOutcome outcome) {
    return _db.recordUpsync(userId, (resource: resource.name, id: id, outcome: outcome.name));
  }

  @override
  Future<void> settle(String userId) => _db.settleUpsync(userId);

  @override
  Future<void> mergeExercise(String userId, {required String from, required String to}) {
    return _db.mergeExercise(userId, from: from, to: to);
  }

  @override
  Future<void> mergeFolder(String userId, {required String from, required String to}) {
    return _db.mergeFolder(userId, from: from, to: to);
  }
}

/// Presents [Api] as the [UpsyncService] the [Upsync] notifier wants — the
/// replay's creates are the same calls the everyday paths make, kept with the
/// server's created-or-found answer.
class RemoteUpsync implements UpsyncService {
  final Api _api;

  const new(this._api);

  @override
  Future<Replayed<Exercise>> replayExercise(Exercise exercise) => _api.replayExercise(exercise);

  @override
  Future<void> replayUnitPreference(String exerciseId, MeasurementUnit unit) {
    return _api.replayUnitPreference(exerciseId, unit);
  }

  @override
  Future<Replayed<TemplateFolder>> replayFolder(TemplateFolder folder) => _api.replayFolder(folder);

  @override
  Future<Replayed<Template>> replayTemplate(Template template) => _api.replayTemplate(template);

  @override
  Future<Replayed<Workout>> replayWorkout(Workout workout) => _api.replayWorkout(workout);

  @override
  Future<Replayed<Goal>> replayGoal(Goal goal) => _api.replayGoal(goal);
}
