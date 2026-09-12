// A weighted-bodyweight set logged at bodyweight carries no *added* weight,
// which is the ordinary way to do one. Against the real schema, because the
// bug these guard was a NULL falling out of an aggregate: every metric query
// over such a set has to answer with a number or not answer at all — never
// with a row whose `value` is null, which `getExerciseMetics` rejects as a
// malformed shape and the chart draws as its error state.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const exerciseId = 'catalog-dips';

  var sequence = 0;

  /// One completed workout of [sets], each `(weight, reps)` — a null weight is
  /// a set done at plain bodyweight.
  Future<void> seedWorkout(List<(double?, int?)> sets, {DateTime? start}) async {
    final at = start ?? DateTime.utc(2026, 1, 1 + sequence);
    final workout = 'workout-${sequence++}';
    await db.insert('workouts', {
      'id': workout,
      'user_id': userId,
      'start': at.toIso8601String(),
      'end': at.add(const Duration(hours: 1)).toIso8601String(),
    });
    await db.insert('workout_exercises', {
      'id': '$workout-we',
      'workout_id': workout,
      'exercise_id': exerciseId,
      'exercise_order': 0,
    });
    for (final (index, (weight, reps)) in sets.indexed) {
      await db.insert('sets', {
        'id': '$workout-set-$index',
        'exercise_id': '$workout-we',
        'completed': 1,
        'weight': weight,
        'reps': reps,
      });
    }
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    sequence = 0;
    await db.insert('exercises', {
      'id': exerciseId,
      'name': 'Chest Dips',
      'category': Category.weightedBodyWeight.value,
      'target': Target.chest.value,
      'own': 0,
    });
  });

  tearDown(() async => db.close());

  Future<List<(num, DateTime)>> metric(ChartPreferenceType type) async {
    return await local.getExerciseMetics(userId, type, exerciseId, limit: 30) ?? const [];
  }

  group('average working weight', () {
    test('a workout of bodyweight-only sets answers with a number, not a null row', () async {
      // `sum(weight * reps) / sum(reps)` over rows whose weight is NULL sums to
      // NULL, and a null `value` no longer matches the row pattern — so the
      // whole chart fell to its error state rather than plotting.
      await seedWorkout([(null, 12), (null, 10), (null, 8)]);

      final result = await metric(.averageWorkingWeight);

      expect(result, hasLength(1));
      expect(result.single.$1, 0, reason: 'no added weight is nought added weight');
    });

    test('a mixed workout averages the added weight over every rep', () async {
      // 20kg x 10 = 200 over 10 + 10 bodyweight reps: 200 / 20.
      await seedWorkout([(20.0, 10), (null, 10)]);

      final result = await metric(.averageWorkingWeight);

      expect(result.single.$1, 10);
    });

    test('a fully weighted workout is unchanged', () async {
      await seedWorkout([(20.0, 10), (30.0, 10)]);

      final result = await metric(.averageWorkingWeight);

      expect(result.single.$1, 25);
    });

    test('every workout of a bodyweight history plots', () async {
      await seedWorkout([(null, 12)]);
      await seedWorkout([(null, 10)]);
      await seedWorkout([(20.0, 8)]);

      final result = await metric(.averageWorkingWeight);

      expect(result, hasLength(3), reason: 'none of them dropped out or threw');
    });
  });

  group('the other metrics over the same sets', () {
    test('top set weight, total volume and total reps all answer', () async {
      await seedWorkout([(null, 12), (20.0, 8)]);

      expect((await metric(.topSetWeight)).single.$1, 20);
      expect((await metric(.totalVolume)).single.$1, 160, reason: '20 x 8, the bodyweight reps adding nothing');
      expect((await metric(.totalReps)).single.$1, 20);
      expect((await metric(.maxConsecutiveReps)).single.$1, 12);
    });

    test('estimated 1RM skips a bodyweight-only workout rather than nulling it', () async {
      // It guards with `AND sets.weight > 0`, so the workout produces no row at
      // all — which is a different answer from a row that cannot be read.
      await seedWorkout([(null, 12)]);

      expect(await metric(.estimatedOneRepMax), isEmpty);
    });
  });
}
