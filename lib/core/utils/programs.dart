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
        if ((ProgramRow.values.asNameMap()[row], ProgramChange.values.asNameMap()[change]) case (
          final ProgramRow row,
          final ProgramChange change,
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
}

/// Presents [Api] as the [RemoteProgramService] the [Programs] notifier wants.
///
/// A refusal reaches [Programs] as the body the server sent, `{'code': …}`,
/// the way every other create throws it: `heart_state` cannot see the typed
/// [ProgramRefused], and decides by the code what not to ask again.
class RemotePrograms implements RemoteProgramService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Program>> getPrograms() => _refusedAsBody(_api.getPrograms);

  @override
  Future<Replayed<Program>> replayProgram(Program program, {required Iterable<Template> sessions}) {
    return _refusedAsBody(() => _api.replayProgram(program, sessions: sessions));
  }

  @override
  Future<Program> editProgram(Program program) => _refusedAsBody(() => _api.editProgram(program));

  @override
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) {
    return _refusedAsBody(() => _api.deleteProgram(programId, keepTemplates: keepTemplates));
  }

  @override
  Future<List<ProgramAction>> getProgramActions(String programId) {
    return _refusedAsBody(() => _api.getProgramActions(programId));
  }

  @override
  Future<Replayed<ProgramAction>> replayProgramAction(ProgramAction action) {
    return _refusedAsBody(() => _api.replayProgramAction(action));
  }

  @override
  Future<void> deleteProgramAction(String programId, String actionId) {
    return _refusedAsBody(() => _api.deleteProgramAction(programId, actionId));
  }

  @override
  Future<List<ProgramBase>> getProgramBases(String programId) => _refusedAsBody(() => _api.getProgramBases(programId));

  @override
  Future<Replayed<ProgramBase>> replayProgramBase(ProgramBase base) {
    return _refusedAsBody(() => _api.replayProgramBase(base));
  }

  @override
  Future<void> deleteProgramBase(String programId, String baseId) {
    return _refusedAsBody(() => _api.deleteProgramBase(programId, baseId));
  }

  @override
  Future<Template> setTemplateProgram(Template template, {required String? programId}) {
    return _refusedAsBody(() => _api.setTemplateProgram(template, programId: programId));
  }

  static Future<T> _refusedAsBody<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ProgramRefused catch (refused) {
      throw {'code': refused.reason.code};
    }
  }
}
