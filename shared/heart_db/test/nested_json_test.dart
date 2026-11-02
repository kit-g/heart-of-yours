import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_db/src/sql.dart' as sql;
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// A workout's sets are built by a subquery inside `json_object`. SQLite does
/// not promise that a subquery's result stays marked as JSON: without `json()`
/// around it, SQLite 3.54.1 stores the list as a string, the model reads no
/// sets, and the next save would send a workout without them.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const bench = 'catalog-bench';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.insert('exercises', {
      'id': bench,
      'name': 'Bench Press (Barbell)',
      'category': 'Barbell',
      'target': 'Chest',
    });
    await local.storeWorkoutHistory([
      Workout.fromJson({
        'id': 'w1',
        'name': 'Push',
        'start': '2026-10-03T18:00:00.000Z',
        'end': '2026-10-03T19:00:00.000Z',
        'exercises': [
          {
            'order': 0,
            'id': 'w1-ex',
            'exercise': {'id': bench, 'category': 'Barbell', 'name': 'Bench Press (Barbell)', 'target': 'Chest'},
            'sets': [
              {'id': 'w1-s1', 'completed': true, 'reps': 5, 'weight': 100},
            ],
          },
        ],
      }),
    ], user);
  });

  tearDown(() => db.close());

  Future<Object?> setsIn(String query, List<Object?> arguments) async {
    final [row] = await db.rawQuery(query, arguments);
    final [exercise] = jsonDecode(row['exercises'] as String) as List<dynamic>;
    return (exercise as Map<String, dynamic>)['sets'];
  }

  Matcher isTheOneSet = isA<List<dynamic>>().having(
    (sets) => (sets.single as Map<String, dynamic>)['id'],
    'id',
    'w1-s1',
  );

  test('the history reads sets as a list', () async {
    expect(await setsIn(sql.history, [user]), isTheOneSet);
  });

  test('one workout reads its sets as a list', () async {
    expect(await setsIn(sql.getWorkout, ['w1', user]), isTheOneSet);
  });

  test('the active workout reads its sets as a list', () async {
    await db.update('workouts', {'end': null, 'synced': 0});
    expect(await setsIn(sql.activeWorkout, [user]), isTheOneSet);
  });

  test('sets reach the model through every read', () async {
    final history = await local.getWorkoutHistory(user);
    expect(history!.single.single.single.id, 'w1-s1');
    expect((await local.getWorkout(user, 'w1'))!.single.single.id, 'w1-s1');
  });
}
