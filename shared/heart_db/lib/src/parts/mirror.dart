part of '../../heart_db.dart';

/// The mirror's own answer to the question `GET /accounts/summary` answers for
/// the server: how many rows are here, and which is the newest.
///
/// Same shape on both sides on purpose — an [AccountSummary] compared against
/// an [AccountSummary] — so the completeness check in `heart_state` is a
/// comparison and not a translation. Ids are uuid v7 and render as canonical
/// lowercase hex, so `max(id)` over text is `max(id)` over time, the way the
/// server's `max(id::text)` is.
///
/// Only the collections a *mirror* can answer for appear. The account holds
/// more than this — comments, connections, shares, the preferences table the
/// app spreads across `exercise_details` and `charts` — and a count of zero
/// for those would read as "the server has rows I am missing" when it means
/// "this device does not keep that". Absent is the honest answer, and
/// `exportedCollections` in `heart_state` is the list that drives the compare.
mixin _Mirror on _LocalDatabase {
  /// Where each comparable collection lives, and what counts as one of its
  /// rows under a user.
  ///
  /// The rule is *what the server would also count*, because that is the only
  /// thing a comparison against it can mean. So a workout counts once it is
  /// synced, and a template once it has a name — an unnamed draft and a
  /// workout the server has never been told about are local-only states, and
  /// counting them would inflate the mirror's side and hide the very shortfall
  /// this is here to find.
  ///
  /// `synced`, not "finished": the account holds abandoned sessions too — 2 of
  /// this dev account's 568 have no `end` — so filtering on one would leave the
  /// mirror permanently two short of a target it could never reach, and the
  /// backfill would page the whole history down again on every launch.
  static const _sources = <ExportableCollection, ({String table, String where})>{
    .customExercises: (table: _exercises, where: 'user_id = ? AND own = 1'),
    .templateFolders: (table: _templateFolders, where: 'user_id = ?'),
    .templates: (table: _templates, where: 'user_id = ? AND name IS NOT NULL'),
    .workouts: (table: _workouts, where: 'user_id = ? AND synced = 1'),
    .goals: (table: _goals, where: 'user_id = ?'),
  };

  /// The `syncs` key under which a completed history backfill is recorded,
  /// keyed per uid for the same reason the health backfill is: a second
  /// account on this device must not inherit the first one's "already whole".
  static String historyBackfillKey(String userId) => 'history_backfill:$userId';

  /// Whether [userId]'s history has been paged down in full on this device.
  ///
  /// The mark is the reason a normal launch asks the server nothing: it is
  /// written only after a run whose count matched the account's, so its
  /// presence is a claim the mirror is whole rather than a note that a run
  /// once started.
  Future<bool> isHistoryBackfilled(String userId) async {
    final rows = await _db.query(
      _syncs,
      where: 'table_name = ?',
      whereArgs: [historyBackfillKey(userId)],
    );
    return rows.isNotEmpty;
  }

  Future<void> markHistoryBackfilled(String userId) async {
    await _db.insert(
      _syncs,
      {'table_name': historyBackfillKey(userId), 'synced_at': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: .replace,
    );
  }

  /// The account gained rows this device did not put there, so the claim that
  /// the mirror is whole is no longer one this device can make.
  Future<void> clearHistoryBackfilled(String userId) async {
    await _db.delete(_syncs, where: 'table_name = ?', whereArgs: [historyBackfillKey(userId)]);
  }

  /// What this device holds for [userId], collection by collection.
  Future<AccountSummary> mirrorSummary(String userId) async {
    // one statement, one round trip: a scalar subquery per column, in the
    // order [_sources] declares
    final selects = [
      for (final MapEntry(key: collection, value: (:table, :where)) in _sources.entries) ...[
        '(SELECT count(*) FROM $table WHERE $where) AS ${collection.name}_count',
        '(SELECT max(id) FROM $table WHERE $where) AS ${collection.name}_head',
      ],
    ];

    final rows = await _db.rawQuery(
      'SELECT ${selects.join(', ')}',
      List.filled(_sources.length * 2, userId),
    );

    final row = rows.first;
    return AccountSummary(
      collections: {
        for (final collection in _sources.keys)
          collection: CollectionSummary(
            count: switch (row['${collection.name}_count']) {
              final num count => count.toInt(),
              _ => 0,
            },
            latestId: row['${collection.name}_head'] as String?,
          ),
      },
    );
  }
}
