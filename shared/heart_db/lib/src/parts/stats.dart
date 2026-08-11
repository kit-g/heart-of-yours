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
    // The user's week, matching `WorkoutAggregation.fromRows`, which buckets by
    // the local calendar — then converted to UTC, because that is the zone
    // `start` is stored in and the comparison is lexicographic.
    final cutoff = getMonday(DateTime.now()).subtract(Duration(days: 7 * (weeksBack ?? 0))).toUtc().toIso8601String();
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

  /// Every finished workout the user has, with no period bound.
  ///
  /// What a "do N workouts" milestone counts. Local, so it counts what this
  /// device has pulled down — history is paged, so a user who has never opened
  /// far enough back can be undercounted until they do.
  Future<int> getTotalWorkoutCount({String? userId}) {
    return _db
        .rawQuery(
          'SELECT count(*) AS c FROM workouts WHERE end IS NOT NULL AND user_id = ?',
          [userId],
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
    // Bounds in [d]'s own zone so "this month" is the month the user is living
    // in, then converted to UTC: `start` is stored as a UTC ISO string, and the
    // comparison is lexicographic, so both sides have to be in the same zone.
    final from = DateTime(d.year, d.month).toUtc();
    final to = DateTime(d.year, d.month + 1).toUtc();
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
    // the user's week, expressed in the zone `start` is stored in — see
    // [getMonthlyWorkoutCount]
    final monday = getMonday(d).toUtc();
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
