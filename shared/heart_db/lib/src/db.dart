import 'dart:async';
import 'package:heart_models/heart_models.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'sql.dart' as sql;

const _exercises = 'exercises';
const _sets = 'sets';
const _syncs = 'syncs';
const _workouts = 'workouts';
const _workoutExercises = 'workout_exercises';

final _logger = Logger('Sqlite');

final class LocalDatabase implements ExerciseService, StatsService, WorkoutService {
  static late final Database _db;

  static Future<void> init() async {
    var path = await getDatabasesPath();
    // await deleteDatabase(path);

    _logger.info('Local database at $path');
    await openDatabase(
      join(path, 'heart.db'),
      version: 1,
      onUpgrade: _migrate,
      onConfigure: (db) async {
        _db = db;
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static FutureOr<void> _migrate(Database db, int oldVersion, int newVersion) async {
    _logger.info('Migrating local database from version $oldVersion to $newVersion');
    await db.execute(sql.exercises);
    await db.execute(sql.syncs);
    await db.execute(sql.workouts);
    await db.execute(sql.workoutExercises);
    await db.execute(sql.sets);
  }

  @override
  Future<(DateTime?, Iterable<Exercise>)> getExercises() async {
    return _db.transaction<(DateTime?, Iterable<Exercise>)>(
      (txn) async {
        final rows = await txn.query('exercises');
        final exercises = rows.map(
          (row) {
            final formatted = {
              for (var MapEntry(:key, :value) in row.entries) _toCamel(key): value,
            };
            return Exercise.fromJson(formatted);
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
            for (var MapEntry(:key, :value) in each.toMap().entries) _toSnake(key): value,
          };
          batch.insert(_exercises, row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        txn.insert(_syncs, {'table_name': _exercises});

        return batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> startWorkout(String workoutId, DateTime start, {String? name}) {
    final row = {
      'id': workoutId,
      'start': start.toIso8601String(),
      if (name != null) 'name': name,
    };
    return _db.insert(_workouts, row);
  }

  @override
  Future<void> deleteWorkout(String workoutId) {
    return _db.delete(_workouts, where: 'id = ?', whereArgs: [workoutId]);
  }

  @override
  Future<void> finishWorkout(Workout workout) {
    return _db.update(
      _workouts,
      {'end': workout.end?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [workout.id],
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

        batch.commit(noResult: true);
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
    final row = switch (set) {
      CardioSet s => {'duration': s.duration, 'reps': s.reps},
      WeightedSet s => {'weight': s.weight, 'reps': s.reps},
      AssistedSet s => {'weight': s.weight, 'reps': s.reps},
    };
    return _db.update(_sets, row, where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> _makeSet(ExerciseSet set, bool status) {
    final row = {'completed': status ? 1 : 0};
    return _db.update(_sets, row, where: 'id = ?', whereArgs: [set.id]);
  }

  @override
  Future<void> markSetAsComplete(ExerciseSet set) {
    return _makeSet(set, true);
  }

  @override
  Future<void> markSetAsIncomplete(ExerciseSet set) {
    return _makeSet(set, false);
  }

  @override
  Future<Workout?> getActiveWorkout() async {
    final rows = await _db.rawQuery(sql.activeWorkout);
    if (rows.isEmpty) return null;
    final renamed = rows.map((row) => {for (var MapEntry(:key, :value) in row.entries) _toCamel(key): value});
    return Workout.fromRows(renamed);
  }

  @override
  Future<void> storeWorkoutHistory(Iterable<Workout> history) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();

        for (var each in history) {
          _storeWorkout(batch, each);
        }

        batch.commit();
      },
    );
  }

  @override
  Future<Iterable<Workout>?> getWorkoutHistory() async {
    final rows = await _db.rawQuery(sql.history);
    final mapped = rows.fold<Map<String, List<Map<String, Object?>>>>(
      {},
      (accumulator, row) {
        final workoutExerciseId = row['workout_id'] as String;
        final renamed = {for (var MapEntry(:key, :value) in row.entries) _toCamel(key): value};
        (accumulator[workoutExerciseId] ??= []).add(renamed);
        return accumulator;
      },
    );
    return mapped.values.map((each) => Workout.fromRows(each));
  }

  static void _storeWorkout(Batch batch, Workout workout) {
    final Workout(id: workoutId, :start, :name, :end) = workout;
    final row = {
      'id': workoutId,
      'start': start.toIso8601String(),
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
    return _db.query(_workouts, where: 'start > ?', whereArgs: [cutoff]).then(
      (rows) {
        if (rows.isEmpty) return WorkoutAggregation.empty();
        return WorkoutAggregation.fromRows(rows);
      },
    );
  }
}

String _toSnake(String s) {
  return s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]}_${match[2]}').toLowerCase();
}

String _toCamel(String s) {
  final words = s.split('_');
  return words.first + words.skip(1).map((word) => word[0].toUpperCase() + word.substring(1)).join();
}
