part of '../api.dart';

/// Coaching messages (heart-of-yours#556): one thread per connection, whose
/// items are ciphertext the server never reads.
///
/// A refusal is thrown whole, as everywhere, so a caller branches on its
/// `code` (`thread_closed`, `rate_limited` with `retryAfter`, `stale_cursor`,
/// `not_implemented`).
mixin _ThreadRoutes on Requests {
  /// The one thread of [connectionId], opened the first time it is asked for.
  Future<Thread> openThread(String connectionId) async {
    final (json, code) = await post(Router.connectionThread(connectionId));
    return switch ((code, json)) {
      (200 || 201, Map json) => Thread.fromJson(json),
      _ => throw json,
    };
  }

  /// The inbox: every thread, last arrival first. Read whole or not at all:
  /// it replaces the device's inbox, where a thread skipped would be deleted.
  Future<List<Thread>> getThreads() async {
    final (json, code) = await get(Router.threads);
    return switch ((code, json)) {
      (200, {'threads': final List threads}) => [for (final each in threads) Thread.fromJson(each as Map)],
      _ => throw json,
    };
  }

  /// Stores one item. [id] is the device's, so a retry answers the stored item
  /// rather than storing it twice. [content] is ciphertext; [commitment] the
  /// franking commitment beside it. The answer carries what a report needs
  /// later: the server's `tag`, `tagKey` and `createdAt`.
  Future<ThreadItem> postThreadItem(
    String threadId, {
    required String id,
    required String content,
    required String commitment,
    required DateTime at,
    String? subjectType,
    String? subjectId,
  }) async {
    final (json, code) = await post(
      Router.threadItems(threadId),
      body: {
        'id': id,
        'kind': 'message',
        'content': content,
        'commitment': commitment,
        'at': at.toUtc().toIso8601String(),
        'subjectType': ?subjectType,
        'subjectId': ?subjectId,
      },
    );
    return switch ((code, json)) {
      (200 || 201, Map json) => ThreadItem.fromJson(json),
      _ => throw json,
    };
  }

  /// A page of [threadId]'s items: after [since] in stored order, or before
  /// [before] newest first, or the newest when neither is given. `cursor` is
  /// there only when more follow in the same direction.
  Future<({List<ThreadItem> items, String? cursor})> getThreadItems(
    String threadId, {
    String? since,
    String? before,
    int? limit,
  }) async {
    final (json, code) = await get(
      Router.threadItems(threadId),
      query: switch ({'since': ?since, 'before': ?before, 'limit': ?limit?.toString()}) {
        final Map<String, String> query when query.isNotEmpty => query,
        _ => null,
      },
    );
    return switch ((code, json)) {
      (200, {'items': final List items}) => (
        items: [
          for (final each in items)
            if (each is Map) ThreadItem.fromJson(each),
        ],
        cursor: json['cursor'] as String?,
      ),
      _ => throw json,
    };
  }

  /// Moves this person's read position in [threadId] to [cursor].
  Future<void> markThreadRead(String threadId, String cursor) async {
    final (json, code) = await put(Router.threadRead(threadId), body: {'cursor': cursor});
    if (code != 204) throw json;
  }
}
