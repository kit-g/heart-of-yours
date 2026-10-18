part of '../../heart_db.dart';

String? _encoded(Map<String, dynamic>? json) {
  return switch (json) {
    Map<String, dynamic> json => jsonEncode(json),
    null => null,
  };
}

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

        final exercises = _readable(
          rows,
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

            if (each['aliases'] case String s) each['aliases'] = jsonDecode(s);

            return Exercise.fromJson(each);
          },
          what: 'exercise',
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

  /// What the cached catalog rows are a copy of, as the CDN identifies it —
  /// the manifest `version`, the locale file, that file's ETag. Null until a
  /// library has been stored with one.
  Future<({String version, String locale, String? etag})?> getCatalogStamp() async {
    final rows = await _db.query(
      _syncs,
      columns: ['version', 'locale', 'etag'],
      where: 'table_name = ?',
      whereArgs: [_exercises],
    );

    return switch (rows) {
      [{'version': String version, 'locale': String locale, 'etag': String? etag}] => (
        version: version,
        locale: locale,
        etag: etag,
      ),
      _ => null,
    };
  }

  /// The search glossary stored with the catalog it came in, in its
  /// published form; null until a library carrying one has been stored.
  Future<Map<String, dynamic>?> getSearchGlossary() async {
    final rows = await _db.query(_syncs, columns: ['glossary'], where: 'table_name = ?', whereArgs: [_exercises]);
    return switch (rows) {
      [{'glossary': String json}] => jsonDecode(json) as Map<String, dynamic>,
      _ => null,
    };
  }

  /// [locale], [version] and [etag] together are the catalog stamp — see
  /// [getCatalogStamp]; the interface has no notion of them, so a caller that
  /// stores one user-created exercise passes none and the stamp stays put.
  /// [glossary] travels with a catalog write; a write without one keeps the
  /// glossary already stored.
  @override
  Future<void> storeExercises(
    Iterable<Exercise> exercises, {
    String? userId,
    String? locale,
    String? version,
    String? etag,
    Map<String, dynamic>? glossary,
  }) async {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        for (final each in exercises) {
          var row = {
            for (final MapEntry(:key, :value) in each.toMap().entries) key.toSnake(): value,
          };
          // unconditional for the same reason as the blobs below — and it has
          // to clear as well as set: an exercise promoted from someone's
          // custom into the shared catalog must shed its old owner on the
          // conflict-update, or the row lands on own = 0 with a stale
          // user_id and trips CHECK (own = 1 OR user_id IS NULL).
          row['user_id'] = switch (each.isMine) {
            true => userId,
            false => null,
          };
          row['muscles'] = jsonEncode(each.muscles.toMap());
          // both blobs are omitted by `toMap()` when empty, so set them
          // unconditionally — the row is built generically from its keys, and a
          // missing one would leave the column untouched on conflict-update.
          row['movement'] = jsonEncode(each.movement.toMap());
          row['health'] = jsonEncode(each.health.toMap());
          // unconditional for a sharper reason than the blobs: `toMap()` omits
          // the key when null, and null is a meaning, not an absence — a row
          // demoted from reviewed copy to machine copy (or to none, when it
          // goes library → custom) must not keep a stale flag on the
          // conflict-update.
          row['validated'] = switch (each.validated) {
            true => 1,
            false => 0,
            null => null,
          };
          // same trap for the slug: absent on a custom, and a row promoted
          // into someone's customs must shed it rather than keep a stale one
          row['key'] = each.key;
          // a list is no column value, and an empty one must clear the old
          row['aliases'] = each.aliases.isNotEmpty ? jsonEncode([...each.aliases]) : null;
          // the unit preference is per-user (exercise_details), not a column on
          // the shared catalog row — see setExerciseUnit / getExerciseUnits.
          row.remove('unit_system');

          // The row is built from every key the model emits, so a field added
          // in heart_models arrives here with no column behind it — see
          // [_fitToSchema]. This is the write that made that fatal.
          row = await _fitToSchema(txn, _exercises, row);

          final columns = row.keys.join(', ');
          final placeholders = List.filled(row.length, '?').join(', ');
          // `name` is in the update set on purpose: it is localized display
          // copy now, and refreshing it in place — same id, new language — is
          // how a locale change lands.
          final updates = row.keys.where((k) => k != 'id').map((k) => '$k = EXCLUDED.$k').join(', ');

          batch.rawInsert(
            '''
            INSERT INTO $_exercises ($columns)
            VALUES ($placeholders)
            ON CONFLICT(id) DO UPDATE SET $updates
            ''',
            row.values.toList(),
          );
        }

        // The stamp is part of the cache key: localized columns are only as
        // fresh as the locale file they came from, and version + ETag are
        // what the next launch shows the CDN. An upsert rather than REPLACE so
        // a stamp-less write — storing one user-created exercise — bumps the
        // timestamp and leaves the stamp alone. A catalog write replaces the
        // ETag even with null: a stale one would vouch for rows it never
        // described, and the next conditional fetch would 304 against them.
        txn.rawInsert(
          '''
          INSERT INTO $_syncs (table_name, locale, version, etag, glossary) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(table_name) DO UPDATE SET
            synced_at = (datetime('now') || '+00:00'),
            locale = coalesce(EXCLUDED.locale, locale),
            version = coalesce(EXCLUDED.version, version),
            etag = CASE WHEN EXCLUDED.version IS NULL THEN etag ELSE EXCLUDED.etag END,
            glossary = coalesce(EXCLUDED.glossary, glossary)
          ''',
          [_exercises, locale, version, etag, _encoded(glossary)],
        );

        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> setExerciseUnit({
    // the exercise's uuid since v11 — the parameter keeps the interface's
    // (stale) name until the next heart_models major
    required String exerciseName,
    required String userId,
    required MeasurementUnit? unit,
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
              {'unit_system': unit?.name},
              where: 'exercise_id = ? AND user_id = ?',
              whereArgs: [exerciseName, userId],
            );
          default: // new
            txn.insert(
              _exerciseDetails,
              {
                'unit_system': unit?.name,
                'exercise_id': exerciseName,
                'user_id': userId,
              },
              conflictAlgorithm: .replace,
            );
        }
      },
    );
  }

  Future<Map<String, String>> getExerciseNotes(String userId) async {
    final rows = await _db.query(
      _exerciseDetails,
      columns: ['exercise_id', 'note'],
      where: 'user_id = ? AND note IS NOT NULL',
      whereArgs: [userId],
    );
    return {for (final row in rows) row['exercise_id'] as String: row['note'] as String};
  }

  Future<void> setExerciseNote(String exerciseId, String userId, String? note, {bool pending = false}) async {
    await _db.transaction((txn) async {
      if (pending) {
        await txn.delete(
          _upsync,
          where: 'user_id = ? AND resource = ? AND id = ?',
          whereArgs: [userId, 'note', exerciseId],
        );
      }
      final count = await txn.update(
        _exerciseDetails,
        {'note': note},
        where: 'exercise_id = ? AND user_id = ?',
        whereArgs: [exerciseId, userId],
      );
      if (count == 0 && note != null) {
        await txn.insert(_exerciseDetails, {'exercise_id': exerciseId, 'user_id': userId, 'note': note});
      }
    });
  }

  @override
  Future<Map<String, MeasurementUnit>> getExerciseUnits(String userId) async {
    final rows = await _db.query(
      _exerciseDetails,
      columns: ['exercise_id', 'unit_system'],
      where: 'user_id = ? AND unit_system IS NOT NULL',
      whereArgs: [userId],
    );

    return Map.fromEntries(
      _readable(
        rows,
        (row) {
          return MapEntry(
            row['exercise_id'] as String,
            MeasurementUnit.fromString(row['unit_system'] as String),
          );
        },
        what: 'unit preference',
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
    return _db.rawQuery(sql.getExerciseHistory, [exercise.id, userId]).then<Iterable<ExerciseAct>>(
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
        return _readable(grouped.values, (group) => ExerciseAct.fromRows(exercise, group), what: 'exercise history');
      },
    );
  }

  @override
  Future<Map?> getRecord(String userId, Exercise exercise) {
    return _db
        .rawQuery(sql.recordSets, [userId, exercise.id])
        .then(
          (rows) => _foldRecords(exercise.category, rows),
        );
  }

  /// [getRecord] as it stood when [workoutId] was done: that workout and
  /// every earlier one, so a record day stays one after a later session
  /// beats it. Null when the exercise had not been performed by then.
  Future<Map?> getRecordAsOf(String userId, Exercise exercise, String workoutId) {
    return _db
        .rawQuery(sql.recordSetsAsOf, [userId, exercise.id, workoutId, workoutId])
        .then((rows) => _foldRecords(exercise.category, rows));
  }

  @override
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSets(
    String userId,
  ) {
    return _db.rawQuery(sql.getPreviousExercises, [userId]).then(_previousByExercise);
  }

  /// [getPreviousSets] as of [before]: each exercise's last finished session
  /// that started earlier — "last time" from a past workout's point of view.
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSetsBefore(String userId, DateTime before) {
    return _db
        .rawQuery(sql.getPreviousExercisesBefore, [userId, before.toUtc().toIso8601String()])
        .then(_previousByExercise);
  }

  /// [getPreviousSets] within one template (#172): each exercise's sets from
  /// the last finished workout started from [templateId], and, with [before],
  /// one that started earlier than it.
  Future<Map<ExerciseId, List<Map<String, dynamic>>>> getPreviousSetsInTemplate(
    String userId,
    String templateId, {
    DateTime? before,
  }) {
    final (query, arguments) = switch (before) {
      DateTime before => (
        sql.getPreviousExercisesInTemplateBefore,
        [userId, templateId, before.toUtc().toIso8601String()],
      ),
      null => (sql.getPreviousExercisesInTemplate, [userId, templateId]),
    };
    return _db.rawQuery(query, arguments).then(_previousByExercise);
  }

  static Map<ExerciseId, List<Map<String, dynamic>>> _previousByExercise(List<Map<String, Object?>> rows) {
    return Map.fromEntries(
      rows.map(
        (row) => MapEntry(
          row['exerciseId'] as String,
          List.castFrom<dynamic, Map<String, dynamic>>(jsonDecode(row['sets'] as String) as List),
        ),
      ),
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
    return _db.rawQuery(query, [userId, exercise.id, limit ?? 30]).then(
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

/// Folds the [sql.recordSets] rows — one per completed set, oldest workout
/// first — into the map [ExerciseService.getRecord] hands the app. Null when
/// the exercise has never been performed.
///
/// The fold itself is heart_models' [PersonalRecords.toPersonalRecords] (#291),
/// the one definition of a record that `/me/records` and MCP compute too, so
/// the app shows what an assistant reports.
Map? _foldRecords(Category category, List<Map<String, dynamic>> rows) {
  return _readable(rows, RecordSet.fromRow, what: 'record set').toPersonalRecords(category);
}
