part of '../../heart_db.dart';

/// "Erase my data": everything the store holds under one uid, gone.
///
/// An anonymous session has no account to delete and nothing on a server, so
/// the device store is the whole of what the user holds — and the one place
/// it can be wiped from. Rows keyed to another uid, and the shared catalog
/// (`user_id IS NULL`), are not touched: a phone that signs an account in and
/// out again keeps that account's mirror.
mixin _Erase on _LocalDatabase {
  /// Deletes every row under [userId], in one transaction.
  ///
  /// Children go before parents on purpose. The schema cascades `workouts →
  /// workout_exercises → sets` and `templates → template_exercises`, but only
  /// while `PRAGMA foreign_keys` is on — a per-connection setting [init] asks
  /// for and nothing else guarantees. A wipe that leaves orphaned sets behind
  /// on a connection without it would be silent, so the cascade is spelled
  /// out instead of relied on.
  ///
  /// The health backfill markers live in `syncs` under a key carrying the uid
  /// (see [_Health]), so they are cleared here too: a fresh uid re-reads the
  /// device store from scratch, as a first launch does.
  Future<void> eraseUser(String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        batch.rawDelete(
          '''
          DELETE FROM $_sets
          WHERE exercise_id IN (
            SELECT we.id FROM $_workoutExercises we
            JOIN $_workouts w ON w.id = we.workout_id
            WHERE w.user_id = ?
          )
          ''',
          [userId],
        );
        batch.rawDelete(
          'DELETE FROM $_workoutExercises WHERE workout_id IN (SELECT id FROM $_workouts WHERE user_id = ?)',
          [userId],
        );
        batch.delete(_workouts, where: 'user_id = ?', whereArgs: [userId]);
        batch.rawDelete(
          'DELETE FROM $_templatesExercises WHERE template_id IN (SELECT id FROM $_templates WHERE user_id = ?)',
          [userId],
        );
        batch.delete(_templates, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_templateFolders, where: 'user_id = ?', whereArgs: [userId]);
        // per-exercise rest timers and unit overrides
        batch.delete(_exerciseDetails, where: 'user_id = ?', whereArgs: [userId]);
        // the user's own exercises; the catalog has no uid and stays
        batch.delete(_exercises, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_charts, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_goals, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_healthSamples, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_syncs, where: 'table_name LIKE ?', whereArgs: ['health_backfill:$userId:%']);
        // a replay owed to the uid, and how far it got — nothing left to replay
        batch.delete(_upsync, where: 'user_id = ?', whereArgs: [userId]);
        batch.delete(_syncs, where: 'table_name = ?', whereArgs: [_Upsync._owedKey(userId)]);
        await batch.commit(noResult: true);
      },
    );
  }
}
