part of '../../heart_db.dart';

/// "Not today" (#312, heart-api#202): the days the user chose not to train.
/// A program's position reads them beside its workouts ([getProgramMarks]).
mixin _Skips on _LocalDatabase {
  /// [userId]'s skips, of [programId] or all of them, oldest first.
  Future<List<TrainingSkip>> getSkips(String userId, {String? programId}) async {
    final rows = await _db.query(
      _skips,
      where: switch (programId) {
        null => 'user_id = ?',
        String _ => 'user_id = ? AND program_id = ?',
      },
      whereArgs: [userId, ?programId],
      orderBy: 'at, id',
    );
    return _readable(rows, _skipOf, what: 'skip');
  }

  Future<void> storeSkip(TrainingSkip skip, String userId) => _storeSkip(_db, skip, userId);

  /// Replaces [userId]'s skips with [skips]: a full read from the server.
  Future<void> storeSkips(Iterable<TrainingSkip> skips, String userId) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_skips, where: 'user_id = ?', whereArgs: [userId]);
        for (final skip in skips) {
          await _storeSkip(txn, skip, userId);
        }
      },
    );
  }

  Future<void> deleteSkip(String skipId) => _db.delete(_skips, where: 'id = ?', whereArgs: [skipId]);

  static Future<void> _storeSkip(DatabaseExecutor db, TrainingSkip skip, String userId) {
    return db.insert(
      _skips,
      {
        'id': skip.id,
        'user_id': userId,
        'at': skip.at.toUtc().toIso8601String(),
        'reason': skip.reason,
        'weather': switch (skip.weather) {
          final Weather weather when !weather.isEmpty => jsonEncode(weather.toMap()),
          _ => null,
        },
        'template_id': skip.templateId,
        'program_id': skip.programId,
      },
      conflictAlgorithm: .replace,
    );
  }

  static TrainingSkip _skipOf(Map<String, Object?> row) {
    return TrainingSkip.fromRow({
      ...row,
      'weather': switch (row['weather']) {
        final String weather => jsonDecode(weather),
        _ => null,
      },
    });
  }
}
