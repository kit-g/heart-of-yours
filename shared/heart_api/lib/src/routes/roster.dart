part of '../api.dart';

/// A coach's view of everyone they coach (#559): the roster, sorted by who
/// may need a word, marking a client looked at, and the feed of what they all
/// did.
mixin _RosterRoutes on Requests {
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
    final (json, code) = await get(Router.coachClients, query: query.isEmpty ? null : query);
    return switch ((code, json)) {
      (200, {'clients': List l}) => (items: _readable(l, ClientSummary.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// The coach has looked at a client: from [at], or now, only what comes
  /// after counts towards their reasons. `404` for a connection that isn't
  /// the coach's, thrown whole.
  Future<void> markReviewed(String connectionId, {DateTime? at}) async {
    final (json, code) = await put(
      Router.coachClientReviewed(connectionId),
      body: {'at': ?at?.toUtc().toIso8601String()},
    );
    if (code != 204) throw json;
  }

  /// Workouts, skips and endings of every client, newest first.
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) async {
    final (json, code) = await get(Router.coachFeed, query: _cursor(cursor));
    return switch ((code, json)) {
      (200, {'items': List l}) => (items: _readable(l, CoachFeedItem.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// A client's workouts, newest first, as their coach may read them: from
  /// accepting on (or all, with history shared), never a hidden one, none
  /// started during a pause, no photos. `403` once the connection ends, thrown
  /// whole.
  Future<({List<Workout> items, String? cursor})> getClientWorkouts(String studentId, {String? cursor}) async {
    final (json, code) = await get(Router.clientWorkouts(studentId), query: _cursor(cursor));
    return switch ((code, json)) {
      (200, {'workouts': List l}) => (items: _readable(l, Workout.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// When a client skipped a session, never why.
  Future<List<TrainingSkip>> getClientSkips(String studentId) async {
    final (json, code) = await get(Router.clientSkips(studentId));
    return switch ((code, json)) {
      (200, {'skips': List l}) => _readable(l, TrainingSkip.fromJson),
      _ => throw json,
    };
  }

  /// What a client's workout was asked to be, to put target beside done; null
  /// for a workout with no plan (`404`), which has nothing to compare with.
  Future<WorkoutPlan?> getClientWorkoutPlan(String studentId, String workoutId) async {
    final (json, code) = await get(Router.clientWorkoutPlan(studentId, workoutId));
    return switch ((code, json)) {
      (200, Map json) => WorkoutPlan.fromJson(json),
      (404, _) => null,
      _ => throw json,
    };
  }

  /// The copies the coach manages for a client.
  Future<List<Program>> getClientPrograms(String studentId) async {
    final (json, code) = await get(Router.clientPrograms(studentId));
    return switch ((code, json)) {
      (200, {'programs': List l}) => _readable(l, Program.fromJson),
      _ => throw json,
    };
  }

  /// One copy as the coach can see it: its sessions, and its position worked
  /// out only from what the coach can read.
  Future<CoachProgramView> getClientProgram(String studentId, String programId) async {
    final (json, code) = await get(Router.clientProgram(studentId, programId));
    return switch ((code, json)) {
      (200, Map json) => CoachProgramView.fromJson(json),
      _ => throw json,
    };
  }

  /// The coach edits a copy's own fields, from [baseRevision]. `409
  /// program_changed`, carrying the current `revision`, when the client
  /// changed them since; a retry with the same [changeId] writes nothing
  /// again. Thrown whole.
  Future<Program> editClientProgram(
    String studentId,
    Program program, {
    required int baseRevision,
    required String changeId,
  }) async {
    final (json, code) = await put(
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
    return switch ((code, json)) {
      (200, Map json) => Program.fromJson(json),
      _ => throw json,
    };
  }

  /// The coach replaces one session of a copy, exercises included, from
  /// [baseRevision]. Conflicts as [editClientProgram].
  Future<void> editClientSession(
    String studentId,
    String programId,
    Template session, {
    required int baseRevision,
    required String changeId,
  }) async {
    final (json, code) = await put(
      Router.clientSession(studentId, programId, session.id),
      body: {...session.toMap(), 'baseRevision': baseRevision, 'changeId': changeId},
    );
    if (code != 200) throw json;
  }

  /// The coach removes a session of a copy. Harmless twice.
  Future<void> deleteClientSession(String studentId, String programId, String sessionId) async {
    final (json, code) = await delete(Router.clientSession(studentId, programId, sessionId));
    if (code != 204) throw json;
  }

  /// What changed in a copy, oldest first, from [since] on.
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since}) async {
    final (json, code) = await get(
      Router.clientProgramChanges(studentId, programId),
      query: {'since': ?since},
    );
    return switch ((code, json)) {
      (200, Map json) => ProgramChanges.fromJson(json).changes,
      _ => throw json,
    };
  }

  /// Puts [changeId] back, as a new change. `409` when the client has since
  /// built on it, thrown whole.
  Future<void> revertClientChange(String studentId, String programId, String changeId) async {
    final (json, code) = await post(Router.clientChangeRevert(studentId, programId, changeId));
    if (code != 204) throw json;
  }
}
