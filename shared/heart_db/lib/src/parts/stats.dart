part of '../../heart_db.dart';

mixin _Stats on _LocalDatabase implements StatsService {
  @override
  Future<WorkoutAggregation> getWorkoutSummary({
    int? weeksBack = 8,
    String? userId,
  }) {
    final cutoff = getMonday(
      DateTime.timestamp(),
    ).subtract(Duration(days: 7 * (weeksBack ?? 0))).toIso8601String();
    return _db
        .query(
          _workouts,
          where: 'start > ? AND end IS NOT NULL AND user_id = ?',
          whereArgs: [cutoff, userId],
        )
        .then(
          (rows) {
            if (rows.isEmpty) return WorkoutAggregation.empty();
            return WorkoutAggregation.fromRows(rows);
          },
        );
  }

  @override
  Future<int> getWeeklyWorkoutCount(DateTime d) {
    final monday = getMonday(d);
    return _db
        .rawQuery(
          'SELECT count(*) AS c FROM workouts WHERE start > ? AND end < ?',
          [
            monday.toIso8601String(),
            (monday.add(const Duration(days: 7)).toIso8601String()),
          ],
        )
        .then(
          (rows) {
            return switch (rows) {
              [{'c': num count}] => count.toInt(),
              _ => 0,
            };
          },
        );
  }
}
