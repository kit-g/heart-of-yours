part of '../../heart_db.dart';

/// One stored thread item and where it sits: [position] is the server's order
/// as this device met it, null for one not sent yet ([pending]).
typedef StoredThreadItem = ({ThreadItem item, int? position, bool pending});

/// Coaching messages (#556), kept so a thread opens offline: the inbox, and
/// each thread's items as ciphertext.
mixin _Threads on _LocalDatabase {
  Future<List<Thread>> getThreads(String userId) async {
    final rows = await _db.query(_threads, where: 'user_id = ?', whereArgs: [userId], orderBy: 'last_at DESC, id DESC');
    return [for (final row in rows) _thread(row)];
  }

  /// Makes [threads] the whole inbox of [userId]'s. Their items stay: a
  /// thread gone from the inbox may come back, and what was said is the
  /// thread's own to drop.
  Future<void> storeThreads(String userId, Iterable<Thread> threads) {
    return _db.transaction((txn) async {
      final batch = txn.batch()..delete(_threads, where: 'user_id = ?', whereArgs: [userId]);
      for (final thread in threads) {
        batch.insert(_threads, _threadRow(userId, thread), conflictAlgorithm: .replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// One thread, added or as it now stands.
  Future<void> storeThread(String userId, Thread thread) {
    return _db.insert(_threads, _threadRow(userId, thread), conflictAlgorithm: .replace);
  }

  /// [threadId]'s items in the server's order, then those not sent yet, in
  /// the order they were written.
  Future<List<StoredThreadItem>> getThreadItems(String userId, String threadId) async {
    final rows = await _db.query(
      _threadItems,
      where: 'user_id = ? AND thread_id = ?',
      whereArgs: [userId, threadId],
      orderBy: 'position IS NULL, position, at, id',
    );
    return [
      for (final row in rows)
        (
          item: ThreadItem(
            id: row['id'] as String,
            threadId: row['thread_id'] as String,
            senderId: row['sender_id'] as String?,
            kind: row['kind'] as String,
            subjectType: row['subject_type'] as String?,
            subjectId: row['subject_id'] as String?,
            content: row['content'] as String,
            commitment: row['commitment'] as String,
            tag: row['tag'] as String? ?? '',
            tagKey: row['tag_key'] as String? ?? '',
            at: DateTime.parse(row['at'] as String),
            createdAt: switch (row['created_at']) {
              final String at => DateTime.parse(at),
              _ => DateTime.parse(row['at'] as String),
            },
            cursor: row['cursor'] as String?,
          ),
          position: row['position'] as int?,
          pending: row['pending'] == 1,
        ),
    ];
  }

  /// Adds [items], or replaces those already here by id.
  Future<void> storeThreadItems(String userId, Iterable<StoredThreadItem> items) {
    return _db.transaction((txn) async {
      final batch = txn.batch();
      for (final (:item, :position, :pending) in items) {
        batch.insert(_threadItems, {
          'user_id': userId,
          'id': item.id,
          'thread_id': item.threadId,
          'sender_id': item.senderId,
          'kind': item.kind,
          'subject_type': item.subjectType,
          'subject_id': item.subjectId,
          'content': item.content,
          'commitment': item.commitment,
          'tag': switch (pending) {
            true => null,
            false => item.tag,
          },
          'tag_key': switch (pending) {
            true => null,
            false => item.tagKey,
          },
          'at': item.at.toUtc().toIso8601String(),
          'created_at': switch (pending) {
            true => null,
            false => item.createdAt.toUtc().toIso8601String(),
          },
          'cursor': item.cursor,
          'position': position,
          'pending': switch (pending) {
            true => 1,
            false => 0,
          },
        }, conflictAlgorithm: .replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Drops one item, as one written here that the server will never take.
  Future<void> deleteThreadItem(String userId, String itemId) {
    return _db.delete(_threadItems, where: 'user_id = ? AND id = ?', whereArgs: [userId, itemId]);
  }

  Thread _thread(Map<String, Object?> row) {
    DateTime? at(String column) => switch (row[column]) {
      final String at => DateTime.parse(at),
      _ => null,
    };
    return Thread(
      id: row['id'] as String,
      connectionId: row['connection_id'] as String?,
      otherId: row['other_id'] as String?,
      otherName: row['other_name'] as String?,
      otherAvatar: row['other_avatar'] as String?,
      unread: row['unread'] as int? ?? 0,
      lastAt: at('last_at'),
      clearedAt: at('cleared_at'),
      clearedBy: row['cleared_by'] as String?,
    );
  }

  Map<String, Object?> _threadRow(String userId, Thread thread) {
    return {
      'user_id': userId,
      'id': thread.id,
      'connection_id': thread.connectionId,
      'other_id': thread.otherId,
      'other_name': thread.otherName,
      'other_avatar': thread.otherAvatar,
      'unread': thread.unread,
      'last_at': thread.lastAt?.toUtc().toIso8601String(),
      'cleared_at': thread.clearedAt?.toUtc().toIso8601String(),
      'cleared_by': thread.clearedBy,
    };
  }
}
