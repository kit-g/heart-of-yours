import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';
import 'utils.dart';

/// Against a real in-memory SQLite, with foreign keys on, as production runs.
///
/// heart-of-yours#85: the `workouts` row used to be written with
/// `INSERT OR REPLACE`, which SQLite runs as a delete + insert — and the
/// delete cascaded through `workout_exercises` into `sets`. Any re-store of a
/// workout without its exercises wiped the detail the mirror had. A mock
/// cannot hold a cascade, so this is the one place the fix is actually proven.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  final ex = exercise();

  setUp(() async {
    db = await openTestDatabase();
    await db.execute('PRAGMA foreign_keys = ON');
    local = await LocalDatabase.init(other: db);
    await local.storeExercises([ex], userId: userId);
  });

  tearDown(() => db.close());

  /// A finished workout with one exercise of [sets] sets, as the server hands
  /// it back: synced, with detail.
  Workout full({required String id, int sets = 3}) {
    return Workout.fromJson({
      'id': id,
      'start': '2026-08-21T10:00:00.000Z',
      'end': '2026-08-21T11:00:00.000Z',
      'name': 'Pull Day',
      'exercises': [
        {
          'id': '$id-ex',
          'order': 0,
          'exercise': ex.toMap(),
          'sets': [
            for (var i = 0; i < sets; i++) {'id': '$id-set-$i', 'weight': 225, 'reps': 5, 'completed': true},
          ],
        },
      ],
    });
  }

  /// The same workout as a list page or a PATCH echo might carry it: the row
  /// without its exercises.
  Workout shallow({required String id, String name = 'Pull Day'}) {
    return Workout.fromJson({
      'id': id,
      'start': '2026-08-21T10:00:00.000Z',
      'end': '2026-08-21T11:30:00.000Z',
      'name': name,
    });
  }

  Future<int> count(String table, String workoutId) async {
    final rows = await db.rawQuery(
      switch (table) {
        'sets' =>
          'SELECT count(*) AS n FROM sets WHERE exercise_id IN (SELECT id FROM workout_exercises WHERE workout_id = ?)',
        _ => 'SELECT count(*) AS n FROM $table WHERE workout_id = ?',
      },
      [workoutId],
    );
    return rows.single['n'] as int;
  }

  group('storeWorkoutHistory', () {
    test('a shallow re-store keeps the exercises and sets the mirror had', () async {
      await local.storeWorkoutHistory([full(id: 'w1')], userId);
      expect(await count('sets', 'w1'), 3);

      await local.storeWorkoutHistory([shallow(id: 'w1', name: 'Pull Day, renamed')], userId);

      expect(await count('workout_exercises', 'w1'), 1);
      expect(await count('sets', 'w1'), 3);

      // the row itself did take the update
      final row = (await db.query('workouts', where: 'id = ?', whereArgs: ['w1'])).single;
      expect(row['name'], 'Pull Day, renamed');
      expect(row['end'], '2026-08-21T11:30:00.000Z');
      expect(row['synced'], 1);
    });

    test('a full re-store replaces the children, dropping what the payload no longer lists', () async {
      await local.storeWorkoutHistory([full(id: 'w1', sets: 3)], userId);

      // an edit elsewhere removed a set: the server's copy is authoritative
      await local.storeWorkoutHistory([full(id: 'w1', sets: 2)], userId);

      expect(await count('sets', 'w1'), 2);
      expect(await count('workout_exercises', 'w1'), 1);
    });

    test('reads back the detail after a shallow re-store', () async {
      await local.storeWorkoutHistory([full(id: 'w1')], userId);
      await local.storeWorkoutHistory([shallow(id: 'w1')], userId);

      final history = await local.getWorkoutHistory(userId);
      final workout = history!.single;

      expect(workout.single.sets, hasLength(3));
      expect(workout.single.sets.first.weight, 225);
    });

    test('a shallow first store is just the row', () async {
      await local.storeWorkoutHistory([shallow(id: 'w1')], userId);

      expect(await count('workout_exercises', 'w1'), 0);
      final row = (await db.query('workouts', where: 'id = ?', whereArgs: ['w1'])).single;
      expect(row['name'], 'Pull Day');
    });

    test('a page mixing full and shallow workouts treats each on its own', () async {
      await local.storeWorkoutHistory([full(id: 'w1'), full(id: 'w2')], userId);

      await local.storeWorkoutHistory([shallow(id: 'w1'), full(id: 'w2', sets: 1)], userId);

      expect(await count('sets', 'w1'), 3);
      expect(await count('sets', 'w2'), 1);
    });
  });

  group('finishWorkout', () {
    test('drops the exercises the finished workout no longer carries', () async {
      // the active workout is written incrementally, one exercise and set at
      // a time — then `removeEmptySets` drops what was never done, and the
      // finish must take those exercises out of the mirror too
      final workout = Workout(name: 'Morning');
      await local.startWorkout(workout, userId);

      final done = workout.add(ex);
      done.first.setMeasurements(weight: 100, reps: 5);
      done.first.isCompleted = true;
      await local.startExercise(workout.id, done);

      final skipped = workout.add(ex);
      await local.startExercise(workout.id, skipped);
      expect(await count('workout_exercises', workout.id), 2);

      workout
        ..finish(DateTime.utc(2026, 8, 21, 11))
        ..removeEmptySets();
      await local.finishWorkout(workout, userId);

      expect(await count('workout_exercises', workout.id), 1);
      expect(await count('sets', workout.id), 1);
    });
  });
}
