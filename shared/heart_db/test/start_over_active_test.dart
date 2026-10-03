import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';
import 'utils.dart';

/// What the mirror holds when a new workout replaces an active one (#228),
/// against a real SQLite: the "active" workout is whatever `sql.activeWorkout`
/// picks, so only the real statement can show a stray coming back.
void main() {
  const user = 'anonymous';

  late Database db;
  late LocalDatabase local;
  late Exercise squat;

  setUp(() async {
    db = await openTestDatabase();
    // production turns this on as it opens the file (`LocalDatabase.init`,
    // onConfigure); deleting a workout takes its exercises and sets with it
    // only through these cascades
    await db.execute('PRAGMA foreign_keys = ON');
    local = await LocalDatabase.init(other: db);
    squat = exercise();
    await local.storeExercises([squat]);
  });

  tearDown(() => db.close());

  /// A started workout with one exercise and one set, as the mirror keeps it.
  Future<Workout> started(String name) async {
    final workout = Workout(name: name)..add(squat);
    await local.startWorkout(workout, user);
    return workout;
  }

  Future<int> count(String table) async {
    final rows = await db.rawQuery('SELECT count(*) AS c FROM $table');
    return rows.single['c'] as int;
  }

  test('discarding deletes the old workout with everything in it, and the new one is the active one', () async {
    final old = await started('Leg Day');
    expect(await count('workout_exercises'), 1);
    expect(await count('sets'), 1);

    // the order the app keeps: delete first, then start
    await local.deleteWorkout(old.id);
    final fresh = await started('Push Day');

    expect((await local.getActiveWorkout(user))?.id, fresh.id);
    expect(await count('workouts'), 1, reason: 'no stray left behind');
    expect(await count('workout_exercises'), 1, reason: "the old workout's exercises went with it");
    expect(await count('sets'), 1);

    fresh.finish(DateTime.now());
    fresh.first.first.isCompleted = true;
    await local.finishWorkout(fresh, user);
    expect(await local.getActiveWorkout(user), isNull, reason: 'nothing comes back once the new one is done');
  });

  test('without the delete, the old workout comes back once the new one finishes', () async {
    // what #228 fixed, kept as the reason the delete is not optional
    final old = await started('Leg Day');
    final fresh = await started('Push Day');
    expect((await local.getActiveWorkout(user))?.id, fresh.id, reason: 'the newer one hides it');

    fresh.finish(DateTime.now());
    fresh.first.first.isCompleted = true;
    await local.finishWorkout(fresh, user);

    expect((await local.getActiveWorkout(user))?.id, old.id);
  });
}
