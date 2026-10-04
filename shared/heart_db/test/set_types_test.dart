import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Set types, RPE and the workout note through the mirror (#151).
///
/// The wire model sends all three on every save, nulls included, and the
/// server takes a present key as the new value. Whatever the mirror drops is
/// what the next edit of that workout wipes on the server, so the round trip
/// is the contract. Warm-ups then stay out of records and charts, and sets
/// stored before types existed (a null column) still count.
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

  final benchPress = Exercise.fromJson({
    'id': bench,
    'name': 'Bench Press (Barbell)',
    'category': 'Barbell',
    'target': 'Chest',
  });

  Map<String, dynamic> set(String id, {required double weight, int reps = 5, String? type, double? rpe}) {
    return {
      'id': id,
      'completed': true,
      'started_at': '2026-09-26T08:00:00.000Z',
      'reps': reps,
      'weight': weight,
      'set_type': ?type,
      'rpe': rpe,
    };
  }

  Workout server(String id, {String start = '2026-09-26T08:00:00.000Z', required List<Map<String, dynamic>> sets}) {
    return Workout.fromJson({
      'id': id,
      'name': 'Push',
      'start': start,
      'end': start.replaceFirst('08:', '09:'),
      'note': 'Felt strong',
      'exercises': [
        {
          'order': 0,
          'id': '$id-ex',
          'exercise': {'id': bench, 'category': 'Barbell', 'name': 'Bench Press (Barbell)', 'target': 'Chest'},
          'start': start,
          'sets': sets,
        },
      ],
    });
  }

  Future<Workout> readBack(String id) async {
    final history = await local.getWorkoutHistory(user);
    return history!.singleWhere((each) => each.id == id);
  }

  test('a synced workout reads back with its set types, RPEs and note', () async {
    await local.storeWorkoutHistory([
      server(
        'w1',
        sets: [
          set('s1', weight: 60, type: 'warmup'),
          set('s2', weight: 100, rpe: 8.5),
        ],
      ),
    ], user);

    final stored = await readBack('w1');
    final [warmup, working] = stored.single.toList();

    expect(stored.note, 'Felt strong');
    expect((warmup.setType, warmup.rpe), (SetType.warmup, null));
    expect((working.setType, working.rpe), (SetType.normal, 8.5));
  });

  test('a plain set is stored as no type, as the server stores it', () async {
    await local.storeWorkoutHistory([
      server(
        'w1',
        sets: [
          set('s1', weight: 100, type: 'normal'),
          set('s2', weight: 60, type: 'warmup'),
        ],
      ),
    ], user);

    final rows = await db.query('sets', columns: ['id', 'set_type'], orderBy: 'id');
    expect(rows, [
      {'id': 's1', 'set_type': null},
      {'id': 's2', 'set_type': 'warmup'},
    ]);
  });

  test('an edit keeps what it does not touch, and the type it does', () async {
    await local.storeWorkoutHistory([
      server('w1', sets: [set('s1', weight: 60, type: 'warmup', rpe: 6)]),
    ], user);

    final stored = await readBack('w1');
    final only = stored.single.single..setMeasurements(weight: 65);
    await local.storeMeasurements(only);

    var again = (await readBack('w1')).single.single;
    expect((again.weight, again.setType, again.rpe), (65, SetType.warmup, 6));

    only.setType = .drop;
    await local.storeMeasurements(only);

    again = (await readBack('w1')).single.single;
    expect(again.setType, SetType.drop);
  });

  test('a template-started exercise keeps its warm-ups', () async {
    final workout = Workout(name: 'Push');
    await local.startWorkout(workout, user);

    final exercise = WorkoutExercise(starter: ExerciseSet(benchPress, setType: .warmup));
    await local.startExercise(workout.id, exercise);

    final active = await local.getActiveWorkout(user);
    expect(active!.single.single.setType, SetType.warmup);
  });

  test('last time carries each set\'s type, so Previous can match warm-ups to warm-ups (#236)', () async {
    await local.storeWorkoutHistory([
      server(
        'w1',
        sets: [
          set('s1', weight: 60, type: 'warmup'),
          set('s2', weight: 100),
          set('s3', weight: 80, type: 'drop'),
        ],
      ),
    ], user);

    final previous = await local.getPreviousSets(user);

    expect(
      previous[bench]?.map((each) => (each['set_id'], each['set_type'])),
      unorderedEquals([
        ('s1', 'warmup'),
        ('s2', null),
        ('s3', 'drop'),
      ]),
    );
  });

  test('last time is the newest session, and says when it was (#135)', () async {
    await local.storeWorkoutHistory([
      server('w1', start: '2026-09-20T08:00:00.000Z', sets: [set('old', weight: 90)]),
      server('w2', start: '2026-09-26T08:00:00.000Z', sets: [set('new', weight: 100)]),
      server('w0', start: '2026-09-10T08:00:00.000Z', sets: [set('older', weight: 80)]),
    ], user);

    final previous = await local.getPreviousSets(user);

    expect(previous[bench]?.map((each) => each['set_id']), ['new']);
    expect(previous[bench]?.single['workout_start'], '2026-09-26T08:00:00.000Z');
  });

  group('warm-ups are no record', () {
    final exercise = benchPress;

    setUp(() async {
      await local.storeWorkoutHistory([
        // a heavy single tagged as a warm-up: the heaviest set on file, and not a record
        server(
          'w1',
          sets: [
            set('s1', weight: 140, reps: 1, type: 'warmup'),
            set('s2', weight: 100),
          ],
        ),
      ], user);
    });

    test('in the records fold', () async {
      final records = (await local.getRecord(user, exercise))!;
      expect((records['heaviest'] as Map)['weight'], 100);
    });

    test('in every record kind, not only the heaviest', () async {
      // a warm-up that would win each kind: more weight, more volume, a better
      // estimate, and a rep max at 8 nobody else holds
      await local.storeWorkoutHistory([
        server(
          'w2',
          start: '2026-09-27T08:00:00.000Z',
          sets: [set('s3', weight: 120, reps: 8, type: 'warmup')],
        ),
      ], user);

      final records = (await local.getRecord(user, exercise))!;
      for (final kind in ['heaviest', 'oneRepMax', 'bestVolume']) {
        expect((records[kind] as Map)['workoutId'], 'w1', reason: '$kind went to the warm-up');
      }
      expect(
        (records['repMaxes'] as List).cast<Map>().map((each) => each['workoutId']),
        everyElement('w1'),
        reason: 'no rep max at 8 from a warm-up',
      );
    });

    test('so a session of warm-ups alone sets none, and is no session of the exercise', () async {
      await local.storeWorkoutHistory([
        server(
          'w2',
          start: '2026-09-27T08:00:00.000Z',
          sets: [set('s3', weight: 200, reps: 10, type: 'warmup')],
        ),
      ], user);

      final records = (await local.getRecord(user, exercise))!;
      expect(records.values.whereType<Map>().map((each) => each['workoutId']), everyElement('w1'));
      expect(records['sessions'], 1);
    });

    test('in the charts', () async {
      final top = await local.getWeightHistory(user, exercise);
      expect(top.single.$1, 100);

      final volume = await local.getExerciseMetics(user, .totalVolume, bench);
      expect(volume!.single.$1, 500);
    });

    test('while a set stored before types existed still counts', () async {
      await db.update('sets', {'set_type': null});

      final records = (await local.getRecord(user, exercise))!;
      expect((records['heaviest'] as Map)['weight'], 140);
    });
  });
}
