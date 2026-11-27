import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalProgramService] the [Programs]
/// notifier wants (#346). Pure delegation, for the reason `LocalGoals` is:
/// `heart_state` depends on interfaces, not on `heart_db`.
class LocalPrograms implements LocalProgramService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<List<Program>> getPrograms(String userId) => _db.getPrograms(userId);

  @override
  Future<void> storePrograms(Iterable<Program> programs, String userId) => _db.storePrograms(programs, userId);

  @override
  Future<void> storeProgram(Program program, String userId) => _db.storeProgram(program, userId);

  @override
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) {
    return _db.deleteProgram(programId, keepTemplates: keepTemplates);
  }

  @override
  Future<List<ProgramMark>> getProgramMarks(String userId, String programId) => _db.getProgramMarks(userId, programId);

  @override
  Future<List<Workout>> getProgramWorkouts(String userId, String programId) {
    return _db.getProgramWorkouts(userId, programId);
  }

  @override
  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId}) {
    return _db.getProgramActions(userId, programId: programId);
  }

  @override
  Future<void> storeProgramActions(String programId, Iterable<ProgramAction> actions) {
    return _db.storeProgramActions(programId, actions);
  }

  @override
  Future<void> storeProgramAction(ProgramAction action) => _db.storeProgramAction(action);

  @override
  Future<void> deleteProgramAction(String actionId) => _db.deleteProgramAction(actionId);

  @override
  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId}) {
    return _db.getProgramBases(userId, programId: programId);
  }

  @override
  Future<void> storeProgramBases(String programId, Iterable<ProgramBase> bases) {
    return _db.storeProgramBases(programId, bases);
  }

  @override
  Future<void> storeProgramBase(ProgramBase base) => _db.storeProgramBase(base);

  @override
  Future<void> deleteProgramBase(String baseId) => _db.deleteProgramBase(baseId);

  @override
  Future<List<ProgramOwed>> getProgramsOwed(String userId) async {
    return [
      for (final (:row, :id, :programId, :change) in await _db.getProgramsOwed(userId))
        if ((ProgramRow.values.asNameMap()[row], ProgramOwedChange.values.asNameMap()[change]) case (
          final ProgramRow row,
          final ProgramOwedChange change,
        ))
          (row: row, id: id, programId: programId, change: change),
    ];
  }

  @override
  Future<void> owePrograms(String userId, ProgramOwed owed) {
    final (:row, :id, :programId, :change) = owed;
    return _db.owePrograms(userId, (row: row.name, id: id, programId: programId, change: change.name));
  }

  @override
  Future<void> settleProgram(ProgramRow row, String id) => _db.settleProgram(row.name, id);

  @override
  Future<List<TrainingSkip>> getSkips(String userId) => _db.getSkips(userId);

  @override
  Future<void> storeSkips(Iterable<TrainingSkip> skips, String userId) => _db.storeSkips(skips, userId);

  @override
  Future<void> storeSkip(TrainingSkip skip, String userId) => _db.storeSkip(skip, userId);

  @override
  Future<void> deleteSkip(String skipId) => _db.deleteSkip(skipId);
}

/// Presents [Api] as the [RemoteProgramService] the [Programs] notifier wants.
/// A refusal reaches [Programs] as the [ServerRefusal] [Api] threw, and it
/// decides by the code what not to ask again.
class RemotePrograms implements RemoteProgramService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Program>> getPrograms() => _api.getPrograms();

  @override
  Future<Program> getProgram(String programId) => _api.getProgram(programId);

  @override
  Future<Replayed<Program>> replayProgram(Program program, {required Iterable<Template> sessions}) {
    return _api.replayProgram(program, sessions: sessions);
  }

  @override
  Future<Program> editProgram(Program program, {int? baseRevision, String? changeId}) {
    return _api.editProgram(program, baseRevision: baseRevision, changeId: changeId);
  }

  @override
  Future<({List<ProgramChange> items, String? cursor})> getProgramChanges(String programId, {String? since}) {
    return _api.getProgramChanges(programId, since: since);
  }

  @override
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) {
    return _api.deleteProgram(programId, keepTemplates: keepTemplates);
  }

  @override
  Future<List<ProgramAction>> getProgramActions(String programId) => _api.getProgramActions(programId);

  @override
  Future<Replayed<ProgramAction>> replayProgramAction(ProgramAction action) => _api.replayProgramAction(action);

  @override
  Future<void> deleteProgramAction(String programId, String actionId) {
    return _api.deleteProgramAction(programId, actionId);
  }

  @override
  Future<List<ProgramBase>> getProgramBases(String programId) => _api.getProgramBases(programId);

  @override
  Future<Replayed<ProgramBase>> replayProgramBase(ProgramBase base) => _api.replayProgramBase(base);

  @override
  Future<void> deleteProgramBase(String programId, String baseId) => _api.deleteProgramBase(programId, baseId);

  @override
  Future<Template> setTemplateProgram(Template template, {required String? programId}) {
    return _api.setTemplateProgram(template, programId: programId);
  }

  @override
  Future<List<TrainingSkip>> getSkips() => _api.getSkips();

  @override
  Future<Replayed<TrainingSkip>> replaySkip(TrainingSkip skip) => _api.replaySkip(skip);

  @override
  Future<void> deleteSkip(String skipId) => _api.deleteSkip(skipId);

  @override
  Future<void> startProgram(String programId) => _api.startProgram(programId);
}
