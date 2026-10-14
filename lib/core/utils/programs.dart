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
}

/// Presents [Api] as the [RemoteProgramService] the [Programs] notifier wants.
class RemotePrograms implements RemoteProgramService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Program>> getPrograms() => _api.getPrograms();

  @override
  Future<Replayed<Program>> replayProgram(Program program, {required Iterable<Template> sessions}) {
    return _api.replayProgram(program, sessions: sessions);
  }

  @override
  Future<Program> editProgram(Program program) => _api.editProgram(program);

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
}
