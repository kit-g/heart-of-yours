import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_health/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Against a real in-memory SQLite, not a mock.
///
/// The reconciliation in `getDailyHealth` *is* the logic — stubbing `rawQuery`
/// would assert that we pass the string we pass. The multi-source case below is
/// the one that keeps a chart from inventing steps the user never took.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const other = 'user-2';

  HealthSample sample({
    required String id,
    required HealthMetric metric,
    required double value,
    required DateTime start,
    String sourceId = 'com.apple.health',
    String sourceName = 'Health',
    String? deviceModel,
    bool isManual = false,
  }) {
    return HealthSample(
      id: id,
      metric: metric,
      value: value,
      start: start,
      end: start,
      source: HealthSource(id: sourceId, name: sourceName, deviceModel: deviceModel),
      isManual: isManual,
    );
  }

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // The real DDL, so a change to the migration breaks this test rather than
    // sailing past a hand-written copy of the schema.
    await db.execute(healthSamples);
    await db.execute(healthSamplesIndex);
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  group('storing', () {
    test('round-trips a sample with its source', () async {
      await local.storeHealthSamples([
        sample(
          id: 'a',
          metric: HealthMetric.bodyMass,
          value: 82.5,
          start: DateTime.utc(2026, 8, 1, 12),
          sourceId: 'com.garmin.connect.mobile',
          sourceName: 'Garmin Connect',
          deviceModel: 'Apple Watch',
          isManual: true,
        ),
      ], userId);

      final [stored] = await local.getHealthSamples(
        userId: userId,
        metric: HealthMetric.bodyMass,
        from: DateTime.utc(2026, 7),
        to: DateTime.utc(2026, 9),
      );

      expect(stored.id, 'a');
      expect(stored.value, 82.5);
      expect(stored.source.name, 'Garmin Connect');
      expect(stored.source.deviceModel, 'Apple Watch');
      expect(stored.isManual, isTrue);
      expect(stored.start, DateTime.utc(2026, 8, 1, 12));
    });

    // Re-reading an overlapping window is the normal sync path, so it has to be
    // free rather than duplicating every sample in the overlap.
    test('re-importing the same sample replaces rather than duplicates', () async {
      final first = sample(id: 'a', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12));
      final corrected = sample(id: 'a', metric: HealthMetric.steps, value: 150, start: DateTime.utc(2026, 8, 1, 12));

      await local.storeHealthSamples([first], userId);
      await local.storeHealthSamples([corrected], userId);

      final stored = await local.getHealthSamples(
        userId: userId,
        metric: HealthMetric.steps,
        from: DateTime.utc(2026, 7),
        to: DateTime.utc(2026, 9),
      );

      expect(stored, hasLength(1));
      expect(stored.single.value, 150);
    });

    test('storing nothing touches nothing', () async {
      await local.storeHealthSamples([], userId);

      expect(
        await local.getHealthSamples(
          userId: userId,
          metric: HealthMetric.steps,
          from: DateTime.utc(2026, 7),
          to: DateTime.utc(2026, 9),
        ),
        isEmpty,
      );
    });

    test('one user cannot see another', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12)),
      ], other);

      expect(
        await local.getHealthSamples(
          userId: userId,
          metric: HealthMetric.steps,
          from: DateTime.utc(2026, 7),
          to: DateTime.utc(2026, 9),
        ),
        isEmpty,
      );
    });
  });

  group('reading a window', () {
    test('excludes samples outside it and orders oldest first', () async {
      await local.storeHealthSamples([
        sample(id: 'before', metric: HealthMetric.steps, value: 1, start: DateTime.utc(2026, 6, 1, 12)),
        sample(id: 'late', metric: HealthMetric.steps, value: 3, start: DateTime.utc(2026, 8, 20, 12)),
        sample(id: 'early', metric: HealthMetric.steps, value: 2, start: DateTime.utc(2026, 8, 2, 12)),
        sample(id: 'after', metric: HealthMetric.steps, value: 4, start: DateTime.utc(2026, 10, 1, 12)),
      ], userId);

      final stored = await local.getHealthSamples(
        userId: userId,
        metric: HealthMetric.steps,
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      );

      expect(stored.map((s) => s.id), ['early', 'late']);
    });

    test('does not mix metrics', () async {
      await local.storeHealthSamples([
        sample(id: 'steps', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12)),
        sample(id: 'mass', metric: HealthMetric.bodyMass, value: 82, start: DateTime.utc(2026, 8, 1, 12)),
      ], userId);

      final stored = await local.getHealthSamples(
        userId: userId,
        metric: HealthMetric.steps,
        from: DateTime.utc(2026, 7),
        to: DateTime.utc(2026, 9),
      );

      expect(stored.single.id, 'steps');
    });
  });

  group('the sync watermark', () {
    test('is null before anything is stored', () async {
      expect(await local.lastHealthSampleAt(userId: userId, metric: HealthMetric.steps), isNull);
    });

    test('is the newest sample of that metric', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.steps, value: 1, start: DateTime.utc(2026, 8, 1, 12)),
        sample(id: 'b', metric: HealthMetric.steps, value: 2, start: DateTime.utc(2026, 8, 9, 12)),
        sample(id: 'c', metric: HealthMetric.steps, value: 3, start: DateTime.utc(2026, 8, 5, 12)),
      ], userId);

      expect(
        await local.lastHealthSampleAt(userId: userId, metric: HealthMetric.steps),
        DateTime.utc(2026, 8, 9, 12),
      );
    });

    // Per metric, because they arrive at wildly different rates — steps every
    // few minutes, body mass when the user remembers to stand on a scale.
    test('is tracked per metric, not per user', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.steps, value: 1, start: DateTime.utc(2026, 8, 9, 12)),
        sample(id: 'b', metric: HealthMetric.bodyMass, value: 82, start: DateTime.utc(2026, 8, 1, 12)),
      ], userId);

      expect(
        await local.lastHealthSampleAt(userId: userId, metric: HealthMetric.bodyMass),
        DateTime.utc(2026, 8, 1, 12),
      );
    });
  });

  group('daily rollup', () {
    Future<List<HealthDailyValue>> daily(HealthMetric metric) {
      return local.getDailyHealth(
        userId: userId,
        metric: metric,
        from: DateTime.utc(2026, 7),
        to: DateTime.utc(2026, 9),
      );
    }

    // The one that matters. Phone and watch both report the same day's steps as
    // distinct samples; summing them would hand the user 900 steps they never
    // took. The best-covered source wins instead.
    test('a cumulative metric takes the best source, never the sum', () async {
      await local.storeHealthSamples([
        sample(
          id: 'p1',
          metric: HealthMetric.steps,
          value: 200,
          start: DateTime.utc(2026, 8, 1, 10),
          sourceId: 'phone',
        ),
        sample(
          id: 'p2',
          metric: HealthMetric.steps,
          value: 200,
          start: DateTime.utc(2026, 8, 1, 12),
          sourceId: 'phone',
        ),
        sample(
          id: 'w1',
          metric: HealthMetric.steps,
          value: 250,
          start: DateTime.utc(2026, 8, 1, 10),
          sourceId: 'watch',
        ),
        sample(
          id: 'w2',
          metric: HealthMetric.steps,
          value: 250,
          start: DateTime.utc(2026, 8, 1, 12),
          sourceId: 'watch',
        ),
      ], userId);

      final [day] = await daily(HealthMetric.steps);

      expect(day.value, 500, reason: 'the watch total, not the 900 of both summed');
    });

    test('a cumulative metric still sums within one source', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.steps, value: 120, start: DateTime.utc(2026, 8, 1, 10), sourceId: 'watch'),
        sample(id: 'b', metric: HealthMetric.steps, value: 80, start: DateTime.utc(2026, 8, 1, 12), sourceId: 'watch'),
      ], userId);

      final [day] = await daily(HealthMetric.steps);

      expect(day.value, 200);
    });

    test('an instantaneous metric averages its readings', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.restingHeartRate, value: 50, start: DateTime.utc(2026, 8, 1, 10)),
        sample(id: 'b', metric: HealthMetric.restingHeartRate, value: 60, start: DateTime.utc(2026, 8, 1, 12)),
      ], userId);

      final [day] = await daily(HealthMetric.restingHeartRate);

      expect(day.value, 55);
    });

    // Two opinions of one morning's number average to a fair summary; nothing
    // accumulates, so multiple sources are not a hazard here.
    test('an instantaneous metric averages across sources too', () async {
      await local.storeHealthSamples([
        sample(id: 'a', metric: HealthMetric.bodyMass, value: 80, start: DateTime.utc(2026, 8, 1, 10), sourceId: 'x'),
        sample(id: 'b', metric: HealthMetric.bodyMass, value: 84, start: DateTime.utc(2026, 8, 1, 12), sourceId: 'y'),
      ], userId);

      final [day] = await daily(HealthMetric.bodyMass);

      expect(day.value, 82);
    });

    test('separate days stay separate, in order', () async {
      await local.storeHealthSamples([
        sample(id: 'b', metric: HealthMetric.steps, value: 300, start: DateTime.utc(2026, 8, 2, 12)),
        sample(id: 'a', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12)),
      ], userId);

      final days = await daily(HealthMetric.steps);

      expect(days.map((d) => d.value), [100, 300]);
      expect(days.first.day.isBefore(days.last.day), isTrue);
    });

    test('is empty when there is nothing to roll up', () async {
      expect(await daily(HealthMetric.steps), isEmpty);
    });
  });

  group('forgetting', () {
    test('erases one user and leaves the other alone', () async {
      await local.storeHealthSamples([
        sample(id: 'mine', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12)),
      ], userId);
      await local.storeHealthSamples([
        sample(id: 'theirs', metric: HealthMetric.steps, value: 100, start: DateTime.utc(2026, 8, 1, 12)),
      ], other);

      await local.deleteHealthSamples(userId);

      Future<List<HealthSample>> forUser(String id) {
        return local.getHealthSamples(
          userId: id,
          metric: HealthMetric.steps,
          from: DateTime.utc(2026, 7),
          to: DateTime.utc(2026, 9),
        );
      }

      expect(await forUser(userId), isEmpty);
      expect(await forUser(other), hasLength(1));
    });
  });
}
