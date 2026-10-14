import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The mirror's half of an exercise-history move (#338), against a real
/// in-memory SQLite: the server's rules row for row, scoped to one uid.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const me = 'uid-me';
  const other = 'uid-other';

  Future<void> exercise(String id, {String? owner}) {
    return db.insert('exercises', {
      'id': id,
      'name': id,
      'category': 'Weighted Body Weight',
      'target': 'Chest',
      'user_id': ?owner,
      'own': switch (owner) {
        null => 0,
        _ => 1,
      },
    });
  }

  /// A workout and a template under [uid], each holding [exerciseId].
  Future<void> seed(String uid, String exerciseId) async {
    await db.insert('workouts', {
      'id': '$uid-workout',
      'start': '2026-09-01T10:00:00.000Z',
      'end': '2026-09-01T11:00:00.000Z',
      'user_id': uid,
    });
    await db.insert('workout_exercises', {
      'id': '$uid-workout-exercise',
      'workout_id': '$uid-workout',
      'exercise_id': exerciseId,
      'exercise_order': 0,
    });
    await db.insert('sets', {
      'id': '$uid-set',
      'exercise_id': '$uid-workout-exercise',
      'completed': 1,
      'weight': 50,
      'reps': 10,
    });
    await db.insert('templates', {'id': '$uid-template', 'name': 'Push', 'user_id': uid, 'order_in_parent': 0});
    await db.insert('template_exercises', {
      'id': '$uid-template-exercise',
      'template_id': '$uid-template',
      'exercise_id': exerciseId,
    });
    await db.insert('goals', {
      'id': '$uid-goal',
      'user_id': uid,
      'metric': 'topSetWeight',
      'exercise_id': exerciseId,
      'stages': '[]',
    });
  }

  Future<List<Object?>> column(String table, String column, String where, List<Object?> args) async {
    final rows = await db.query(table, columns: [column], where: where, whereArgs: args);
    return [for (final row in rows) row[column]];
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await exercise('source');
    await exercise('target');
    await exercise('custom', owner: me);
  });

  tearDown(() => db.close());

  test('logged exercises, template entries and goals move, and only the uid\'s own', () async {
    await seed(me, 'source');
    await seed(other, 'source');

    await local.moveExerciseHistory(sourceId: 'source', targetId: 'target', userId: me, deleteSource: false);

    expect(await column('workout_exercises', 'exercise_id', 'id = ?', ['$me-workout-exercise']), ['target']);
    expect(await column('template_exercises', 'exercise_id', 'id = ?', ['$me-template-exercise']), ['target']);
    expect(await column('goals', 'exercise_id', 'id = ?', ['$me-goal']), ['target']);

    expect(await column('workout_exercises', 'exercise_id', 'id = ?', ['$other-workout-exercise']), ['source']);
    expect(await column('template_exercises', 'exercise_id', 'id = ?', ['$other-template-exercise']), ['source']);
    expect(await column('goals', 'exercise_id', 'id = ?', ['$other-goal']), ['source']);
  });

  test('the preference row moves when the target has none, and is dropped whole when it has one', () async {
    await db.insert('exercise_details', {'exercise_id': 'source', 'user_id': me, 'rest_timer': 90, 'note': 'Pause'});

    await local.moveExerciseHistory(sourceId: 'source', targetId: 'target', userId: me, deleteSource: false);
    expect(await column('exercise_details', 'rest_timer', 'exercise_id = ? AND user_id = ?', ['target', me]), [90]);

    // back the other way, onto a target that now has a row of its own
    await db.insert('exercise_details', {'exercise_id': 'source', 'user_id': me, 'unit_system': 'imperial'});
    await local.moveExerciseHistory(sourceId: 'target', targetId: 'source', userId: me, deleteSource: false);

    final rows = await db.query('exercise_details', where: 'user_id = ?', whereArgs: [me]);
    expect(rows, hasLength(1));
    expect(rows.single, containsPair('exercise_id', 'source'));
    expect(rows.single, containsPair('unit_system', 'imperial'));
    // the target kept its row whole, empty fields included
    expect(rows.single['rest_timer'], isNull);
    expect(rows.single['note'], isNull);
  });

  test('a chart follows the exercise unless the target already has one of that type', () async {
    await db.insert('charts', {
      'user_id': me,
      'type': 'topSetWeight',
      'data': '{"exerciseName":"source"}',
      'sort_order': 0,
    });
    await db.insert('charts', {
      'user_id': me,
      'type': 'totalVolume',
      'data': '{"exerciseName":"source"}',
      'sort_order': 1,
    });
    await db.insert('charts', {
      'user_id': me,
      'type': 'totalVolume',
      'data': '{"exerciseName":"target"}',
      'sort_order': 2,
    });

    await local.moveExerciseHistory(sourceId: 'source', targetId: 'target', userId: me, deleteSource: false);

    final charts = await db.query('charts', where: 'user_id = ?', whereArgs: [me], orderBy: 'sort_order');
    expect(
      [for (final each in charts) (each['type'], each['data'], each['sort_order'])],
      [
        ('topSetWeight', '{"exerciseName":"target"}', 0),
        ('totalVolume', '{"exerciseName":"target"}', 2),
      ],
    );
  });

  test('a deleted custom goes after its children have moved, so the cascade takes nothing', () async {
    await seed(me, 'custom');

    await local.moveExerciseHistory(sourceId: 'custom', targetId: 'target', userId: me, deleteSource: true);

    expect(await column('exercises', 'id', 'id = ?', ['custom']), isEmpty);
    expect(await column('workout_exercises', 'exercise_id', 'id = ?', ['$me-workout-exercise']), ['target']);
    expect(await column('sets', 'weight', 'id = ?', ['$me-set']), [50]);
    expect(await column('template_exercises', 'exercise_id', 'id = ?', ['$me-template-exercise']), ['target']);
  });

  test('a library source is never deleted here, whatever the flag says', () async {
    await local.moveExerciseHistory(sourceId: 'source', targetId: 'target', userId: me, deleteSource: true);

    expect(await column('exercises', 'id', 'id = ?', ['source']), ['source']);
  });
}
