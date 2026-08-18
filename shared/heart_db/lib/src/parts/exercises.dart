part of '../../heart_db.dart';

mixin _Exercises on _LocalDatabase
    implements ExerciseService, ExerciseHistoryService, ExercisesMetricsService, PreviousExerciseService {
  @override
  Future<(DateTime?, Iterable<Exercise>)> getExercises({String? userId}) async {
    return _db.transaction<(DateTime?, Iterable<Exercise>)>(
      (txn) async {
        final rows = await txn.query(
          'exercises',
          where: 'user_id IS NULL OR user_id = ?',
          whereArgs: [userId],
        );

        final exercises = rows.map(
          (row) {
            final each = row.toCamel();
            switch (each['muscles']) {
              case String s:
                each['muscles'] = jsonDecode(s);
              case null:
                each['muscles'] = {};
            }

            switch (each['movement']) {
              case String s:
                each['movement'] = jsonDecode(s);
              case null:
                each['movement'] = {};
            }

            switch (each['health']) {
              case String s:
                each['health'] = jsonDecode(s);
              case null:
                each['health'] = {};
            }

            return Exercise.fromJson(each);
          },
        );

        final syncRows = await txn.query(
          _syncs,
          where: 'table_name = ?',
          whereArgs: [_exercises],
        );

        if (syncRows case [Map row]) {
          return (DateTime.tryParse(row['synced_at'] ?? ''), exercises);
        }
        return (null, exercises);
      },
    );
  }

  @override
  Future<void> storeExercises(
    Iterable<Exercise> exercises, {
    String? userId,
  }) async {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        for (final each in exercises) {
          var row = {
            for (final MapEntry(:key, :value) in each.toMap().entries) key.toSnake(): value,
          };
          if (each.isMine) row['user_id'] = userId;
          row['muscles'] = jsonEncode(each.muscles.toMap());
          // both blobs are omitted by `toMap()` when empty, so set them
          // unconditionally — the row is built generically from its keys, and a
          // missing one would leave the column untouched on conflict-update.
          row['movement'] = jsonEncode(each.movement.toMap());
          row['health'] = jsonEncode(each.health.toMap());
          // the unit preference is per-user (exercise_details), not a column on
          // the shared catalog row — see setExerciseUnit / getExerciseUnits.
          row.remove('unit_system');

          final columns = row.keys.join(', ');
          final placeholders = List.filled(row.length, '?').join(', ');
          final updates = row.keys.where((k) => k != 'name').map((k) => '$k = EXCLUDED.$k').join(', ');

          batch.rawInsert(
            '''
            INSERT INTO $_exercises ($columns)
            VALUES ($placeholders)
            ON CONFLICT(name) DO UPDATE SET $updates
            ''',
            row.values.toList(),
          );
        }

        txn.insert(_syncs, {
          'table_name': _exercises,
        }, conflictAlgorithm: .replace);

        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> setExerciseUnit({
    required String exerciseName,
    required String userId,
    required MeasurementUnit? unit,
  }) {
    return _db.transaction(
      (txn) async {
        final rows = await txn.query(
          _exerciseDetails,
          where: 'exercise_name = ? AND user_id = ?',
          whereArgs: [exerciseName, userId],
        );

        switch (rows) {
          case [Map _]: // exists
            txn.update(
              _exerciseDetails,
              {'unit_system': unit?.name},
              where: 'exercise_name = ? AND user_id = ?',
              whereArgs: [exerciseName, userId],
            );
          default: // new
            txn.insert(
              _exerciseDetails,
              {
                'unit_system': unit?.name,
                'exercise_name': exerciseName,
                'user_id': userId,
              },
              conflictAlgorithm: .replace,
            );
        }
      },
    );
  }

  @override
  Future<Map<String, MeasurementUnit>> getExerciseUnits(String userId) async {
    final rows = await _db.query(
      _exerciseDetails,
      columns: ['exercise_name', 'unit_system'],
      where: 'user_id = ? AND unit_system IS NOT NULL',
      whereArgs: [userId],
    );

    return Map.fromEntries(
      rows.map(
        (row) {
          return MapEntry(
            row['exercise_name'] as String,
            MeasurementUnit.fromString(row['unit_system'] as String),
          );
        },
      ),
    );
  }

  @override
  Future<Iterable<ExerciseAct>> getExerciseHistory(
    String userId,
    Exercise exercise, {
    int? pageSize,
    String? anchor,
  }) {
    return _db.rawQuery(sql.getExerciseHistory, [exercise.name, userId]).then<Iterable<ExerciseAct>>(
      (rows) {
        if (rows.isEmpty) return [];
        final grouped = rows.fold<Map<String, List<Map<String, dynamic>>>>(
          {},
          (acc, row) {
            final converted = row.toCamel();
            final workoutId = converted['workoutId'].toString();
            acc.putIfAbsent(workoutId, () => []).add(converted);
            return acc;
          },
        );
        return grouped.values.map(
          (group) => ExerciseAct.fromRows(exercise, group),
        );
      },
    );
  }

  @override
  Future<Map?> getRecord(String userId, Exercise exercise) {
    final query = switch (exercise.category) {
      .weightedBodyWeight => sql.weightRecord,
      .assistedBodyWeight => sql.weightRecord,
      .dumbbell => sql.weightRecord,
      .machine => sql.weightRecord,
      .barbell => sql.weightRecord,
      .repsOnly => sql.repsRecord,
      .cardio => sql.distanceRecord,
      .duration => sql.durationRecord,
    };
    return _db.rawQuery(query, [userId, exercise.name]).then(
      (rows) {
        return switch (rows) {
          [Map m] => m,
          _ => null,
        };
      },
    );
  }

  @override
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSets(
    String userId,
  ) {
    return _db.rawQuery(sql.getPreviousExercises, [userId]).then(
      (rows) {
        return Map.fromEntries(
          rows.map(
            (row) {
              return MapEntry(
                row['exerciseId'] as String,
                List.castFrom<dynamic, Map<String, dynamic>>(
                  jsonDecode(row['sets'] as String) as List,
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Future<List<(num, DateTime)>> getRepsHistory(
    String userId,
    Exercise exercise, {
    int? limit,
  }) {
    return _getMetric(userId, exercise, sql.getRepsHistory, limit: limit);
  }

  @override
  Future<List<(num, DateTime)>> getDistanceHistory(
    String userId,
    Exercise exercise, {
    int? limit,
  }) {
    return _getMetric(userId, exercise, sql.getDistanceHistory, limit: limit);
  }

  @override
  Future<List<(num, DateTime)>> getDurationHistory(
    String userId,
    Exercise exercise, {
    int? limit,
  }) {
    return _getMetric(userId, exercise, sql.getDurationHistory, limit: limit);
  }

  @override
  Future<List<(num, DateTime)>> getWeightHistory(
    String userId,
    Exercise exercise, {
    int? limit,
  }) {
    return _getMetric(userId, exercise, sql.getWeightHistory, limit: limit);
  }

  Future<List<(num, DateTime)>> _getMetric(
    String userId,
    Exercise exercise,
    String query, {
    int? limit,
  }) {
    return _db.rawQuery(query, [userId, exercise.name, limit ?? 30]).then(
      (rows) {
        return rows.map(
          (row) {
            return switch (row) {
              {'value': num value, 'when': String id} => (
                value,
                DateTime.parse(id),
              ),
              _ => throw ArgumentError('_getMetric: $row'),
            };
          },
        ).toList();
      },
    );
  }

  @override
  Future<List<(num, DateTime)>?> getExerciseMetics(
    String userId,
    ChartPreferenceType type,
    String exerciseName, {
    int limit = 8,
  }) {
    final query = switch (type) {
      .maxConsecutiveReps => metrics.getMaxConsecutiveRepsHistory,
      .topSetWeight => metrics.getTopSetWeightHistory,
      .estimatedOneRepMax => metrics.getEstimatedOneRepMaxHistory,
      .totalVolume => metrics.getTotalVolumeHistory,
      .averageWorkingWeight => metrics.getAverageWorkingWeightHistory,
      .assistanceWeight => metrics.getAssistanceWeightHistory,
      .totalReps => metrics.getTotalRepsHistory,
      .cardioDistance => metrics.getCardioDistanceHistory,
      .cardioDuration => metrics.getCardioDurationHistory,
      .averagePace => metrics.getAveragePaceHistory,
      .totalTimeUnderTension => metrics.getTotalTimeUnderTensionHistory,
    };

    return _db.rawQuery(query, [userId, exerciseName, limit]).then(
      (rows) {
        return rows.map(
          (row) {
            return switch (row) {
              {'value': num value, 'when': String id} => (
                value,
                DateTime.parse(id),
              ),
              _ => throw ArgumentError('getExerciseMetics: $row'),
            };
          },
        ).toList();
      },
    );
  }
}
