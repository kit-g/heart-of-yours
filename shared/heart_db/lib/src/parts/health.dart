part of '../../heart_db.dart';

mixin _Health on _LocalDatabase implements HealthSampleStore {
  @override
  Future<void> storeHealthSamples(Iterable<HealthSample> samples, String userId) async {
    if (samples.isEmpty) return;

    final batch = _db.batch();
    for (final sample in samples) {
      batch.insert(
        _healthSamples,
        {...sample.toRow(), 'user_id': userId},
        // Collides on the platform's sample UUID, so re-importing an
        // overlapping window rewrites rows instead of duplicating them.
        conflictAlgorithm: .replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<HealthSample>> getHealthSamples({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) {
    return _db
        .query(
          _healthSamples,
          where: 'user_id = ? AND metric = ? AND start >= ? AND start < ?',
          whereArgs: [userId, metric.value, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
          orderBy: 'start',
        )
        .then((rows) => rows.map(HealthSample.fromRow).toList());
  }

  @override
  Future<DateTime?> lastHealthSampleAt({
    required String userId,
    required HealthMetric metric,
  }) {
    return _db
        .rawQuery(
          'SELECT max(start) AS last FROM $_healthSamples WHERE user_id = ? AND metric = ?',
          [userId, metric.value],
        )
        .then(
          (rows) {
            return switch (rows) {
              [{'last': String last}] => DateTime.parse(last),
              _ => null,
            };
          },
        );
  }

  @override
  Future<List<HealthDailyValue>> getDailyHealth({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) {
    final sql = metric.isCumulative ? metrics.dailyCumulativeHealth : metrics.dailyAverageHealth;

    return _db.rawQuery(sql, [userId, metric.value, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()]).then(
      (rows) {
        return rows
            .map<HealthDailyValue?>(
              (row) {
                return switch (row) {
                  // `day` is a local calendar date, so it is parsed as a
                  // local DateTime — midnight of the user's day, not UTC's.
                  {'day': String day, 'value': num value} => (day: DateTime.parse(day), value: value.toDouble()),
                  _ => null,
                };
              },
            )
            .nonNulls
            .toList();
      },
    );
  }

  @override
  Future<void> deleteHealthSamples(String userId) async {
    await _db.delete(
      _healthSamples,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
