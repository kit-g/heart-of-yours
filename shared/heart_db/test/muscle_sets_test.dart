import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The muscle map's read (#136): completed sets per exercise, with the
/// exercise's tagging, in a period.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  final from = DateTime.utc(2026, 9, 1);
  final to = DateTime.utc(2026, 9, 8);

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
          'ids': ['pectoralis_major_l', 'pectoralis_major_r'],
          'groups': [],
        },
        'secondary': {
          'ids': [],
          'groups': ['arms'],
        },
      }),
    });
    await db.insert('exercises', {
      'id': 'mine',
      'name': 'My Thing',
      'category': 'Barbell',
      'target': 'Other',
      'user_id': userId,
      'own': 1,
    });
  });

  tearDown(() => db.close());

  var sequence = 0;

  /// A workout with [completed] ticked sets and [skipped] unticked ones of
  /// [exercise], the first [warmups] of the ticked ones warm-ups.
  Future<void> seed({
    required String exercise,
    required DateTime start,
    int completed = 1,
    int skipped = 0,
    int warmups = 0,
    bool finished = true,
    String user = userId,
  }) async {
    final workout = 'w${sequence++}';
    await db.insert('workouts', {
      'id': workout,
      'start': start.toIso8601String(),
      'end': switch (finished) {
        true => start.add(const Duration(hours: 1)).toIso8601String(),
        false => null,
      },
      'user_id': user,
    });
    await db.insert('workout_exercises', {
      'id': '$workout-e',
      'workout_id': workout,
      'exercise_id': exercise,
      'exercise_order': 0,
    });
    for (final (index, done) in [...List.filled(completed, 1), ...List.filled(skipped, 0)].indexed) {
      await db.insert('sets', {
        'id': '$workout-s$index',
        'exercise_id': '$workout-e',
        'completed': done,
        'reps': 5,
        'set_type': switch (index < warmups) {
          true => 'warmup',
          false => null,
        },
      });
    }
  }

  test('counts completed sets per exercise per workout, with its start and the exercise\'s tagging', () async {
    final monday = DateTime.utc(2026, 9, 2, 10);
    final thursday = DateTime.utc(2026, 9, 4, 10);
    await seed(exercise: 'bench', start: monday, completed: 3, skipped: 2);
    await seed(exercise: 'bench', start: thursday, completed: 2);

    final rows = await local.getMuscleSets(from, to, userId: userId);

    expect(rows.map((row) => (row.start, row.sets)), unorderedEquals([(monday.toLocal(), 3), (thursday.toLocal(), 2)]));
    final (:muscles, :target, start: _, sets: _) = rows.first;
    expect(muscles.primary.ids, ['pectoralis_major_l', 'pectoralis_major_r']);
    expect(muscles.secondary?.groups, ['arms']);
    expect(target, Target.chest);
  });

  test('leaves out warm-ups, and counts drop and failure sets', () async {
    await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 2, 10), completed: 4, warmups: 2);
    await db.update('sets', {'set_type': 'drop'}, where: 'id = ?', whereArgs: ['w${sequence - 1}-s3']);

    final [(:sets, muscles: _, target: _, start: _)] = await local.getMuscleSets(from, to, userId: userId);

    expect(sets, 2);
  });

  test('an untagged custom exercise comes back with empty tagging and its target, not dropped', () async {
    await seed(exercise: 'mine', start: DateTime.utc(2026, 9, 2, 10), completed: 4);

    final [(:muscles, :sets, :target, start: _)] = await local.getMuscleSets(from, to, userId: userId);

    expect(sets, 4);
    expect(muscles.isEmpty, isTrue);
    // what the map places it by
    expect(target, Target.other);
  });

  test('leaves out unfinished workouts, other users, and anything outside [from, to)', () async {
    await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 2, 10), finished: false);
    await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 2, 10), user: 'user-2');
    await seed(exercise: 'bench', start: DateTime.utc(2026, 8, 31, 23));
    await seed(exercise: 'bench', start: to);

    expect(await local.getMuscleSets(from, to, userId: userId), isEmpty);
  });

  test('no user matches nothing', () async {
    await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 2, 10));
    expect(await local.getMuscleSets(from, to), isEmpty);
  });

  group('the pattern lens\'s read (#341)', () {
    test('carries the workout, the movement and the target with each count', () async {
      final monday = DateTime.utc(2026, 9, 2, 10);
      await seed(exercise: 'bench', start: monday, completed: 3, skipped: 1);

      final [row] = await local.getLensSets(from, to, userId: userId);

      expect(row.workoutId, 'w${sequence - 1}');
      expect(row.start, monday.toLocal());
      expect(row.sets, 3);
      expect(row.movement.groups, ['horizontal_press']);
      expect(row.target, Target.chest);
      expect(row.muscles.primary.ids, ['pectoralis_major_l', 'pectoralis_major_r']);
    });

    test('an untagged custom exercise keeps its target, with no movement and no muscles', () async {
      await seed(exercise: 'mine', start: DateTime.utc(2026, 9, 2, 10), completed: 2);

      final [row] = await local.getLensSets(from, to, userId: userId);

      expect(row.sets, 2);
      expect(row.target, Target.other);
      expect(row.movement.isEmpty, isTrue);
      expect(row.muscles.isEmpty, isTrue);
    });

    test('leaves out warm-ups, unfinished workouts, other users and no user at all', () async {
      await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 2, 10), completed: 2, warmups: 2);
      await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 3, 10), finished: false);
      await seed(exercise: 'bench', start: DateTime.utc(2026, 9, 3, 10), user: 'user-2');

      expect(await local.getLensSets(from, to, userId: userId), isEmpty);
      expect(await local.getLensSets(from, to), isEmpty);
    });
  });
}
