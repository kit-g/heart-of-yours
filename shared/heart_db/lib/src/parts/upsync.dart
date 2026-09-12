part of '../../heart_db.dart';

/// One confirmed step of a replay, as the ledger holds it: which kind of row,
/// the id it has locally *after* confirmation, and what the server said.
typedef UpsyncEntry = ({String resource, String id, String outcome});

/// The store's half of the anonymous-to-account upsync (heart-of-yours#96):
/// moving a session's rows onto the account's uid, remembering that a replay
/// is owed and how far it got, and rewriting references when the server
/// merged a row onto one the account already had.
///
/// The replay loop itself lives in `heart_state`; this is only what has to
/// happen inside the database, in transactions.
mixin _Upsync on _LocalDatabase {
  /// The `syncs` key under which a replay owed to [userId] is recorded — the
  /// same table the health backfill uses for "how far have we got", keyed per
  /// uid for the same reason: a second account on the device must not inherit
  /// the first one's debt.
  static String _owedKey(String userId) => 'upsync:$userId';

  /// Moves every row the store holds under [from] onto [to], in one
  /// transaction — the "existing account" case, where the anonymous uid is
  /// replaced by the account's and the rows have to follow.
  ///
  /// `OR REPLACE`, because the account may already have a mirror on this
  /// device from an earlier sign-in, and the two can collide on a natural key:
  /// a unit preference for the same exercise, the same health sample, the same
  /// chart. The anonymous device is where the user has been training, so its
  /// row is the most recent intent and wins. Row ids are uuids and never
  /// collide across uids; the clause costs nothing there.
  ///
  /// The health backfill markers move too: they are a fact about this device's
  /// health store, which is the same store under either uid.
  Future<void> rekeyUser(String from, String to) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        for (final table in [
          _workouts,
          _templates,
          _templateFolders,
          _exerciseDetails,
          _exercises,
          _charts,
          _goals,
          _healthSamples,
          _upsync,
        ]) {
          batch.rawUpdate('UPDATE OR REPLACE $table SET user_id = ? WHERE user_id = ?', [to, from]);
        }
        batch.rawUpdate(
          'UPDATE OR REPLACE $_syncs SET table_name = ? || substr(table_name, ?) WHERE table_name LIKE ?',
          ['health_backfill:$to:', 'health_backfill:$from:'.length + 1, 'health_backfill:$from:%'],
        );
        await batch.commit(noResult: true);
      },
    );
  }

  /// Records that [userId]'s store is owed a replay. Idempotent: a second call
  /// during an unfinished run changes nothing.
  Future<void> oweUpsync(String userId) {
    return _db.insert(
      _syncs,
      {'table_name': _owedKey(userId)},
      conflictAlgorithm: .ignore,
    );
  }

  Future<bool> isUpsyncOwed(String userId) async {
    final rows = await _db.query(
      _syncs,
      columns: ['table_name'],
      where: 'table_name = ?',
      whereArgs: [_owedKey(userId)],
    );
    return rows.isNotEmpty;
  }

  /// Every step of [userId]'s replay the server has already answered.
  Future<List<UpsyncEntry>> upsyncLedger(String userId) async {
    final rows = await _db.query(_upsync, where: 'user_id = ?', whereArgs: [userId]);
    return [
      for (final row in rows)
        (resource: row['resource'] as String, id: row['id'] as String, outcome: row['outcome'] as String),
    ];
  }

  Future<void> recordUpsync(String userId, UpsyncEntry entry) {
    return _db.insert(
      _upsync,
      {'user_id': userId, 'resource': entry.resource, 'id': entry.id, 'outcome': entry.outcome},
      conflictAlgorithm: .replace,
    );
  }

  /// The run is complete: the debt goes, the ledger stays.
  ///
  /// The ledger is the only durable record that the server has seen an
  /// exercise, a unit preference, a folder or a template — those four have no
  /// `synced` column the way workouts and goals do, so [_planFor] asks the
  /// ledger and nothing else. Clearing it here meant every sign-out and back
  /// in — which is an anonymous session becoming an account, so a replay is
  /// owed every time — re-posted the whole account: 19 customs, 3 unit
  /// preferences, 2 folders and 2 templates, answered `200` and reported as
  /// "3 uploaded, 23 already there" forever.
  ///
  /// Keeping it costs one row per row the server has confirmed, and
  /// [eraseUser] drops them with the rest of the uid's data.
  Future<void> settleUpsync(String userId) {
    return _db.delete(_syncs, where: 'table_name = ?', whereArgs: [_owedKey(userId)]);
  }

  /// The server answered a replayed custom exercise with an id other than the
  /// one sent — the account already had one by that name — so everything of
  /// [userId]'s that pointed at [from] now points at [to], and the row under
  /// [from] goes.
  ///
  /// The row under [to] must already be stored (the server's copy); the
  /// references move before the old row is deleted, because deleting it first
  /// would cascade the workout and template exercises away with it.
  Future<void> mergeExercise(String userId, {required String from, required String to}) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        batch.rawUpdate(
          'UPDATE $_workoutExercises SET exercise_id = ? '
          'WHERE exercise_id = ? AND workout_id IN (SELECT id FROM $_workouts WHERE user_id = ?)',
          [to, from, userId],
        );
        batch.rawUpdate(
          'UPDATE $_templatesExercises SET exercise_id = ? '
          'WHERE exercise_id = ? AND template_id IN (SELECT id FROM $_templates WHERE user_id = ?)',
          [to, from, userId],
        );
        // the preference on the merged exercise wins over one the account
        // already had, like every other local-first write in the replay
        batch.rawUpdate(
          'UPDATE OR REPLACE $_exerciseDetails SET exercise_id = ? WHERE exercise_id = ? AND user_id = ?',
          [to, from, userId],
        );
        batch.rawUpdate(
          'UPDATE $_goals SET exercise_id = ? WHERE exercise_id = ? AND user_id = ?',
          [to, from, userId],
        );
        // a chart preference keeps its exercise inside a JSON blob; the id is
        // a quoted string value there and nowhere else in the blob
        batch.rawUpdate(
          'UPDATE OR REPLACE $_charts SET data = replace(data, ?, ?) WHERE user_id = ? AND data LIKE ?',
          ['"$from"', '"$to"', userId, '%"$from"%'],
        );
        batch.delete(_exercises, where: 'id = ? AND user_id = ?', whereArgs: [from, userId]);
        await batch.commit(noResult: true);
      },
    );
  }

  /// The folder counterpart of [mergeExercise]: [userId]'s templates filed
  /// under [from] are refiled under [to], and the folder row under [from] goes.
  Future<void> mergeFolder(String userId, {required String from, required String to}) {
    return _db.transaction(
      (txn) async {
        await txn.update(
          _templates,
          {'folder_id': to},
          where: 'folder_id = ? AND user_id = ?',
          whereArgs: [from, userId],
        );
        await txn.delete(_templateFolders, where: 'id = ? AND user_id = ?', whereArgs: [from, userId]);
      },
    );
  }
}
