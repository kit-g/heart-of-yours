import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// The training charts' read (#137): every finished workout in a window, with
/// its working sets, its volume and how long it ran.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'muffin';
  final from = DateTime.utc(2026, 9, 1);
  final to = DateTime.utc(2026, 9, 8);

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);

    for (final (id, category) in [('bench', 'Barbell'), ('pullup', 'Assisted Body Weight'), ('run', 'Cardio')]) {
      await db.insert('exercises', {'id': id, 'name': id, 'category': category, 'target': 'Other'});
    }
  });

  tearDown(() => db.close());

  var sequence = 0;

  /// A workout lasting [minutes], holding [sets] of each exercise: (exercise,
  /// weight, reps, completed, set type).
  Future<String> seed({
    required DateTime start,
    int minutes = 60,
    List<(String, double?, int?, bool, String?)> sets = const [],
    bool finished = true,
    String user = userId,
    String? pauses,
  }) async {
    final workout = 'w${sequence++}';
    await db.insert('workouts', {
      'id': workout,
      'start': start.toIso8601String(),
      'end': switch (finished) {
        true => start.add(Duration(minutes: minutes)).toIso8601String(),
        false => null,
      },
      'user_id': user,
      'pauses': pauses,
    });
    for (final (index, (exercise, weight, reps, completed, type)) in sets.indexed) {
      final we = '$workout-e$index';
      await db.insert('workout_exercises', {
        'id': we,
        'workout_id': workout,
        'exercise_id': exercise,
        'exercise_order': index,
      });
      await db.insert('sets', {
        'id': '$we-s',
        'exercise_id': we,
        'completed': completed ? 1 : 0,
        'weight': weight,
        'reps': reps,
        'set_type': type,
      });
    }
    return workout;
  }

  test('counts working sets and sums their volume, leaving out warm-ups, unticked sets and assistance', () async {
    final start = DateTime.utc(2026, 9, 2, 10);
    await seed(
      start: start,
      sets: [
        ('bench', 100, 5, true, null),
        ('bench', 100, 5, true, 'drop'),
        ('bench', 60, 10, true, 'warmup'),
        ('bench', 100, 5, false, null),
        ('pullup', 20, 8, true, null),
        ('run', null, null, true, null),
      ],
    );

    final [row] = await local.getTrainingTotals(from, to, userId: userId);

    expect(row.start, start.toLocal());
    expect(row.sets, 4);
    expect(row.volume, 1000);
    expect(row.duration, const Duration(hours: 1));
  });

  test('a workout with no working sets still counts its time', () async {
    await seed(start: DateTime.utc(2026, 9, 3, 10), minutes: 30);

    final [row] = await local.getTrainingTotals(from, to, userId: userId);

    expect((row.sets, row.volume, row.duration), (0, 0, const Duration(minutes: 30)));
  });

  test('its pauses come off its duration', () async {
    final start = DateTime.utc(2026, 9, 3, 10);
    await seed(
      start: start,
      minutes: 90,
      pauses: jsonEncode([
        {
          'start': start.add(const Duration(minutes: 10)).toIso8601String(),
          'end': start.add(const Duration(minutes: 30)).toIso8601String(),
        },
      ]),
    );

    final [row] = await local.getTrainingTotals(from, to, userId: userId);

    expect(row.duration, const Duration(minutes: 70));
  });

  test('leaves out unfinished workouts, other users, no user, and anything outside [from, to)', () async {
    final sets = [('bench', 100.0, 5, true, null)];
    await seed(start: DateTime.utc(2026, 9, 2, 10), sets: sets, finished: false);
    await seed(start: DateTime.utc(2026, 9, 2, 10), sets: sets, user: 'someone-else');
    await seed(start: DateTime.utc(2026, 8, 31, 23), sets: sets);
    await seed(start: to, sets: sets);

    expect(await local.getTrainingTotals(from, to, userId: userId), isEmpty);
    await seed(start: DateTime.utc(2026, 9, 2, 10), sets: sets);
    expect(await local.getTrainingTotals(from, to), isEmpty);
  });
}
