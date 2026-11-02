import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';
import 'utils.dart';

/// Suspicious entries in the mirror (#428): the server's flags kept as they
/// came, a decision kept until the server has it, and a discarded set out of
/// every count only while the feature is on.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'muffin';
  final bench = exercise(name: 'Bench Press', category: 'Barbell');
  final start = DateTime.utc(2026, 10, 1, 8);

  Anomaly anomaly(
    String id, {
    String? setId = 's2',
    String status = 'pending',
    String reason = 'outlier_weight',
    DateTime? detectedAt,
  }) {
    return Anomaly.fromJson({
      'id': id,
      'workoutId': 'w1',
      'workoutStart': start.toIso8601String(),
      'setId': ?setId,
      'exerciseId': bench.id,
      'exerciseName': bench.name,
      'reason': reason,
      'observed': {'weight': 630, 'reps': 5},
      'typical': 100,
      'status': status,
      'detectedAt': (detectedAt ?? DateTime.utc(2026, 10, 2, 3, 37)).toIso8601String(),
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.insert('exercises', {'id': bench.id, 'name': bench.name, 'category': 'Barbell', 'target': 'Chest'});
    await db.insert('workouts', {
      'id': 'w1',
      'start': start.toIso8601String(),
      'end': start.add(const Duration(hours: 1)).toIso8601String(),
      'user_id': userId,
    });
    await db.insert('workout_exercises', {'id': 'we1', 'workout_id': 'w1', 'exercise_id': bench.id});
    // a working set, and the same set with a pound slip in it
    await db.insert('sets', {'id': 's1', 'exercise_id': 'we1', 'completed': 1, 'weight': 100, 'reps': 5});
    await db.insert('sets', {'id': 's2', 'exercise_id': 'we1', 'completed': 1, 'weight': 630, 'reps': 5});
  });

  tearDown(() => db.close());

  test('an anomaly comes back as it was stored', () async {
    await local.storeAnomalies([anomaly('a1')], userId);

    final [read] = await local.getAnomalies(userId);

    expect(read.toMap(), anomaly('a1').toMap());
  });

  test('a decision is unsynced until the server answers it', () async {
    await local.storeAnomalies([anomaly('a1')], userId);
    await local.resolveAnomaly('a1', .invalid, at: DateTime.utc(2026, 10, 3));

    final [owed] = await local.unsyncedAnomalies(userId);
    expect((owed.status, owed.resolvedAt), (AnomalyStatus.invalid, DateTime.utc(2026, 10, 3)));

    await local.storeAnomaly(anomaly('a1', status: 'invalid'), userId);
    expect(await local.unsyncedAnomalies(userId), isEmpty);
  });

  test('a read from the server keeps a decision it has not heard yet, unless the question is new', () async {
    await local.storeAnomalies([anomaly('a1'), anomaly('a2', setId: 's1')], userId);
    await local.resolveAnomaly('a1', .valid, at: DateTime.utc(2026, 10, 3));
    await local.resolveAnomaly('a2', .invalid, at: DateTime.utc(2026, 10, 3));

    // a2 was edited and is still odd: found again, so asked again
    await local.storeAnomalies([
      anomaly('a1'),
      anomaly('a2', setId: 's1', detectedAt: DateTime.utc(2026, 10, 4)),
    ], userId);

    final read = {for (final each in await local.getAnomalies(userId)) each.id: each.status};
    expect(read, {'a1': AnomalyStatus.valid, 'a2': AnomalyStatus.pending});
    expect((await local.unsyncedAnomalies(userId)).map((each) => each.id), ['a1']);
  });

  test('an anomaly the server no longer has is gone from the mirror', () async {
    await local.storeAnomalies([anomaly('a1')], userId);
    await local.resolveAnomaly('a1', .invalid, at: DateTime.utc(2026, 10, 3));

    await local.storeAnomalies(const [], userId);

    expect(await local.getAnomalies(userId), isEmpty);
  });

  group('a discarded set', () {
    setUp(() => local.storeAnomalies([anomaly('a1', status: 'invalid')], userId));

    Future<Object?> heaviest() async {
      return switch (await local.getRecord(userId, bench)) {
        {'heaviest': {'weight': final Object? weight}} => weight,
        _ => null,
      };
    }

    test('still counts while the feature is off', () async {
      local.leavesOutDiscarded = false;

      expect(await heaviest(), 630);
      expect((await local.getWeightHistory(userId, bench)).map((each) => each.$1), [630]);
      final [row] = await local.getMuscleSets(start, start.add(const Duration(days: 1)), userId: userId);
      expect(row.sets, 2);
    });

    test('drops out of records, charts and the muscle map while it is on', () async {
      local.leavesOutDiscarded = true;

      expect(await heaviest(), 100);
      expect((await local.getWeightHistory(userId, bench)).map((each) => each.$1), [100]);
      expect(
        (await local.getExerciseMetics(userId, .topSetWeight, bench.id))?.map((each) => each.$1),
        [100],
      );
      final [muscles] = await local.getMuscleSets(start, start.add(const Duration(days: 1)), userId: userId);
      expect(muscles.sets, 1);
      final [lens] = await local.getLensSets(start, start.add(const Duration(days: 1)), userId: userId);
      expect(lens.sets, 1);
    });

    test('drops out of a recap, the training charts and the last-record read while it is on', () async {
      final window = (start, start.add(const Duration(days: 1)));
      Future<(int, double, Object?)> counts() async {
        final recap = await local.getRecapSets(window.$1, window.$2, userId: userId);
        final [totals] = await local.getTrainingTotals(window.$1, window.$2, userId: userId);
        final heaviest = switch (await local.getRecordWithout(userId, bench, 'none')) {
          {'heaviest': {'weight': final Object? weight}} => weight,
          _ => null,
        };
        return (recap.length, totals.volume, heaviest);
      }

      local.leavesOutDiscarded = false;
      final (allSets, allVolume, allHeaviest) = await counts();
      expect(allSets, 2);
      expect(allVolume, 100 * 5 + 630 * 5);
      expect(allHeaviest, 630);

      local.leavesOutDiscarded = true;
      final (sets, volume, heaviest) = await counts();
      expect(sets, 1);
      expect(volume, 100 * 5);
      expect(heaviest, 100);
    });

    test('stays in the log', () async {
      local.leavesOutDiscarded = true;

      final act = (await local.getExerciseHistory(userId, bench)).single;
      expect(act.map((set) => set.weight), unorderedEquals([100, 630]));
    });

    test('a pending or kept one counts either way', () async {
      local.leavesOutDiscarded = true;
      await local.storeAnomalies([anomaly('a1', status: 'valid')], userId);
      expect(await heaviest(), 630);

      await local.storeAnomalies([anomaly('a1')], userId);
      expect(await heaviest(), 630);
    });
  });

  group('a discarded duration', () {
    final window = (start, start.add(const Duration(days: 1)));

    setUp(
      () => local.storeAnomalies([
        anomaly('a1', setId: null, status: 'invalid', reason: 'duration_left_running'),
      ], userId),
    );

    test('keeps its time while the feature is off', () async {
      local.leavesOutDiscarded = false;

      final [recap] = await local.getRecapWorkouts(window.$1, window.$2, userId: userId);
      expect(recap.trained, const Duration(hours: 1));
      final [totals] = await local.getTrainingTotals(window.$1, window.$2, userId: userId);
      expect(totals.duration, const Duration(hours: 1));
    });

    test('takes only the time while it is on: the workout and its sets still count', () async {
      local.leavesOutDiscarded = true;

      final [recap] = await local.getRecapWorkouts(window.$1, window.$2, userId: userId);
      expect(recap.trained, Duration.zero);
      final [totals] = await local.getTrainingTotals(window.$1, window.$2, userId: userId);
      expect(totals.duration, Duration.zero);
      expect(totals.sets, 2);
    });
  });

  test('erasing the user takes their anomalies, and only theirs', () async {
    await local.storeAnomalies([anomaly('a1')], userId);
    await local.storeAnomalies([anomaly('a2')], 'someone-else');

    await local.eraseUser(userId);

    expect(await local.getAnomalies(userId), isEmpty);
    expect(await local.getAnomalies('someone-else'), hasLength(1));
  });
}
