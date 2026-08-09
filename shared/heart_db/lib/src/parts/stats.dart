part of '../../heart_db.dart';

mixin _Stats on _LocalDatabase implements StatsService {
  @override
  Future<WorkoutAggregation> getWorkoutSummary({
    int? weeksBack = 8,
    String? userId,
  }) {
    // `user_id = NULL` matches nothing (and a null whereArg will throw in a
    // future sqflite), so answer the degenerate query directly
    if (userId == null) return Future.value(WorkoutAggregation.empty());
    final cutoff = getMonday(
      DateTime.timestamp(),
    ).subtract(Duration(days: 7 * (weeksBack ?? 0))).toIso8601String();
    return _db
        .query(
          _workouts,
          where: 'start >= ? AND end IS NOT NULL AND user_id = ?',
          whereArgs: [cutoff, userId],
        )
        .then(
          (rows) {
            if (rows.isEmpty) return WorkoutAggregation.empty();
            return WorkoutAggregation.fromRows(rows);
          },
        );
  }

  /// Finished workouts in [d]'s calendar month.
  ///
  /// Not on [StatsService]: the weekly count is, and this belongs beside it, but
  /// that interface ships from the API repo. Reached through `LocalStatsService`
  /// meanwhile, the way local-only goal reads already are.
  ///
  /// Bounded on `start` and in [d]'s own zone, so "this month" means the month
  /// the user is living in rather than UTC's. `end IS NOT NULL` matches the
  /// aggregation's rule — an unfinished workout is not one you have done.
  Future<int> getMonthlyWorkoutCount(DateTime d, {String? userId}) {
    final from = DateTime(d.year, d.month);
    final to = DateTime(d.year, d.month + 1);
    return _db
        .rawQuery(
          'SELECT count(*) AS c FROM workouts '
          'WHERE start >= ? AND start < ? AND end IS NOT NULL AND user_id = ?',
          [from.toIso8601String(), to.toIso8601String(), userId],
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

  @override
  /// [userId] is an addition to the shared signature — an override may widen
  /// with optional parameters — because without it this counted every account
  /// that had ever signed in on the device. A null one matches nothing, same as
  /// [getWorkoutSummary]: `user_id = NULL` is never true, so there is no user to
  /// count for.
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId}) {
    final monday = getMonday(d);
    // a workout belongs to the week it started in; the old
    // `start > monday AND end < next` dropped week-spanning workouts entirely
    return _db
        .rawQuery(
          'SELECT count(*) AS c FROM workouts '
          'WHERE start >= ? AND start < ? AND end IS NOT NULL AND user_id = ?',
          [
            monday.toIso8601String(),
            (monday.add(const Duration(days: 7)).toIso8601String()),
            userId,
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
