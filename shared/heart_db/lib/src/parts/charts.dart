part of '../../heart_db.dart';

mixin _Charts on _LocalDatabase implements ChartPreferenceService {
  @override
  Future<Iterable<ChartPreference>> getPreferences(String userId) {
    return _db.query(_charts, where: 'user_id = ?', whereArgs: [userId], orderBy: 'sort_order').then(
      (rows) {
        return rows.map(ChartPreference.fromRow);
      },
    );
  }

  @override
  Future<ChartPreference> saveChartPreference(
    ChartPreference preference,
    String userId,
  ) async {
    final row = {
      ...preference.toRow(),
      'user_id': userId,
      // a freshly saved chart lands at the end of the user's list
      'sort_order': await _nextChartOrder(userId),
    };
    final id = await _db.insert(_charts, row, conflictAlgorithm: .replace);
    return preference.copyWith(id: id.toString());
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
