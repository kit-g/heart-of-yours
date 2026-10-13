import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The writes an import of the app's own JSON export makes (heart-of-yours#329),
/// against a real in-memory SQLite.
///
/// `DataImport` in heart_state decides what is new by reading the store back
/// by id, and writes only that. What it needs from the store is pinned here:
/// every row it writes reads back under the id it was written with, so the
/// next import finds it; writing the same rows again leaves one of each; and a
/// workout lands unsynced, with its sets, for the upsync to carry.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'u1';

  Future<int> count(String table) async {
    final rows = await db.query(table, columns: ['count(*) AS n']);
    return rows.single['n'] as int;
  }

  final bench = Exercise.fromJson({'id': 'ex-bench', 'name': 'Bench Press', 'category': 'Barbell', 'target': 'Chest'});
  final custom = Exercise.fromJson({
    'id': 'ex-custom',
    'name': 'Muffin pull-up',
    'category': 'Reps Only',
    'target': 'Other',
    'own': 1,
  });
  final folder = TemplateFolder.fromJson({'id': 'f1', 'name': 'Push', 'order': 0});

  Map<String, dynamic> entry(String id, Exercise exercise) {
    return {
      'id': id,
      'order': 0,
      'exercise': exercise.toMap(),
      'sets': [
        {'id': '$id-s0', 'weight': 60, 'reps': 8, 'completed': 1},
        {'id': '$id-s1', 'weight': 60, 'reps': 6, 'completed': 1},
      ],
    };
  }

  final workout = Workout.fromJson({
    'id': 'w1',
    'start': '2026-03-01T10:00:00.000Z',
    'end': '2026-03-01T11:00:00.000Z',
    'exercises': [entry('w1-0', bench), entry('w1-1', custom)],
  });
  final template = Template.fromJson({
    'id': 't1',
    'name': 'Push day',
    'order': 0,
    'folder': folder.toMap(),
    'exercises': [entry('t1-0', bench)],
  });
  final goal = Goal.fromJson({
    'id': 'g1',
    'metric': 'totalReps',
    'exerciseId': custom.id,
    'stages': [
      {'id': 'g1-s1', 'target': 50},
    ],
  });

  /// What `DataImport.import` writes, in its order.
  Future<void> importRows() async {
    await local.storeExercises([custom], userId: user);
    await local.storeTemplateFolder(folder, userId: user);
    await local.storeTemplates([template], userId: user);
    await local.finishWorkout(workout, user);
    await local.setExerciseUnit(exerciseName: custom.id, userId: user, unit: .imperial);
    await local.createGoal(goal, user);
  }

  setUp(() async {
    db = await openTestDatabase();
    // as the app opens it: a replaced row takes its children with it
    await db.execute('PRAGMA foreign_keys = ON');
    local = await LocalDatabase.init(other: db);
    await local.storeExercises([bench]);
  });

  tearDown(() => db.close());

  test('every row reads back under the id it was written with', () async {
    await importRows();

    final (_, exercises) = await local.getExercises(userId: user);
    expect(exercises.map((each) => each.id), containsAll([bench.id, custom.id]));
    expect(exercises.singleWhere((each) => each.id == custom.id).isMine, isTrue);
    expect((await local.getTemplateFolders(user)).map((each) => each.id), ['f1']);
    expect((await local.getTemplates(user)).single.folderId, 'f1');
    expect((await local.getWorkoutHistory(user))!.map((each) => each.id), ['w1']);
    expect(await local.getExerciseUnits(user), {custom.id: MeasurementUnit.imperial});
    final goals = await local.getTargetUserGoals(requesterId: user, targetUserId: user);
    expect(goals.map((each) => each.id), ['g1']);
  });

  test('the workout lands unsynced, with every set, for the upsync to carry', () async {
    await importRows();

    final [stored] = (await local.getWorkoutHistory(user))!.toList();
    expect(stored.synced, isFalse);
    expect(stored.map((each) => each.length), [2, 2]);
    expect((await local.unsyncedGoals(user)).map((each) => each.id), ['g1']);
  });

  test('writing the same rows twice leaves one of each', () async {
    await importRows();
    final first = {
      for (final table in [
        'exercises',
        'template_folders',
        'templates',
        'template_exercises',
        'workouts',
        'workout_exercises',
        'sets',
        'exercise_details',
        'goals',
      ])
        table: await count(table),
    };

    await importRows();

    expect({for (final table in first.keys) table: await count(table)}, first);
  });
}
