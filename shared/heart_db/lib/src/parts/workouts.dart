part of '../../heart_db.dart';

mixin _Workouts on _LocalDatabase implements GalleryService, WorkoutService {
  static String? _encodeImages(Iterable<WorkoutImage>? images) {
    if (images == null) return null;
    return jsonEncode(images.map((each) => each.toRow()).toList());
  }

  /// Whether [workout] carries its own detail — at least one set somewhere.
  ///
  /// A finished workout cannot legitimately be empty: finishing requires a
  /// completed set, and the client never sends a set-less exercise. So a
  /// server copy with no sets at all is a *shallow* one — a list page, a PATCH
  /// echo, a shape the parser could not fully read — and says nothing about
  /// the exercises the mirror already holds for it.
  static bool _carriesDetail(Workout workout) {
    return workout.any((exercise) => exercise.isNotEmpty);
  }

  /// Writes [workout] into the mirror, updating the row in place.
  ///
  /// The row used to be written with `INSERT OR REPLACE`, whose implicit
  /// delete cascaded the workout's exercises and sets away. That silently
  /// stripped every workout re-stored without its exercises
  /// (heart-of-yours#85) — history, charts and records went empty, and the
  /// Done screen crowned new "records" against nothing.
  ///
  /// [replaceExercises] says the payload is authoritative for the children:
  /// what it lists is the whole of them, so anything the mirror had beyond it
  /// (an exercise dropped by an edit, a set left unfinished) is removed. When
  /// false, the children are left exactly as they are.
  static void _storeWorkout(
    Batch batch,
    Workout workout,
    String userId, {
    required bool synced,
    required bool replaceExercises,
  }) {
    final Workout(id: workoutId, :start, :name, :end, :images) = workout;
    // every column, nulls included, so the row ends up exactly as REPLACE
    // used to leave it — only without the delete underneath
    batch.rawInsert(sql.upsertWorkout, [
      workoutId,
      start.toIso8601String(),
      userId,
      name,
      end?.toIso8601String(),
      _encodeImages(images?.values),
      synced ? 1 : 0,
    ]);

    if (!replaceExercises) return;

    // the one cascade that is meant: the payload's exercises are the whole
    // set, so what the mirror had goes, sets included
    batch.delete(_workoutExercises, where: 'workout_id = ?', whereArgs: [workoutId]);

    for (final each in workout.indexed) {
      var (order, exercise) = each;
      final exerciseRow = {
        'workout_id': workoutId,
        'exercise_id': exercise.exercise.id,
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
        _storeWorkout(batch, workout, userId, synced: false, replaceExercises: true);
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

        // local write only — not yet confirmed on the server. The in-memory
        // workout is the truth here: an exercise `removeEmptySets` dropped
        // must go from the mirror too.
        _storeWorkout(batch, workout, userId, synced: false, replaceExercises: true);

        await batch.commit(noResult: true);

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
          'exercise_id': exercise.exercise.id,
          'id': exercise.id,
          // a freshly started exercise lands at the end of the workout
          'exercise_order': await _nextExerciseOrder(txn, workoutId),
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

  Future<int> _nextExerciseOrder(DatabaseExecutor txn, String workoutId) async {
    final rows = await txn.rawQuery(
      'SELECT COALESCE(MAX(exercise_order), -1) + 1 AS next FROM $_workoutExercises WHERE workout_id = ?',
      [workoutId],
    );
    return switch (rows) {
      [{'next': int next}] => next,
      _ => 0,
    };
  }

  @override
  Future<void> saveExerciseOrder(Iterable<String> orderedIds, String workoutId) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();
        for (final (index, id) in orderedIds.indexed) {
          batch.update(
            _workoutExercises,
            {'exercise_order': index},
            where: 'id = ? AND workout_id = ?',
            whereArgs: [id, workoutId],
          );
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
        // history comes from the server (or a just-confirmed save). A copy
        // with detail replaces the mirror's; a shallow one only touches the
        // row, leaving whatever exercises the mirror already holds.
        final shallow = {
          for (final each in history)
            if (!_carriesDetail(each)) each.id,
        };
        if (shallow.isNotEmpty) await _reportShallow(txn, shallow);

        final batch = txn.batch();

        for (final each in history) {
          _storeWorkout(batch, each, userId, synced: true, replaceExercises: !shallow.contains(each.id));
        }

        await batch.commit();
      },
    );
  }

  /// Names each of the [shallow] workouts — arrived without detail — that the
  /// mirror holds some for: the exact write that used to strip it.
  ///
  /// Diagnostic only: the write above already keeps the mirror's copy. This is
  /// how the payloads that arrive shallow get pinned down, per
  /// heart-of-yours#85, so the contract can be settled with the server.
  Future<void> _reportShallow(DatabaseExecutor txn, Set<String> shallow) async {
    // release builds log nothing, so they should not pay for the query either
    if (!_logger.isLoggable(Level.WARNING)) return;

    final rows = await txn.rawQuery(
      '''
      SELECT workout_id, count(*) AS exercises
      FROM $_workoutExercises
      WHERE workout_id IN (${List.filled(shallow.length, '?').join(', ')})
      GROUP BY workout_id
      ''',
      shallow.toList(),
    );

    for (final row in rows) {
      _logger.warning(
        'Workout ${row['workout_id']} arrived without exercises; '
        'the mirror keeps the ${row['exercises']} it has (heart-of-yours#85)',
      );
    }
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
