import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// What a program workout was asked to be (#566): kept from the start, sent
/// once the workout is on the server, and gone with its workout.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';

  Map<String, dynamic> plan(num weight) => {
    'templateId': 't1',
    'week': 2,
    'lighter': false,
    'exercises': [
      {
        'slot': 's1',
        'exerciseId': 'squat',
        'sets': [
          {'weight': weight, 'reps': 5, 'setId': '01a1b7d4-c1db-7fc9-b20f-e61fcc3b5aa5'},
        ],
      },
    ],
  };

  Future<void> workout(String id, {bool synced = false}) {
    return db.insert('workouts', {
      'id': id,
      'start': '2026-11-08T10:00:00.000Z',
      'user_id': userId,
      'name': 'Day A',
      'synced': synced ? 1 : 0,
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  test('a plan comes back as it was stored', () async {
    await workout('w1');
    await local.storeWorkoutPlan('w1', userId, plan(100));
    expect(await local.getWorkoutPlan('w1'), plan(100));
    expect(await local.getWorkoutPlan('w2'), isNull);
  });

  test('only plans of workouts already on the server are owed', () async {
    await workout('on-server', synced: true);
    await workout('in-progress');
    await local.storeWorkoutPlan('on-server', userId, plan(100));
    await local.storeWorkoutPlan('in-progress', userId, plan(80));

    final owed = await local.getUnsentWorkoutPlans(userId);

    expect(owed.map((each) => each.workoutId), ['on-server']);
    expect(owed.single.plan, plan(100));
    expect(await local.getUnsentWorkoutPlans('someone-else'), isEmpty);
  });

  test('a sent plan is owed no more, and no later plan replaces it', () async {
    await workout('w1', synced: true);
    await local.storeWorkoutPlan('w1', userId, plan(100));
    await local.markWorkoutPlanSent('w1');

    expect(await local.getUnsentWorkoutPlans(userId), isEmpty);

    // the server keeps the first it got, so the device does too
    await local.storeWorkoutPlan('w1', userId, plan(120));
    expect(await local.getWorkoutPlan('w1'), plan(100));
  });

  test('an unsent plan can still be replaced', () async {
    await workout('w1');
    await local.storeWorkoutPlan('w1', userId, plan(100));
    await local.storeWorkoutPlan('w1', userId, plan(110));
    expect(await local.getWorkoutPlan('w1'), plan(110));
  });

  test("a workout's plan goes with it", () async {
    // the app's connection always has foreign keys on; this one has to ask
    await db.execute('PRAGMA foreign_keys = ON');
    await workout('w1');
    await local.storeWorkoutPlan('w1', userId, plan(100));

    await db.delete('workouts', where: 'id = ?', whereArgs: ['w1']);

    expect(await local.getWorkoutPlan('w1'), isNull);
  });
}
