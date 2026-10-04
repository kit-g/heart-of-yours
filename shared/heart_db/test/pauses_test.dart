import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Pauses and the time a set was ticked, through the mirror (#134).
///
/// The wire model sends a workout's pauses on every save, an empty list
/// included, and the server takes a present key as the new value. Whatever the
/// mirror drops is what the next save of that workout wipes on the server, so
/// the round trip is the contract — on every write path. The open pause never
/// goes on the wire; the mirror is the only place it survives a cold start.
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

  final pauses = [
    {'start': '2026-10-03T18:02:11.000Z', 'end': '2026-10-03T18:09:40.000Z'},
    {'start': '2026-10-03T18:40:00.000Z', 'end': '2026-10-03T18:50:00.000Z'},
  ];

  Workout server(String id, {List<Map<String, String>> pauses = const [], bool detail = true}) {
    return Workout.fromJson({
      'id': id,
      'name': 'Push',
      'start': '2026-10-03T18:00:00.000Z',
      'end': '2026-10-03T19:00:00.000Z',
      'pauses': pauses,
      'exercises': [
        if (detail)
          {
            'order': 0,
            'id': '$id-ex',
            'exercise': {'id': bench, 'category': 'Barbell', 'name': 'Bench Press (Barbell)', 'target': 'Chest'},
            'start': '2026-10-03T18:00:00.000Z',
            'sets': [
              {
                'id': '$id-s1',
                'completed': true,
                'started_at': '2026-10-03T18:00:00.000Z',
                'completed_at': '2026-10-03T18:42:00.000Z',
                'reps': 5,
                'weight': 100,
              },
            ],
          },
      ],
    });
  }

  Future<Workout> readBack(String id) async {
    final history = await local.getWorkoutHistory(user);
    return history!.singleWhere((each) => each.id == id);
  }

  List<Map<String, dynamic>> wire(Workout workout) => workout.pauses.map((pause) => pause.toMap()).toList();

  test('a synced workout reads back with its pauses, and its duration leaves them out', () async {
    await local.storeWorkoutHistory([server('w1', pauses: pauses)], user);

    final stored = await readBack('w1');

    expect(wire(stored), pauses);
    expect(stored.duration, const Duration(minutes: 42, seconds: 31));
    expect((await local.getWorkout(user, 'w1'))!.pauses, hasLength(2));
  });

  test('none is stored as nothing, and reads back as none', () async {
    await local.storeWorkoutHistory([server('w1')], user);

    final [row] = await db.query('workouts', columns: ['pauses']);
    expect(row['pauses'], isNull);
    expect((await readBack('w1')).pauses, isEmpty);
  });

  test('a copy without detail keeps the exercises and takes the pauses it carries', () async {
    await local.storeWorkoutHistory([server('w1')], user);
    await local.storeWorkoutHistory([server('w1', pauses: pauses, detail: false)], user);

    final stored = await readBack('w1');
    expect(stored.single.single.id, 'w1-s1');
    expect(wire(stored), pauses);
  });

  test('a finish keeps the pauses, and an edit of the finished workout too', () async {
    final workout = server('w1', pauses: pauses);
    await local.finishWorkout(workout, user);
    expect(wire(await readBack('w1')), pauses);

    final edited = (await readBack('w1'))..name = 'Pull';
    await local.finishWorkout(edited, user);
    expect(wire(await readBack('w1')), pauses);
  });

  test('a set keeps the time it was ticked through every write', () async {
    await local.storeWorkoutHistory([server('w1')], user);
    final ticked = DateTime.utc(2026, 10, 3, 18, 42);

    var set = (await readBack('w1')).single.single;
    expect(set.completedAt, ticked);

    await local.storeMeasurements(set..setMeasurements(weight: 105));
    set = (await readBack('w1')).single.single;
    expect((set.weight, set.completedAt), (105, ticked));
  });

  group('the active workout', () {
    late Workout workout;
    late ExerciseSet set;

    setUp(() async {
      workout = Workout(name: 'Push');
      await local.startWorkout(workout, user);
      set = ExerciseSet(benchPress, weight: 100, reps: 5);
      await local.startExercise(workout.id, WorkoutExercise(starter: set));
    });

    test('comes back paused after a cold start, with the pauses it closed', () async {
      final closed = [WorkoutPause.fromJson(pauses.first)];
      final open = DateTime.utc(2026, 10, 3, 18, 30);
      await local.setWorkoutPauses(workout.id, closed, open);

      final reopened = await LocalDatabase.init(other: db);
      final active = (await reopened.getActiveWorkout(user))!;

      expect(wire(active), [pauses.first]);
      expect(await reopened.getPausedAt(workout.id), open);
    });

    test('resumed, it is open no longer', () async {
      await local.setWorkoutPauses(workout.id, const [], DateTime.utc(2026, 10, 3, 18, 30));
      await local.setWorkoutPauses(workout.id, [WorkoutPause.fromJson(pauses.first)], null);

      expect(await local.getPausedAt(workout.id), isNull);
      expect((await local.getActiveWorkout(user))!.pauses, hasLength(1));
    });

    test('a ticked set keeps its time, and an unticked one loses it', () async {
      final ticked = DateTime.utc(2026, 10, 3, 18, 42);
      await local.markSetAsComplete(
        set
          ..isCompleted = true
          ..completedAt = ticked,
      );
      expect((await local.getActiveWorkout(user))!.single.single.completedAt, ticked);

      await local.markSetAsIncomplete(
        set
          ..isCompleted = false
          ..completedAt = null,
      );
      expect((await local.getActiveWorkout(user))!.single.single.completedAt, isNull);
    });

    test('finished, it is not paused, and the pause it was in is among its pauses', () async {
      await local.setWorkoutPauses(workout.id, const [], DateTime.utc(2026, 10, 3, 18, 30));
      workout
        ..pauses = [WorkoutPause.fromJson(pauses.first)]
        ..finish(DateTime.utc(2026, 10, 3, 19));
      await local.finishWorkout(workout, user);

      expect(await local.getPausedAt(workout.id), isNull);
      expect(wire(await local.getWorkout(user, workout.id) as Workout), [pauses.first]);
    });

    test('a server copy never touches the open pause', () async {
      final open = DateTime.utc(2026, 10, 3, 18, 30);
      await local.setWorkoutPauses(workout.id, const [], open);

      await local.storeWorkoutHistory([workout], user);

      expect(await local.getPausedAt(workout.id), open);
    });
  });
}
