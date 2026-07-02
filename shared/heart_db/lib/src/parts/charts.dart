part of '../../heart_db.dart';

mixin _Charts on _LocalDatabase implements ChartPreferenceService {
  @override
  Future<Iterable<ChartPreference>> getPreferences(String userId) {
    return _db.query(_charts, where: 'user_id = ?', whereArgs: [userId]).then(
      (rows) {
        return rows.map(ChartPreference.fromRow);
      },
    );
  }

  @override
  Future<ChartPreference> saveChartPreference(
    ChartPreference preference,
    String userId,
  ) {
    final row = {
      ...preference.toRow(),
      'user_id': userId,
    };
    return _db.insert(_charts, row, conflictAlgorithm: .replace).then(
      (id) {
        return preference.copyWith(id: id.toString());
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
