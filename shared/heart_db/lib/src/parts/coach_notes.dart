part of '../../heart_db.dart';

/// One stored note of a coach's: [pending] for a write or a deletion the
/// server hasn't taken, [deleted] for one deleted here.
typedef StoredCoachNote = ({CoachNote note, bool pending, bool deleted});

/// A coach's notes on their clients (#556), kept as ciphertext so they open
/// offline.
mixin _CoachNotes on _LocalDatabase {
  /// Every note of [userId]'s, deleted ones included, last edited first.
  Future<List<StoredCoachNote>> getCoachNotes(String userId) async {
    final rows = await _db.query(
      _coachNotes,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC, id DESC',
    );
    return [
      for (final row in rows)
        (
          note: CoachNote(
            id: row['id'] as String,
            connectionId: row['connection_id'] as String?,
            content: row['content'] as String,
            updatedAt: DateTime.parse(row['updated_at'] as String),
          ),
          pending: row['pending'] == 1,
          deleted: row['deleted'] == 1,
        ),
    ];
  }

  /// Adds [notes], or replaces those already here by id.
  Future<void> storeCoachNotes(String userId, Iterable<StoredCoachNote> notes) {
    return _db.transaction((txn) async {
      final batch = txn.batch();
      for (final each in notes) {
        batch.insert(_coachNotes, _coachNoteRow(userId, each), conflictAlgorithm: .replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Makes [notes], as the server holds them, every note of [userId]'s,
  /// except where a change made here waits to be sent: that one stays as it
  /// is, and goes next.
  Future<void> replaceCoachNotes(String userId, Iterable<CoachNote> notes) {
    return _db.transaction((txn) async {
      final waiting = {
        for (final row in await txn.query(
          _coachNotes,
          columns: ['id'],
          where: 'user_id = ? AND pending = 1',
          whereArgs: [userId],
        ))
          row['id'] as String,
      };
      final batch = txn.batch()..delete(_coachNotes, where: 'user_id = ? AND pending = 0', whereArgs: [userId]);
      for (final note in notes) {
        if (waiting.contains(note.id)) continue;
        batch.insert(
          _coachNotes,
          _coachNoteRow(userId, (note: note, pending: false, deleted: false)),
          conflictAlgorithm: .replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Forgets the note [id]: one the server no longer holds.
  Future<void> deleteCoachNote(String userId, String id) {
    return _db.delete(_coachNotes, where: 'user_id = ? AND id = ?', whereArgs: [userId, id]);
  }

  Map<String, Object?> _coachNoteRow(String userId, StoredCoachNote stored) {
    final (:note, :pending, :deleted) = stored;
    return {
      'user_id': userId,
      'id': note.id,
      'connection_id': note.connectionId,
      'content': note.content,
      'updated_at': note.updatedAt.toUtc().toIso8601String(),
      'pending': switch (pending) {
        true => 1,
        false => 0,
      },
      'deleted': switch (deleted) {
        true => 1,
        false => 0,
      },
    };
  }
}
