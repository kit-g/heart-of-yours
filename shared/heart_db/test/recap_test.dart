import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// A recap's reads (#154): the period's finished workouts with their trained
/// time, and the working sets of what was trained in it, history included.
void main() {
  late Database db;
  late LocalDatabase local;

  const muffin = 'muffin';
  final from = DateTime.utc(2026, 9);
  final to = DateTime.utc(2026, 10);

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);

    await db.insert('exercises', {
      'id': 'bench',
      'name': 'Bench Press',
      'category': 'Barbell',
      'target': 'Chest',
      'movement': jsonEncode({
        'groups': ['horizontal_press'],
      }),
      'muscles': jsonEncode({
        'primary': {
          'ids': [],
          'groups': ['chest'],
        },
      }),
    });
    await db.insert('exercises', {
      'id': 'curl',
      'name': 'Curl',
      'category': 'Dumbbell',
      'target': 'Arms',
    });
  });

  tearDown(() => db.close());

  var sequence = 0;

  /// A workout of [muffin]'s (or [user]'s), with [sets] of [exercise] — each
  /// a weight, reps and whether it was ticked — the first [warmups] of them
  /// warm-ups.
  Future<String> seed({
    required DateTime start,
    String exercise = 'bench',
    List<(double, int, bool)> sets = const [(60, 5, true)],
    int warmups = 0,
    Duration length = const Duration(hours: 1),
    bool finished = true,
    String user = muffin,
    List<Map<String, String>>? pauses,
  }) async {
    final workout = 'w${sequence++}';
    await db.insert('workouts', {
      'id': workout,
      'start': start.toIso8601String(),
      'end': switch (finished) {
        true => start.add(length).toIso8601String(),
        false => null,
      },
      'user_id': user,
      'pauses': ?switch (pauses) {
        final List<Map<String, String>> pauses => jsonEncode(pauses),
        null => null,
      },
    });
    await db.insert('workout_exercises', {
      'id': '$workout-e',
      'workout_id': workout,
      'exercise_id': exercise,
      'exercise_order': 0,
    });
    for (final (index, (weight, reps, done)) in sets.indexed) {
      await db.insert('sets', {
        'id': '$workout-s$index',
        'exercise_id': '$workout-e',
        'completed': done ? 1 : 0,
        'weight': weight,
        'reps': reps,
        'set_type': switch (index < warmups) {
          true => 'warmup',
          false => null,
        },
      });
    }
    return workout;
  }

  group('getRecapWorkouts', () {
    test('the period\'s finished workouts, each with its time less its pauses', () async {
      final start = DateTime.utc(2026, 9, 2, 18);
      final id = await seed(
        start: start,
        length: const Duration(minutes: 70),
        pauses: [
          {
            'start': start.add(const Duration(minutes: 20)).toIso8601String(),
            'end': start.add(const Duration(minutes: 30)).toIso8601String(),
          },
        ],
      );
      await seed(start: DateTime.utc(2026, 9, 20, 9), length: const Duration(minutes: 45));

      final rows = await local.getRecapWorkouts(from, to, userId: muffin);

      expect(rows.map((row) => (row.id, row.start, row.trained)), [
        (id, start.toLocal(), const Duration(minutes: 60)),
        ('w${sequence - 1}', DateTime.utc(2026, 9, 20, 9).toLocal(), const Duration(minutes: 45)),
      ]);
    });

    test('leaves out unfinished workouts, other users, and anything outside [from, to)', () async {
      await seed(start: DateTime.utc(2026, 9, 2, 10), finished: false);
      await seed(start: DateTime.utc(2026, 9, 2, 10), user: 'someone-else');
      await seed(start: DateTime.utc(2026, 8, 31, 23));
      await seed(start: to);

      expect(await local.getRecapWorkouts(from, to, userId: muffin), isEmpty);
    });

    test('no user matches nothing', () async {
      await seed(start: DateTime.utc(2026, 9, 2, 10));
      expect(await local.getRecapWorkouts(from, to), isEmpty);
    });
  });

  group('getRecapSets', () {
    test('every working set of what the period trained, oldest first, history included', () async {
      final august = await seed(start: DateTime.utc(2026, 8, 20, 18), sets: [(80, 5, true)]);
      final september = await seed(start: DateTime.utc(2026, 9, 2, 18), sets: [(70, 5, true), (75, 3, true)]);

      final rows = await local.getRecapSets(from, to, userId: muffin);

      expect(rows.map((row) => (row.workoutId, row.weight, row.reps)), [
        (august, 80.0, 5),
        (september, 70.0, 5),
        (september, 75.0, 3),
      ]);
    });

    test('carries what the exercise is: its category, movement, tagging and target', () async {
      await seed(start: DateTime.utc(2026, 9, 2, 18));

      final [row] = await local.getRecapSets(from, to, userId: muffin);

      expect(row.exerciseId, 'bench');
      expect(row.start, DateTime.utc(2026, 9, 2, 18).toLocal());
      expect(row.category, Category.barbell);
      expect(row.movement.groups, ['horizontal_press']);
      expect(row.muscles.groupShares, {MuscleGroupKey.chest: 1.0});
      expect(row.target, Target.chest);
    });

    test('leaves out an exercise the period did not train, however much history it has', () async {
      await seed(start: DateTime.utc(2026, 8, 20, 18), exercise: 'curl');
      await seed(start: DateTime.utc(2026, 9, 2, 18));

      final rows = await local.getRecapSets(from, to, userId: muffin);

      expect(rows.map((row) => row.exerciseId).toSet(), {'bench'});
    });

    test('leaves out warm-ups, unticked sets, and anything after the period', () async {
      await seed(
        start: DateTime.utc(2026, 9, 2, 18),
        sets: [(40, 10, true), (60, 5, true), (65, 5, false)],
        warmups: 1,
      );
      await seed(start: DateTime.utc(2026, 10, 2, 18), sets: [(90, 1, true)]);

      final rows = await local.getRecapSets(from, to, userId: muffin);

      expect(rows.map((row) => row.weight), [60.0]);
    });

    test('leaves out unfinished workouts and other users, in the period and before it', () async {
      await seed(start: DateTime.utc(2026, 8, 2, 18), finished: false, sets: [(100, 1, true)]);
      await seed(start: DateTime.utc(2026, 8, 3, 18), user: 'someone-else', sets: [(110, 1, true)]);
      await seed(start: DateTime.utc(2026, 9, 2, 18), user: 'someone-else');
      await seed(start: DateTime.utc(2026, 9, 3, 18), finished: false);
      await seed(start: DateTime.utc(2026, 9, 4, 18), sets: [(60, 5, true)]);

      final rows = await local.getRecapSets(from, to, userId: muffin);

      expect(rows.map((row) => row.weight), [60.0]);
    });

    test('a dangling exercise comes back with no category, not dropped', () async {
      await seed(start: DateTime.utc(2026, 9, 2, 18), exercise: 'gone');

      final [row] = await local.getRecapSets(from, to, userId: muffin);

      expect(row.exerciseId, 'gone');
      expect(row.category, isNull);
      expect(row.muscles.isEmpty, isTrue);
      expect(row.target, Target.other);
    });

    test('no user matches nothing', () async {
      await seed(start: DateTime.utc(2026, 9, 2, 18));
      expect(await local.getRecapSets(from, to), isEmpty);
    });
  });
}
