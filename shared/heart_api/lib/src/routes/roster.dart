part of '../api.dart';

/// A coach's view of everyone they coach (#559): the roster, sorted by who
/// may need a word, marking a client looked at, and the feed of what they all
/// did.
mixin _RosterRoutes on Requests, _ExerciseNaming {
  /// One row per coaching connection, those with `reasons` first. [reason]
  /// keeps only the clients with that one, and [former] lists the ended
  /// connections instead. A row this build can't read is dropped, not fatal.
  Future<({List<ClientSummary> items, String? cursor})> getClients({
    String? reason,
    bool former = false,
    String? cursor,
  }) async {
    final query = {
      'reason': ?reason,
      if (former) 'former': 'true',
      'cursor': ?cursor,
    };
    final (clients, page) = await _listAt(Router.coachClients, 'clients', query: query.isEmpty ? null : query);
    return (items: _readable(clients, ClientSummary.fromJson), cursor: page['cursor'] as String?);
  }

  /// The coach has looked at a client: from [at], or now, only what comes
  /// after counts towards their reasons. A [ServerRefusal] `404` for a
  /// connection that isn't the coach's.
  Future<void> markReviewed(String connectionId, {DateTime? at}) {
    return put(
      Router.coachClientReviewed(connectionId),
      body: {'at': ?at?.toUtc().toIso8601String()},
    );
  }

  /// Workouts, skips and endings of every client, newest first.
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) async {
    final (items, page) = await _listAt(Router.coachFeed, 'items', query: _cursor(cursor));
    return (items: _readable(items, CoachFeedItem.fromJson), cursor: page['cursor'] as String?);
  }

  /// A client's workouts, newest first, as their coach may read them: from
  /// accepting on (or all, with history shared), never a hidden one, none
  /// started during a pause, no photos. A [ServerRefusal] `403` once the
  /// connection ends.
  Future<({List<Workout> items, String? cursor})> getClientWorkouts(String studentId, {String? cursor}) async {
    final (workouts, page) = await _listAt(Router.clientWorkouts(studentId), 'workouts', query: _cursor(cursor));
    return (
      items: _readable(_namedAll(workouts), Workout.fromJson),
      cursor: page['cursor'] as String?,
    );
  }

  /// When a client skipped a session, never why.
  Future<List<TrainingSkip>> getClientSkips(String studentId) async {
    final (skips, _) = await _listAt(Router.clientSkips(studentId), 'skips');
    return _readable(skips, TrainingSkip.fromJson);
  }

  /// What a client's workout was asked to be, to put target beside done; null
  /// for a workout with no plan (`404`), which has nothing to compare with.
  Future<WorkoutPlan?> getClientWorkoutPlan(String studentId, String workoutId) async {
    try {
      final (json, _) = await get(Router.clientWorkoutPlan(studentId, workoutId));
      return WorkoutPlan.fromJson(json);
    } on Exception catch (error) {
      if (_gone(error)) return null;
      rethrow;
    }
  }

  /// Logs [workout] as [studentId]'s (#560): one the coach was there for,
  /// in the client's history from now on, marked as logged by the coach.
  /// The id is the device's, so a retry answers the stored one; an id someone
  /// else used is refused (`id_taken`), and so is a client this coach no
  /// longer coaches (`forbidden`), both [ServerRefusal]s.
  Future<Workout> logClientWorkout(String studentId, Workout workout) async {
    final (json, _) = _created(await post(Router.clientWorkouts(studentId), body: workout.toMap()));
    return Workout.fromJson(_named(json));
  }

  /// Keeps what a workout the coach logged for [studentId] was asked to be,
  /// to put target beside done. The server keeps the first plan, so sending
  /// it again changes nothing.
  Future<void> saveClientWorkoutPlan(String studentId, String workoutId, WorkoutPlan plan) {
    return put(Router.clientWorkoutPlan(studentId, workoutId), body: plan.toMap());
  }

  /// The copies the coach manages for a client.
  Future<List<Program>> getClientPrograms(String studentId) async {
    final (programs, _) = await _listAt(Router.clientPrograms(studentId), 'programs');
    return _readable(programs, Program.fromJson);
  }

  /// One copy as the coach can see it: its sessions, and its position worked
  /// out only from what the coach can read.
  Future<CoachProgramView> getClientProgram(String studentId, String programId) async {
    final (json, _) = await get(Router.clientProgram(studentId, programId));
    return CoachProgramView.fromJson(_namedSessions(json));
  }

  /// The coach edits a copy's own fields, from [baseRevision]. The
  /// [ServerRefusal] `409 program_changed`, carrying the current `revision`,
  /// when the client changed them since; a retry with the same [changeId]
  /// writes nothing again.
  Future<Program> editClientProgram(
    String studentId,
    Program program, {
    required int baseRevision,
    required String changeId,
  }) async {
    final (json, _) = await put(
      Router.clientProgram(studentId, program.id!),
      body: {
        'name': program.name,
        'note': ?program.note,
        'weeks': program.weeks,
        'perWeek': program.perWeek,
        'baseRevision': baseRevision,
        'changeId': changeId,
      },
    );
    return Program.fromJson(json);
  }

  /// The coach replaces one session of a copy, exercises included, from
  /// [baseRevision]. Conflicts as [editClientProgram].
  Future<void> editClientSession(
    String studentId,
    String programId,
    Template session, {
    required int baseRevision,
    required String changeId,
  }) {
    return put(
      Router.clientSession(studentId, programId, session.id),
      body: {...session.toMap(), 'baseRevision': baseRevision, 'changeId': changeId},
    );
  }

  /// The coach removes a session of a copy. Harmless twice.
  Future<void> deleteClientSession(String studentId, String programId, String sessionId) {
    return delete(Router.clientSession(studentId, programId, sessionId));
  }

  /// What changed in a copy, oldest first, from [since] on.
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since}) async {
    final (json, _) = await get(
      Router.clientProgramChanges(studentId, programId),
      query: {'since': ?since},
    );
    return ProgramChanges.fromJson(json).changes;
  }

  /// Puts [changeId] back, as a new change. A [ServerRefusal] `409` when the
  /// client has since built on it.
  Future<void> revertClientChange(String studentId, String programId, String changeId) {
    return post(Router.clientChangeRevert(studentId, programId, changeId));
  }
}
