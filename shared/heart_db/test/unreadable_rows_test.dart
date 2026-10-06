import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// A row this build cannot read costs only itself.
///
/// Such a row was written by a newer build (an app downgraded, a database
/// restored onto an older one) or synced down with a value this build has never
/// heard of. Before, one unreadable exercise failed the catalog read, which
/// stopped the whole app's start, and one unreadable workout took History with
/// it. The row is left where it is, for the build that can read it.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const future = 'A Category From The Future';

  Map<String, Object?> exerciseRow(String id, String name, {String category = 'Barbell'}) {
    return {'id': id, 'name': name, 'category': category, 'target': 'Chest'};
  }

  Exercise exercise(String id, String name) {
    return Exercise.fromJson(exerciseRow(id, name));
  }

  Workout workout(String id, Exercise exercise, {required String start}) {
    return Workout.fromJson({
      'id': id,
      'name': 'Session $id',
      'start': start,
      'end': start.replaceFirst('T18', 'T19'),
      'exercises': [
        {
          'order': 0,
          'id': '$id-ex',
          'start': start,
          'exercise': exercise.toMap(),
          'sets': [
            {'id': '$id-s1', 'weight': 60, 'reps': 5, 'completed': true},
          ],
        },
      ],
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  test('an exercise with a category from the future leaves the rest of the catalog', () async {
    await db.insert('exercises', exerciseRow('bench', 'Bench Press (Barbell)'));
    await db.insert('exercises', exerciseRow('yoke', 'Yoke Carry', category: future));

    final (_, exercises) = await local.getExercises(userId: user);

    expect(exercises.map((each) => each.name), ['Bench Press (Barbell)']);
    expect(await db.query('exercises'), hasLength(2), reason: 'the unreadable row stays for a build that can read it');
  });

  test('a workout joining an unreadable exercise leaves the rest of History', () async {
    final bench = exercise('bench', 'Bench Press (Barbell)');
    final squat = exercise('squat', 'Squat (Barbell)');
    await db.insert('exercises', exerciseRow('bench', 'Bench Press (Barbell)'));
    await db.insert('exercises', exerciseRow('squat', 'Squat (Barbell)'));
    await local.storeWorkoutHistory(
      [
        workout('w1', bench, start: '2026-10-01T18:00:00.000Z'),
        workout('w2', squat, start: '2026-10-02T18:00:00.000Z'),
      ],
      user,
    );

    // what a newer build's catalog leaves behind
    await db.update('exercises', {'category': future}, where: 'id = ?', whereArgs: ['squat']);

    final history = await local.getWorkoutHistory(user);

    expect(history?.map((each) => each.id), ['w1']);
    expect(await local.getWorkout(user, 'w2'), isNull, reason: 'unreadable reads as absent');
    expect(await local.getWorkout(user, 'w1'), isNotNull);
  });

  test('a goal with a metric from the future leaves the other goals', () async {
    await local.storeGoals(
      [
        Goal(
          id: 'g1',
          metric: .topSetWeight,
          exerciseId: 'bench',
          stages: [GoalStage(id: 's0', target: 100)],
        ),
        Goal(
          id: 'g2',
          metric: .topSetWeight,
          exerciseId: 'bench',
          stages: [GoalStage(id: 's0', target: 120)],
        ),
      ],
      user,
    );
    await db.update('goals', {'metric': 'aMetricFromTheFuture'}, where: 'id = ?', whereArgs: ['g2']);

    final goals = await local.getTargetUserGoals(requesterId: user, targetUserId: user);

    expect(goals.map((each) => each.id), ['g1']);
  });
}
