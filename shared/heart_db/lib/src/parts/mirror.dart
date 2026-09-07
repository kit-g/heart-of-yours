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
  /// A workout is counted once it is finished, and a template once it has a
  /// name: an unfinished workout and an unnamed draft are local-only states
  /// the server never sees. Counting them would inflate the mirror's side and
  /// hide the very shortfall this is here to find.
  static const _sources = <ExportableCollection, ({String table, String where})>{
    .customExercises: (table: _exercises, where: 'user_id = ? AND own = 1'),
    .templateFolders: (table: _templateFolders, where: 'user_id = ?'),
    .templates: (table: _templates, where: 'user_id = ? AND name IS NOT NULL'),
    .workouts: (table: _workouts, where: 'user_id = ? AND "end" IS NOT NULL'),
    .goals: (table: _goals, where: 'user_id = ?'),
  };

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
