part of '../../heart_db.dart';

mixin _Timers on _LocalDatabase implements TimersService {
  @override
  Future<void> setRestTimer({
    required String exerciseName,
    required String userId,
    required int? seconds,
  }) {
    return _db.transaction(
      (txn) async {
        final rows = await txn.query(
          _exerciseDetails,
          where: 'exercise_id = ? AND user_id = ?',
          whereArgs: [exerciseName, userId],
        );

        switch (rows) {
          case [Map _]: // exists
            txn.update(
              _exerciseDetails,
              {'rest_timer': seconds},
              where: 'exercise_id = ? AND user_id = ?',
              whereArgs: [exerciseName, userId],
            );
          default: // new
            txn.insert(
              _exerciseDetails,
              {
                'rest_timer': seconds,
                'exercise_id': exerciseName,
                'user_id': userId,
              },
              conflictAlgorithm: .replace,
            );
        }
      },
    );
  }

  @override
  Future<Map<String, int>> getTimers(String userId) async {
    final rows = await _db.query(
      _exerciseDetails,
      columns: ['exercise_id', 'rest_timer'],
      where: 'user_id = ? AND rest_timer IS NOT NULL',
      whereArgs: [userId],
    );

    return Map.fromEntries(
      rows.map(
        (row) {
          return MapEntry(
            row['exercise_id'] as String,
            row['rest_timer'] as int,
          );
        },
      ),
    );
  }
}
