import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
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
  /// [exercise].
  Future<void> seed({
    required String exercise,
    required DateTime start,
    int completed = 1,
    int skipped = 0,
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
    final (:muscles, start: _, sets: _) = rows.first;
    expect(muscles.primary.ids, ['pectoralis_major_l', 'pectoralis_major_r']);
    expect(muscles.secondary?.groups, ['arms']);
  });

  test('an untagged custom exercise comes back with empty tagging, not dropped', () async {
    await seed(exercise: 'mine', start: DateTime.utc(2026, 9, 2, 10), completed: 4);

    final [(:muscles, :sets, start: _)] = await local.getMuscleSets(from, to, userId: userId);

    expect(sets, 4);
    expect(muscles.isEmpty, isTrue);
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
}
