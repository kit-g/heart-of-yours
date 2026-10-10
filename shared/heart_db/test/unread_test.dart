import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// What this build cannot read survives the mirror (#277, heart-api#125).
///
/// heart_models sets aside an exercise of a kind a newer build added, a set of
/// a shape this build predates, and keeps a set type it doesn't know as its
/// word. It carries them only through its own `toMap`: between a download
/// and the next save sits this store, so whatever it drops, an edit from the
/// mirror deletes on the server. The round trip is the contract.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const bench = 'catalog-bench';

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.insert('exercises', {
      'id': bench,
      'name': 'Bench Press (Barbell)',
      'category': 'Barbell',
      'target': 'Chest',
    });
  });

  tearDown(() => db.close());

  const benchJson = {'id': bench, 'category': 'Barbell', 'name': 'Bench Press (Barbell)', 'target': 'Chest'};

  Map<String, dynamic> set(String id, {String? type}) {
    return {
      'id': id,
      'completed': true,
      'started_at': '2026-09-26T08:00:00.000Z',
      'reps': 5,
      'weight': 100.0,
      'set_type': ?type,
    };
  }

  /// A set whose reps arrive in a shape this build predates.
  final newerSet = {
    'id': 'newer-set',
    'completed': true,
    'reps': {'min': 5, 'max': 8},
    'weight': 100.0,
  };

  /// An exercise of a category this build has never heard of.
  final newerExercise = {
    'order': 1,
    'id': 'sled-ex',
    'exercise': {'id': 'sled', 'category': 'Weighted Push', 'name': 'Sled Push', 'target': 'Legs'},
    'sets': [set('sled-set')],
  };

  Map<String, dynamic> workoutJson(String id, {List<Map<String, dynamic>>? exercises}) {
    return {
      'id': id,
      'name': 'Push',
      'start': '2026-09-26T08:00:00.000Z',
      'end': '2026-09-26T09:00:00.000Z',
      'exercises':
          exercises ??
          [
            {
              'order': 0,
              'id': '$id-ex',
              'exercise': benchJson,
              'sets': [set('known'), newerSet, set('cluster', type: 'cluster')],
            },
            newerExercise,
          ],
    };
  }

  Future<Workout> readBack(String id) async {
    final history = await local.getWorkoutHistory(user);
    return history!.singleWhere((each) => each.id == id);
  }

  List<Map> exercisesOf(Workout workout) => (workout.toMap()['exercises'] as List).cast<Map>();

  test('the models set the newer items aside to begin with', () {
    final workout = Workout.fromJson(workoutJson('w1'));

    expect(workout.unread.map((each) => each['id']), ['sled-ex']);
    expect(workout.single.unread.map((each) => each['id']), ['newer-set']);
    expect(workout.single.last.setTypeValue, 'cluster');
  });

  test('a workout read back from the mirror carries every exercise and set it could not read', () async {
    await local.storeWorkoutHistory([Workout.fromJson(workoutJson('w1'))], user);

    final workout = await readBack('w1');

    expect(workout.unread.map((each) => each['id']), ['sled-ex']);
    final exercises = exercisesOf(workout);
    // the save from the mirror sends them all, which is what heart-api#125 asks
    expect(exercises.map((each) => each['id']), containsAll(['w1-ex', 'sled-ex']));
    final sets = (exercises.firstWhere((each) => each['id'] == 'w1-ex')['sets'] as List).cast<Map>();
    expect(sets.map((each) => each['id']), containsAll(['known', 'newer-set', 'cluster']));
    expect(sets.firstWhere((each) => each['id'] == 'newer-set')['reps'], {'min': 5, 'max': 8});
  });

  test('a set type this build does not know keeps its word, not "normal"', () async {
    await local.storeWorkoutHistory([Workout.fromJson(workoutJson('w1'))], user);

    final [stored] = await db.query('sets', where: 'id = ?', whereArgs: ['cluster']);
    expect(stored['set_type'], 'cluster');

    final workout = await readBack('w1');
    final cluster = workout.single.firstWhere((each) => each.id == 'cluster');
    expect(cluster.setTypeValue, 'cluster');
    // a plain set is still stored the one way plain sets are
    final [plain] = await db.query('sets', where: 'id = ?', whereArgs: ['known']);
    expect(plain['set_type'], isNull);
  });

  test('a workout whose every exercise is newer is whole, and is stored', () async {
    await local.storeWorkoutHistory([
      Workout.fromJson(workoutJson('w2', exercises: [newerExercise])),
    ], user);

    final workout = await readBack('w2');

    expect(workout, isEmpty, reason: 'nothing this build can show');
    expect(exercisesOf(workout).map((each) => each['id']), ['sled-ex']);
  });

  test('a shallow copy of the workout does not erase what the mirror kept', () async {
    await local.storeWorkoutHistory([Workout.fromJson(workoutJson('w1'))], user);

    // a list page, a PATCH echo: the row without its detail
    await local.storeWorkoutHistory([Workout.fromJson(workoutJson('w1', exercises: []))], user);

    final workout = await readBack('w1');
    expect(workout.unread.map((each) => each['id']), ['sled-ex']);
    expect(workout.single.unread.map((each) => each['id']), ['newer-set']);
  });

  test('a copy that carries detail and nothing unread clears the kept list: the server says it is gone', () async {
    await local.storeWorkoutHistory([Workout.fromJson(workoutJson('w1'))], user);

    await local.storeWorkoutHistory([
      Workout.fromJson(
        workoutJson(
          'w1',
          exercises: [
            {
              'order': 0,
              'id': 'w1-ex',
              'exercise': benchJson,
              'sets': [set('known')],
            },
          ],
        ),
      ),
    ], user);

    final workout = await readBack('w1');
    expect(workout.unread, isEmpty);
    expect(workout.single.unread, isEmpty);
  });

  group('templates', () {
    Template template() {
      return Template.fromJson({
        'id': 't1',
        'name': 'Push day',
        'order': 0,
        'exercises': [
          {
            'id': 't1-ex',
            'exercise': benchJson,
            'sets': [set('known'), newerSet],
          },
          newerExercise,
        ],
      });
    }

    test('a template read back carries the exercises and sets it could not read', () async {
      await local.storeTemplates([template()], userId: user);

      final [stored] = (await local.getTemplates(user)).toList();

      expect(stored.unread.map((each) => each['id']), ['sled-ex']);
      expect(stored.single.unread.map((each) => each['id']), ['newer-set']);
    });

    test('an edit from the mirror keeps them', () async {
      await local.storeTemplates([template()], userId: user);
      final [stored] = (await local.getTemplates(user)).toList();

      await local.updateTemplate(stored..name = 'Push day B');

      final [edited] = (await local.getTemplates(user)).toList();
      expect(edited.name, 'Push day B');
      expect(edited.unread.map((each) => each['id']), ['sled-ex']);
      expect(edited.single.unread.map((each) => each['id']), ['newer-set']);
    });
  });
}
