part of '../../heart_db.dart';

/// The dashboard's charts, one table in one order.
///
/// An exercise's metric is heart_models' [ChartPreference]. The training-wide
/// charts (#137) are the app's own kinds and live in the same rows, so they
/// share the order and the removal: the [getChartRows] / [saveChartRow] pair
/// hands them over as stored, and the app reads what it knows. A row of a kind
/// a build predates is skipped by [getPreferences], never thrown on.
mixin _Charts on _LocalDatabase implements ChartPreferenceService {
  @override
  Future<Iterable<ChartPreference>> getPreferences(String userId) {
    return getChartRows(userId).then(
      (rows) {
        return _readable(rows, ChartPreference.fromRow, what: 'chart');
      },
    );
  }

  /// Every chart row of [userId]'s, in the dashboard's order, as stored.
  Future<List<Map<String, Object?>>> getChartRows(String userId) {
    return _db.query(_charts, where: 'user_id = ?', whereArgs: [userId], orderBy: 'sort_order');
  }

  @override
  Future<ChartPreference> saveChartPreference(
    ChartPreference preference,
    String userId,
  ) async {
    final id = await saveChartRow(preference.toRow(), userId);
    return preference.copyWith(id: id);
  }

  /// Stores [row] (its `type` and `data`) as [userId]'s newest chart and
  /// returns the id it was given.
  Future<String> saveChartRow(Map<String, Object?> row, String userId) async {
    final stored = {
      ...row,
      'user_id': userId,
      // a freshly saved chart lands at the end of the user's list
      'sort_order': await _nextChartOrder(userId),
    };
    final id = await _db.insert(_charts, stored, conflictAlgorithm: .replace);
    return id.toString();
  }

  /// Replaces the `data` of [userId]'s chart [chartId] with [data], as
  /// stored (JSON), keeping its place.
  Future<void> updateChartData(String chartId, String data, String userId) {
    return _db.update(
      _charts,
      {'data': data},
      where: 'id = ? AND user_id = ?',
      whereArgs: [chartId, userId],
      // the same chart already stored with this data: the one being changed
      // keeps what it had rather than failing the write
      conflictAlgorithm: .ignore,
    );
  }

  Future<int> _nextChartOrder(String userId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next FROM $_charts WHERE user_id = ?',
      [userId],
    );
    return switch (rows) {
      [{'next': int next}] => next,
      _ => 0,
    };
  }

  @override
  Future<void> saveChartOrder(Iterable<String> orderedIds, String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        for (final (index, id) in orderedIds.indexed) {
          batch.update(
            _charts,
            {'sort_order': index},
            where: 'id = ? AND user_id = ?',
            whereArgs: [id, userId],
          );
        }
        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> deleteChartPreference(String preferenceId, String userId) {
    return _db.delete(
      _charts,
      where: 'id = ? AND user_id = ?',
      whereArgs: [preferenceId, userId],
    );
  }
}
