import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RosterService] [Roster] wants (#559), as
/// `RemoteCoaching` does for connections.
class RemoteRoster implements RosterService {
  final Api _api;

  const new(this._api);

  @override
  Future<({List<ClientSummary> items, String? cursor})> getClients({bool former = false, String? cursor}) {
    return _api.getClients(former: former, cursor: cursor);
  }

  @override
  Future<void> markReviewed(String connectionId, {DateTime? at}) => _api.markReviewed(connectionId, at: at);

  @override
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) {
    return _api.getCoachFeed(cursor: cursor);
  }

  @override
  Future<({List<Workout> items, String? cursor})> getClientWorkouts(String studentId, {String? cursor}) {
    return _api.getClientWorkouts(studentId, cursor: cursor);
  }

  @override
  Future<List<TrainingSkip>> getClientSkips(String studentId) => _api.getClientSkips(studentId);

  @override
  Future<Workout> getClientWorkout(String studentId, String workoutId) {
    // the requester is the token's, which the route reads for itself
    return _api.getTargetWorkout(requesterId: '', targetUserId: studentId, workoutId: workoutId);
  }

  @override
  Future<WorkoutPlan?> getClientWorkoutPlan(String studentId, String workoutId) {
    return _api.getClientWorkoutPlan(studentId, workoutId);
  }
}

/// Presents [Api] as the [ClientProgramService] [ClientPrograms] wants (#558).
class RemoteClientPrograms implements ClientProgramService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Program>> getClientPrograms(String studentId) => _api.getClientPrograms(studentId);

  @override
  Future<CoachProgramView> getClientProgram(String studentId, String programId) {
    return _api.getClientProgram(studentId, programId);
  }

  @override
  Future<Program> editClientProgram(
    String studentId,
    Program program, {
    required int baseRevision,
    required String changeId,
  }) {
    return _api.editClientProgram(studentId, program, baseRevision: baseRevision, changeId: changeId);
  }

  @override
  Future<void> editClientSession(
    String studentId,
    String programId,
    Template session, {
    required int baseRevision,
    required String changeId,
  }) {
    return _api.editClientSession(studentId, programId, session, baseRevision: baseRevision, changeId: changeId);
  }

  @override
  Future<void> deleteClientSession(String studentId, String programId, String sessionId) {
    return _api.deleteClientSession(studentId, programId, sessionId);
  }

  @override
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since}) {
    return _api.getClientProgramChanges(studentId, programId, since: since);
  }

  @override
  Future<void> revertClientChange(String studentId, String programId, String changeId) {
    return _api.revertClientChange(studentId, programId, changeId);
  }
}
