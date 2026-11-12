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
}
