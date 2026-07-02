part of '../../heart_db.dart';

mixin _Workouts on _LocalDatabase implements GalleryService, WorkoutService {
  static String? _encodeImages(final Iterable<WorkoutImage>? images) {
    if (images == null) return null;
    return jsonEncode(images.map((each) => each.toRow()).toList());
  }

  static void _storeWorkout(
    Batch batch,
    Workout workout,
    String userId, {
    required bool synced,
  }) {
    final Workout(id: workoutId, :start, :name, :end, :images) = workout;
    final row = {
      'id': workoutId,
      'start': start.toIso8601String(),
      'user_id': userId,
      'name': ?name,
      'end': ?end?.toIso8601String(),
      'images': ?_encodeImages(images?.values),
      'synced': synced ? 1 : 0,
    };
    batch.insert(_workouts, row, conflictAlgorithm: .replace);

    for (final each in workout.indexed) {
      var (order, exercise) = each;
      final exerciseRow = {
        'workout_id': workoutId,
        'exercise_id': exercise.exercise.name,
        'exercise_order': order,
        'id': exercise.id,
      };

      batch.insert(_workoutExercises, exerciseRow, conflictAlgorithm: .replace);

      for (final set in exercise) {
        final setRow = {
          'exercise_id': exercise.id,
          ...set.toRow(),
          'completed': set.isCompleted ? 1 : 0,
        };

        batch.insert(_sets, setRow, conflictAlgorithm: .replace);
      }
    }
  }

  @override
  Future<void> updateWorkout({
    required String workoutId,
    String? name,
    Iterable<WorkoutImage>? images,
  }) {
    final row = {'name': name, 'images': _encodeImages(images)};
    assert(row.isNotEmpty, 'Provide at least one attribute');
    return _db.update(_workouts, row, where: 'id = ?', whereArgs: [workoutId]);
  }

  @override
  Future<void> startWorkout(Workout workout, String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        // local write only — not yet confirmed on the server
        _storeWorkout(batch, workout, userId, synced: false);
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
      (txn) async {
        final batch = txn.batch();

        // local write only — not yet confirmed on the server
        _storeWorkout(batch, workout, userId, synced: false);

        await batch.commit(noResult: true);

        await txn.update(
          _workouts,
          {'end': workout.end?.toIso8601String()},
          where: 'id = ?',
          whereArgs: [workout.id],
        );
        // we'll remove all the exercises that are not marked as finished
        await txn.rawDelete(sql.removeUnfinished, [workout.id]);
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

        for (final each in exercise) {
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
    return _db.delete(
      _workoutExercises,
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
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
    return switch (rows) {
      [Map row] => Workout.fromJson(row.toWorkout()),
      _ => null,
    };
  }

  @override
  Future<Workout?> getWorkout(String? userId, String workoutId) {
    return _db.rawQuery(sql.getWorkout, [workoutId, userId]).then<Workout?>(
      (rows) {
        return switch (rows) {
          [Map row] => Workout.fromJson(row.toWorkout()),
          _ => null,
        };
      },
    );
  }

  @override
  Future<void> storeWorkoutHistory(Iterable<Workout> history, String userId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();

        for (final each in history) {
          // history comes from the server (or a just-confirmed save)
          _storeWorkout(batch, each, userId, synced: true);
        }

        await batch.commit();
      },
    );
  }

  @override
  Future<Iterable<Workout>?> getWorkoutHistory(String userId) async {
    final rows = await _db.rawQuery(sql.history, [userId]);
    return rows.map((each) => Workout.fromJson(each.toWorkout()));
  }

  @override
  Future<ProgressGalleryResponse> getWorkoutGallery({
    String? cursor,
    String? userId,
  }) async {
    final rows = await _db.query(
      _workouts,
      columns: ['images'],
      where: 'images IS NOT NULL AND user_id = ?',
      whereArgs: [?userId],
    );
    return ProgressGalleryResponse(
      images: rows.expand(
        (row) {
          return switch (row['images']) {
            String j => (jsonDecode(j) as List).map<WorkoutImage>(
              (each) => WorkoutImage.fromJson(each),
            ),
            _ => const Iterable<WorkoutImage>.empty(),
          };
        },
      ).toList(),
    );
  }
}
