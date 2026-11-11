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
}
