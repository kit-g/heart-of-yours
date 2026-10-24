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
          sql.workoutCount,
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

  /// Sets with an RPE in [userId]'s finished workouts (#244). Local, like the
  /// count above: an import's ratings show here once the mirror has pulled
  /// its workouts down.
  Future<int> getRatedSetCount(String userId) async {
    final rows = await _db.rawQuery(sql.ratedSetCount, [userId]);
    return switch (rows) {
      [{'c': num count}] => count.toInt(),
      _ => 0,
    };
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
    return getWorkoutCountBetween(DateTime(d.year, d.month), DateTime(d.year, d.month + 1), userId: userId);
  }

  /// Finished workouts that started in [from, to).
  ///
  /// The one count every period is built on: the caller decides where a week
  /// or a month begins — a week starts on the day the user chose (#339), which
  /// this layer has no business knowing. Pass bounds in the user's own zone;
  /// they are converted to UTC here because `start` is stored as a UTC ISO
  /// string and the comparison is lexicographic. A workout belongs to the
  /// period it started in, so one that spans a boundary counts once.
  Future<int> getWorkoutCountBetween(DateTime from, DateTime to, {String? userId}) {
    return _db
        .rawQuery(
          sql.workoutCountBetween,
          [from.toUtc().toIso8601String(), to.toUtc().toIso8601String(), userId],
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
  ///
  /// The shared signature's week is Monday's. The app counts the user's own
  /// week through [getWorkoutCountBetween] instead.
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId}) {
    final monday = getMonday(d);
    return getWorkoutCountBetween(monday, monday.add(const Duration(days: 7)), userId: userId);
  }

  /// Completed sets per exercise per finished workout started in [from, to),
  /// each with the workout's start and the exercise's muscle tagging — what
  /// the muscle map (#136) is counted from. Warm-ups are left out, as they are
  /// from records: they ready a muscle for the work, and the map counts the
  /// work (#236).
  ///
  /// Per workout rather than summed over the period, so one read serves every
  /// window and week the map shows: the caller buckets by `start` in the
  /// user's own calendar, which SQLite's UTC strings cannot do for it.
  ///
  /// Grouped by exercise rather than by muscle: the tagging is a JSON blob,
  /// and which muscles a tag covers is the body atlas's knowledge, not the
  /// database's. Read-only and schema-free, so the feature being off costs the
  /// database nothing and can break nothing in it.
  ///
  /// An exercise missing from `exercises` (a dangling id) comes back with
  /// empty tagging, as does a custom one nobody tagged: both are sets the map
  /// can only report as unmapped.
  Future<List<({DateTime start, MuscleTagging muscles, Target target, int sets})>> getMuscleSets(
    DateTime from,
    DateTime to, {
    String? userId,
  }) {
    if (userId == null) return Future.value(const []);
    return _db
        .rawQuery(
          sql.muscleSets,
          [userId, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
        )
        .then(
          (rows) => rows.map(
            (row) {
              return (
                start: DateTime.parse(row['start'] as String).toLocal(),
                muscles: switch (_blob(row['muscles'])) {
                  Map<String, dynamic> m => MuscleTagging.fromJson(m),
                  null => MuscleTagging.empty(),
                },
                target: _target(row['target']),
                sets: (row['sets'] as num).toInt(),
              );
            },
          ).toList(),
        );
  }

  /// Completed working sets per exercise per finished workout started in
  /// [from, to), each with the workout, its start and what the exercise is:
  /// its movement, muscle tagging and target. The pattern lens's read (#341),
  /// which counts sets and sessions per week by pattern or by muscle.
  ///
  /// The muscle map's read with the rest of the exercise: the workout says
  /// which sessions touched a key, the movement which patterns a set trains,
  /// and the target where an exercise nobody tagged still belongs. Warm-ups
  /// are left out, as they are from the map. Bucketing is the caller's, in
  /// the user's own week.
  Future<
    List<
      ({
        String workoutId,
        String exerciseId,
        DateTime start,
        Movement movement,
        MuscleTagging muscles,
        Target target,
        int sets,
      })
    >
  >
  getLensSets(DateTime from, DateTime to, {String? userId}) {
    if (userId == null) return Future.value(const []);
    return _db
        .rawQuery(
          sql.lensSets,
          [userId, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
        )
        .then(
          (rows) => rows.map(
            (row) {
              return (
                workoutId: row['workout_id'] as String,
                exerciseId: row['exercise_id'] as String,
                start: DateTime.parse(row['start'] as String).toLocal(),
                movement: switch (_blob(row['movement'])) {
                  Map<String, dynamic> m => Movement.fromJson(m),
                  null => Movement.empty(),
                },
                muscles: switch (_blob(row['muscles'])) {
                  Map<String, dynamic> m => MuscleTagging.fromJson(m),
                  null => MuscleTagging.empty(),
                },
                target: _target(row['target']),
                sets: (row['sets'] as num).toInt(),
              );
            },
          ).toList(),
        );
  }
}

/// What a finished workout amounted to, for the dashboard's training charts
/// (#137): when it started, how long it ran less its pauses, its working sets,
/// and the volume they moved, in kilograms.
typedef WorkoutTotalsRow = ({DateTime start, Duration duration, int sets, double volume});

mixin _TrainingTotals on _LocalDatabase {
  /// Every finished workout started in [from, to), with its totals: the
  /// training charts' read (#137). Bucketing into weeks or months is the
  /// caller's, in the user's own calendar, as with [getLensSets].
  Future<List<WorkoutTotalsRow>> getTrainingTotals(DateTime from, DateTime to, {String? userId}) {
    if (userId == null) return Future.value(const []);
    return _db
        .rawQuery(
          sql.trainingTotals,
          [userId, from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
        )
        .then(
          (rows) => _readable(
            rows,
            (row) {
              final start = DateTime.parse(row['start'] as String);
              final end = DateTime.parse(row['end'] as String);
              return (
                start: start.toLocal(),
                // a clock that moved backwards between start and end is not a
                // negative workout
                duration: switch (end.difference(start) - _paused(row['pauses'])) {
                  Duration d when d.isNegative => Duration.zero,
                  Duration d => d,
                },
                sets: (row['sets'] as num).toInt(),
                volume: (row['volume'] as num).toDouble(),
              );
            },
            what: 'workout totals',
          ),
        );
  }
}

/// The closed pauses stored with a workout, as one length (#134).
Duration _paused(Object? value) {
  return switch (value) {
    String s when s.isNotEmpty => switch (jsonDecode(s)) {
      List pauses =>
        pauses
            .whereType<Map>()
            .map(WorkoutPause.fromJson)
            .fold(
              Duration.zero,
              (sum, pause) => sum + pause.duration,
            ),
      _ => Duration.zero,
    },
    _ => Duration.zero,
  };
}

/// A non-empty JSON object stored as text, or null.
Map<String, dynamic>? _blob(Object? value) {
  return switch (value) {
    String s when s.isNotEmpty => switch (jsonDecode(s)) {
      Map<String, dynamic> m when m.isNotEmpty => m,
      _ => null,
    },
    _ => null,
  };
}

/// A stored target; a word this build predates reads as nothing to place by.
Target _target(Object? value) {
  return Target.values.firstWhere((each) => each.value == value, orElse: () => .other);
}
