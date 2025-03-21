part of '../heart_db.dart';

final class LocalDatabase implements TimersService, ExerciseService, StatsService, TemplateService, WorkoutService {
  static late final Database _db;

  static Future<void> init([int version = 1]) async {
    var path = await getDatabasesPath();
    // await deleteDatabase(path);

    const name = 'heart.db';
    _logger.info('Local database at $path/$name');
    await openDatabase(
      join(path, name),
      version: version,
      onUpgrade: _migrate,
      onConfigure: (db) async {
        _db = db;
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static FutureOr<void> _migrate(Database db, int oldVersion, int newVersion) async {
    _logger.info('Migrating local database from version $oldVersion to $newVersion');
    _db.transaction(
      (txn) async {
        txn
          ..execute(sql.exercises)
          ..execute(sql.syncs)
          ..execute(sql.workouts)
          ..execute(sql.workoutExercises)
          ..execute(sql.sets)
          ..execute(sql.templates)
          ..execute(sql.templatesExercises)
          ..execute(sql.exerciseDetails);
      },
    );
  }

  @override
  Future<(DateTime?, Iterable<Exercise>)> getExercises() async {
    return _db.transaction<(DateTime?, Iterable<Exercise>)>(
      (txn) async {
        final rows = await txn.query('exercises');
        final exercises = rows.map(
          (row) {
            return Exercise.fromJson(row.toCamel());
          },
        );

        final syncRows = await txn.query(_syncs, where: 'table_name = ?', whereArgs: [_exercises]);

        if (syncRows case [Map row]) {
          return (DateTime.tryParse(row['synced_at'] ?? ''), exercises);
        }
        return (null, exercises);
      },
    );
  }

  @override
  Future<void> storeExercises(Iterable<Exercise> exercises) async {
    return _db.transaction(
      (txn) {
        final batch = txn.batch();
        for (var each in exercises) {
          var row = {
            for (var MapEntry(:key, :value) in each.toMap().entries) key.toSnake(): value,
          };
          batch.insert(_exercises, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        txn.insert(_syncs, {'table_name': _exercises});

        return batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> setRestTimer({required String exerciseName, required String userId, required int? seconds}) {
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
              {'rest_timer': seconds},
              where: 'exercise_name = ? AND user_id = ?',
              whereArgs: [exerciseName, userId],
            );
          default: // new
            txn.insert(
              _exerciseDetails,
              {
                'rest_timer': seconds,
                'exercise_name': exerciseName,
                'user_id': userId,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
        }
      },
    );
  }

  @override
  Future<Map<String, int>> getTimers(String userId) async {
    final rows = await _db.query(
      _exerciseDetails,
      columns: ['exercise_name', 'rest_timer'],
      where: 'user_id = ? AND rest_timer IS NOT NULL',
      whereArgs: [userId],
    );

    return Map.fromEntries(
      rows.map(
        (row) {
          return MapEntry(
            row['exercise_name'] as String,
            row['rest_timer'] as int,
          );
        },
      ),
    );
  }

  @override
  Future<void> startWorkout(Workout workout, String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        _storeWorkout(batch, workout, userId);
        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> deleteWorkout(String workoutId) {
    return _db.delete(_workouts, where: 'id = ?', whereArgs: [workoutId]);
  }

  @override
  Future<void> finishWorkout(Workout workout, String userId) {
    return _db.transaction(
      (txn) {
        final batch = txn.batch();

        _storeWorkout(batch, workout, userId);

        batch.commit(noResult: true);

        txn.update(
          _workouts,
          {'end': workout.end?.toIso8601String()},
          where: 'id = ?',
          whereArgs: [workout.id],
        );
        // we'll remove all the exercises that are not marked as finished
        return txn.rawDelete(sql.removeUnfinished, [workout.id]);
      },
    );
  }

  @override
  Future<void> startExercise(String workoutId, WorkoutExercise exercise) {
    return _db.transaction<void>(
      (txn) async {
        final row = {
          'workout_id': workoutId,
          'exercise_id': exercise.exercise.name,
          'id': exercise.id,
        };

        await txn.insert(_workoutExercises, row);

        final batch = txn.batch();

        for (var each in exercise) {
          final row = {
            'exercise_id': exercise.id,
            'id': each.id,
            'completed': each.isCompleted ? 1 : 0,
          };

          batch.insert(_sets, row);
        }

        await batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> addSet(WorkoutExercise exercise, ExerciseSet set) {
    final row = {
      'exercise_id': exercise.id,
      ...set.toRow(),
    };
    return _db.insert(_sets, row);
  }

  @override
  Future<void> removeSet(ExerciseSet set) {
    return _db.delete(_sets, where: 'id = ?', whereArgs: [set.id]);
  }

  @override
  Future<void> removeExercise(WorkoutExercise exercise) {
    return _db.delete(_workoutExercises, where: 'id = ?', whereArgs: [exercise.id]);
  }

  @override
  Future<void> storeMeasurements(ExerciseSet set) {
    return _db.update(_sets, set.toRow(), where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> _markSet(ExerciseSet set, bool status) {
    final row = {'completed': status ? 1 : 0};
    return _db.update(_sets, row, where: 'id = ?', whereArgs: [set.id]);
  }

  @override
  Future<void> markSetAsComplete(ExerciseSet set) {
    return _markSet(set, true);
  }

  @override
  Future<void> markSetAsIncomplete(ExerciseSet set) {
    return _markSet(set, false);
  }

  @override
  Future<Workout?> getActiveWorkout(String? userId) async {
    final rows = await _db.rawQuery(sql.activeWorkout, [userId]);
    if (rows.isEmpty) return null;
    final renamed = rows.map((row) => row.toCamel());
    return Workout.fromRows(renamed);
  }

  @override
  Future<void> storeWorkoutHistory(Iterable<Workout> history, String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();

        for (var each in history) {
          _storeWorkout(batch, each, userId);
        }

        batch.commit();
      },
    );
  }

  @override
  Future<Iterable<Workout>?> getWorkoutHistory(String userId) async {
    final rows = await _db.rawQuery(sql.history, [userId]);
    final mapped = rows.fold<Map<String, List<Map<String, Object?>>>>(
      {},
      (accumulator, row) {
        final workoutExerciseId = row['workout_id'] as String;
        (accumulator[workoutExerciseId] ??= []).add(row.toCamel());
        return accumulator;
      },
    );
    return mapped.values.map((each) => Workout.fromRows(each));
  }

  static void _storeWorkout(Batch batch, Workout workout, String userId) {
    final Workout(id: workoutId, :start, :name, :end) = workout;
    final row = {
      'id': workoutId,
      'start': start.toIso8601String(),
      'user_id': userId,
      if (name != null) 'name': name,
      if (end != null) 'end': end.toIso8601String(),
    };
    batch.insert(_workouts, row, conflictAlgorithm: ConflictAlgorithm.replace);

    for (var exercise in workout) {
      final exerciseRow = {
        'workout_id': workoutId,
        'exercise_id': exercise.exercise.name,
        'id': exercise.id,
      };

      batch.insert(_workoutExercises, exerciseRow, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var set in exercise) {
        final setRow = {
          'exercise_id': exercise.id,
          ...set.toRow(),
          'completed': set.isCompleted ? 1 : 0,
        };

        batch.insert(_sets, setRow, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  @override
  Future<void> renameWorkout({required String workoutId, required String name}) {
    return _db.update(_workouts, {'name': name}, where: 'id = ?', whereArgs: [workoutId]);
  }

  @override
  Future<WorkoutAggregation> getWorkoutSummary({int? weeksBack = 8}) {
    final cutoff = getMonday(DateTime.timestamp()).subtract(Duration(days: 7 * (weeksBack ?? 0))).toIso8601String();
    return _db.query(_workouts, where: 'start > ? AND end IS NOT NULL', whereArgs: [cutoff]).then(
      (rows) {
        if (rows.isEmpty) return WorkoutAggregation.empty();
        return WorkoutAggregation.fromRows(rows);
      },
    );
  }

  @override
  Future<void> updateTemplate(Template template) {
    return _db.transaction(
      (txn) {
        txn
          ..update(_templates, {'name': template.name}, where: 'id = ?', whereArgs: [int.parse(template.id)])
          ..delete(_templatesExercises, where: 'template_id = ?', whereArgs: [int.parse(template.id)]);

        final batch = txn.batch();

        for (var exercise in template) {
          var desc = exercise.map((set) => set.toMap()).toList();

          batch.insert(
            _templatesExercises,
            {
              'template_id': int.parse(template.id),
              'exercise_id': exercise.exercise.name,
              'description': jsonEncode(desc),
            },
          );
        }

        return batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) {
    return _db.delete(_templates, where: 'id = ?', whereArgs: [int.parse(templateId)]);
  }

  @override
  Future<Iterable<Template>> getTemplates(String? userId) async {
    final query = userId == null ? sql.getSampleTemplates : sql.getTemplates;
    final rows = (await _db.rawQuery(query, [userId])).map((row) => row.toCamel());
    if (rows.isEmpty) return [];

    final grouped = rows.fold<Map<String, List<Map<String, dynamic>>>>(
      {},
      (acc, row) {
        final templateId = row['templateId'].toString();
        acc.putIfAbsent(templateId, () => []).add(row);
        return acc;
      },
    );

    return grouped.entries.map((entry) => Template.fromRows(entry.value));
  }

  @override
  Future<Template> startTemplate({int? order, String? userId}) async {
    return _db.transaction(
      (txn) async {
        final newOrder = order ?? (await _getMaxValue(txn, _templates, 'order_in_parent') + 1);
        return txn.insert(_templates, {'user_id': userId, 'order_in_parent': newOrder}).then<Template>(
          (id) {
            return Template.empty(id: id.toString(), order: newOrder);
          },
        );
      },
    );
  }

  @override
  Future<void> storeTemplates(Iterable<Template> templates, {String? userId}) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();

        for (final template in templates) {
          batch.insert(
            _templates,
            {
              ...template.toRow(),
              'user_id': userId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          for (final exercise in template) {
            var desc = exercise.map((set) => set.toMap()).toList();

            batch.insert(
              _templatesExercises,
              {
                'template_id': int.parse(template.id),
                'exercise_id': exercise.exercise.name,
                'description': jsonEncode(desc),
              },
            );
          }
        }

        batch.commit(noResult: true);
      },
    );
  }
}

Future<int> _getMaxValue(DatabaseExecutor db, String table, String column) async {
  final rows = await db.rawQuery('SELECT max($column) AS max_value FROM $table;');
  return switch (rows) {
    [{'max_value': num v}] => v.toInt(),
    _ => 0,
  };
}
