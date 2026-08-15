import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart' as plugin;
import 'package:logging/logging.dart';

// `store.dart`'s conditional export resolves to the stub for static analysis,
// so `DeviceHealthStore` and the real `healthStore()` are only visible by
// importing the `dart:io` implementation directly. Tests run on the VM, where
// that is the branch the app gets.
import 'package:heart_health/heart_health.dart' hide healthStore;
import 'package:heart_health/src/device.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

plugin.HealthDataPoint _point({
  required plugin.HealthDataType type,
  required plugin.HealthValue value,
  required plugin.HealthDataUnit unit,
  String uuid = 'uuid-1',
  String sourceName = 'Health',
  String sourceId = 'com.apple.health',
  String? deviceModel,
  plugin.RecordingMethod recordingMethod = plugin.RecordingMethod.automatic,
  DateTime? from,
  DateTime? to,
}) {
  return plugin.HealthDataPoint(
    uuid: uuid,
    value: value,
    type: type,
    unit: unit,
    dateFrom: from ?? DateTime.utc(2026, 8, 1, 7),
    dateTo: to ?? DateTime.utc(2026, 8, 1, 8),
    sourcePlatform: plugin.HealthPlatformType.appleHealth,
    sourceDeviceId: 'device-1',
    sourceId: sourceId,
    sourceName: sourceName,
    recordingMethod: recordingMethod,
    deviceModel: deviceModel,
  );
}

void main() {
  group('HealthMetric', () {
    for (final metric in HealthMetric.values) {
      test('every value round-trips through fromString', () {
        expect(HealthMetric.fromString(metric.value), metric);
      });
    }

    test('an unknown value throws rather than degrading', () {
      expect(() => HealthMetric.fromString('bloodPressure'), throwsArgumentError);
    });

    for (final unit in HealthUnit.values) {
      test('every unit round-trips through fromString', () {
        expect(HealthUnit.fromString(unit.value), unit);
      });
    }

    // The distinction that keeps a chart from multiplying the user's step
    // count: cumulative metrics accumulate over their window, so overlapping
    // sources must be picked between rather than added.
    test('accumulating metrics are cumulative, point readings are not', () {
      expect(HealthMetric.steps.isCumulative, isTrue);
      expect(HealthMetric.activeEnergy.isCumulative, isTrue);
      expect(HealthMetric.sleepAsleep.isCumulative, isTrue);

      expect(HealthMetric.bodyMass.isCumulative, isFalse);
      expect(HealthMetric.restingHeartRate.isCumulative, isFalse);
      expect(HealthMetric.heartRateVariability.isCumulative, isFalse);
    });

    test('only HRV is platform-dependent', () {
      final dependent = HealthMetric.values.where((m) => m.isPlatformDependent);
      expect(dependent, [HealthMetric.heartRateVariability]);
    });
  });

  group('HealthSample', () {
    final sample = HealthSample(
      id: 'uuid-1',
      metric: HealthMetric.bodyMass,
      value: 82.5,
      start: DateTime.utc(2026, 8, 1, 7),
      end: DateTime.utc(2026, 8, 1, 7),
      source: const HealthSource(id: 'com.apple.health', name: 'Health', deviceModel: 'iPhone'),
      isManual: true,
    );

    test('round-trips through a row', () {
      final restored = HealthSample.fromRow(sample.toRow());

      expect(restored.id, sample.id);
      expect(restored.metric, sample.metric);
      expect(restored.value, sample.value);
      expect(restored.start, sample.start);
      expect(restored.end, sample.end);
      expect(restored.source.id, sample.source.id);
      expect(restored.source.name, sample.source.name);
      expect(restored.source.deviceModel, sample.source.deviceModel);
      expect(restored.isManual, isTrue);
    });

    // heart_db spreads toRow() straight into an insert, so a key that is not a
    // column breaks writes at runtime rather than at compile time. This test is
    // the tripwire for that — it must be updated in lockstep with migration 0006.
    test('emits exactly the columns of health_samples', () {
      expect(
        sample.toRow().keys.toSet(),
        {'id', 'metric', 'value', 'unit', 'start', 'end', 'source_id', 'source_name', 'device_model', 'is_manual'},
      );
    });

    test('stores the unit of its metric, not a free choice', () {
      expect(sample.toRow()['unit'], 'kg');
    });
  });

  group('UnsupportedHealthStore', () {
    const store = UnsupportedHealthStore();

    test('reads nothing and claims nothing', () async {
      expect(store.isSupported, isFalse);
      expect(await store.status(), HealthStoreStatus.unavailable);
      expect(await store.access({HealthMetric.steps}), HealthAccess.denied);
      expect(await store.requestAccess({HealthMetric.steps}), isFalse);
      expect(
        await store.read(metrics: {HealthMetric.steps}, from: DateTime.utc(2026), to: DateTime.utc(2027)),
        isEmpty,
      );
    });
  });

  group('DeviceHealthStore', () {
    late MockHealth health;
    late DeviceHealthStore store;

    setUp(() {
      health = MockHealth();
      store = DeviceHealthStore(health: health);
      when(health.configure()).thenAnswer((_) async {});
      when(health.isDataTypeAvailable(any)).thenReturn(true);
      when(health.getHealthConnectSdkStatus()).thenAnswer((_) async => plugin.HealthConnectSdkStatus.sdkAvailable);
    });

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<List<HealthSample>> readReturning(List<plugin.HealthDataPoint> points) {
      when(
        health.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        ),
      ).thenAnswer((_) async => points);

      return store.read(
        metrics: {HealthMetric.bodyMass, HealthMetric.steps, HealthMetric.heartRateVariability},
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      );
    }

    test('maps a point into a sample, keeping its source', () async {
      final samples = await readReturning([
        _point(
          type: plugin.HealthDataType.WEIGHT,
          value: plugin.NumericHealthValue(numericValue: 82.5),
          unit: plugin.HealthDataUnit.KILOGRAM,
          sourceName: 'Garmin Connect',
          sourceId: 'com.garmin.connect.mobile',
          deviceModel: 'Apple Watch',
        ),
      ]);

      expect(samples, hasLength(1));
      final [sample] = samples;
      expect(sample.metric, HealthMetric.bodyMass);
      expect(sample.value, 82.5);
      expect(sample.id, 'uuid-1');
      expect(sample.source.name, 'Garmin Connect');
      expect(sample.source.deviceModel, 'Apple Watch');
      expect(sample.isManual, isFalse);
    });

    test('flags a hand-entered reading', () async {
      final samples = await readReturning([
        _point(
          type: plugin.HealthDataType.WEIGHT,
          value: plugin.NumericHealthValue(numericValue: 80),
          unit: plugin.HealthDataUnit.KILOGRAM,
          recordingMethod: plugin.RecordingMethod.manual,
        ),
      ]);

      expect(samples.single.isManual, isTrue);
    });

    // Both platforms' HRV flavours collapse into one metric — which is exactly
    // why that metric is flagged platform-dependent rather than silently mixed.
    test('SDNN and RMSSD both land on heartRateVariability', () async {
      final samples = await readReturning([
        _point(
          uuid: 'sdnn',
          type: plugin.HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          value: plugin.NumericHealthValue(numericValue: 45),
          unit: plugin.HealthDataUnit.MILLISECOND,
        ),
        _point(
          uuid: 'rmssd',
          type: plugin.HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          value: plugin.NumericHealthValue(numericValue: 30),
          unit: plugin.HealthDataUnit.MILLISECOND,
        ),
      ]);

      expect(samples.map((s) => s.metric), everyElement(HealthMetric.heartRateVariability));
    });

    // A unit we did not expect means the plugin changed its defaults under us.
    // Dropping the sample keeps a wrong number off a chart; the alternative is
    // plotting grams as kilograms.
    test('drops a sample whose unit is not the one the metric stores', () async {
      final samples = await readReturning([
        _point(
          type: plugin.HealthDataType.WEIGHT,
          value: plugin.NumericHealthValue(numericValue: 82500),
          unit: plugin.HealthDataUnit.GRAM,
        ),
      ]);

      expect(samples, isEmpty);
    });

    test('skips a point whose value is not numeric', () async {
      final samples = await readReturning([
        _point(
          type: plugin.HealthDataType.WEIGHT,
          value: plugin.WorkoutHealthValue(workoutActivityType: plugin.HealthWorkoutActivityType.OTHER),
          unit: plugin.HealthDataUnit.KILOGRAM,
        ),
      ]);

      expect(samples, isEmpty);
    });

    test('skips a type we do not model', () async {
      final samples = await readReturning([
        _point(
          type: plugin.HealthDataType.BLOOD_GLUCOSE,
          value: plugin.NumericHealthValue(numericValue: 5),
          unit: plugin.HealthDataUnit.MILLIGRAM_PER_DECILITER,
        ),
      ]);

      expect(samples, isEmpty);
    });

    // A refusal is a normal state, not an error — and the empty result is
    // indistinguishable from "nothing recorded", which is the honest answer.
    test('returns empty when the platform throws', () async {
      when(
        health.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        ),
      ).thenThrow(Exception('not authorized'));

      final samples = await store.read(
        metrics: {HealthMetric.steps},
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      );

      expect(samples, isEmpty);
    });

    test('does not ask for a type the platform lacks', () async {
      when(health.isDataTypeAvailable(any)).thenReturn(false);
      when(
        health.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        ),
      ).thenAnswer((_) async => []);

      final samples = await store.read(
        metrics: {HealthMetric.steps},
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      );

      expect(samples, isEmpty);
      verifyNever(
        health.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        ),
      );
    });

    /// Captures everything logged while [action] runs.
    Future<List<LogRecord>> logsFrom(Future<void> Function() action) async {
      final records = <LogRecord>[];
      final previous = Logger.root.level;
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(records.add);

      await action();

      await subscription.cancel();
      Logger.root.level = previous;
      return records;
    }

    Future<void> readFailingWith(Object error) async {
      when(health.isDataTypeAvailable(any)).thenReturn(true);
      when(
        health.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        ),
      ).thenAnswer((_) async => throw error);

      final samples = await store.read(
        metrics: {HealthMetric.steps},
        from: DateTime.utc(2026, 8),
        to: DateTime.utc(2026, 9),
      );
      expect(samples, isEmpty);
    }

    // On iOS this is what a launch looks like before anyone has been asked, and
    // what it keeps looking like if they decline. Six of them at WARNING on
    // every cold start is us reporting the ordinary case as a fault.
    test('an unauthorized read is not a warning', () async {
      final records = await logsFrom(
        () => readFailingWith(
          PlatformException(
            code: 'HEALTH_ERROR',
            message: 'Error getting health data: Authorization not determined',
          ),
        ),
      );

      expect(records.where((each) => each.level >= Level.WARNING), isEmpty);
      expect(records, isNotEmpty, reason: 'still worth a trace when chasing why nothing arrived');
    });

    test('anything else still is', () async {
      final records = await logsFrom(
        () => readFailingWith(
          PlatformException(code: 'HEALTH_ERROR', message: 'the store fell over'),
        ),
      );

      expect(records.where((each) => each.level >= Level.WARNING), isNotEmpty);
    });

    // The whole point of HealthAccess.unknown: HealthKit will not disclose read
    // permission, and reporting that as "denied" would put a reconnect button in
    // front of users who granted everything.
    test('an undisclosed permission is unknown, not denied', () async {
      when(health.hasPermissions(any)).thenAnswer((_) async => null);

      expect(await store.access({HealthMetric.steps}), HealthAccess.unknown);
    });

    test('a disclosed permission is reported as given', () async {
      when(health.hasPermissions(any)).thenAnswer((_) async => true);

      expect(await store.access({HealthMetric.steps}), HealthAccess.granted);
    });

    test('a failed authorization is a false, not a throw', () async {
      when(
        health.requestAuthorization(any, permissions: anyNamed('permissions')),
      ).thenThrow(Exception('nope'));

      expect(await store.requestAccess({HealthMetric.steps}), isFalse);
    });

    // Left to the plugin's default this is READ_WRITE, and iOS then asks to
    // "access and update your Health data" — write access we have no code to
    // use. Tier 1 widens it deliberately; until then, asking for it is both
    // over-reach and a bad look on a feature selling restraint.
    test('asks only to read', () async {
      when(health.isDataTypeAvailable(any)).thenReturn(true);
      when(
        health.requestAuthorization(any, permissions: anyNamed('permissions')),
      ).thenAnswer((_) async => true);

      await store.requestAccess({HealthMetric.steps, HealthMetric.bodyMass});

      final captured = verify(
        health.requestAuthorization(captureAny, permissions: captureAnyNamed('permissions')),
      ).captured;
      final types = captured[0] as List<plugin.HealthDataType>;
      final permissions = captured[1] as List<plugin.HealthDataAccess>;

      expect(permissions, everyElement(plugin.HealthDataAccess.READ));
      expect(permissions, hasLength(types.length), reason: 'the plugin throws when the lengths differ');
    });

    test('configures once, however many calls', () async {
      when(health.hasPermissions(any)).thenAnswer((_) async => true);

      await store.access({HealthMetric.steps});
      await store.access({HealthMetric.bodyMass});
      await store.status();

      verify(health.configure()).called(1);
    });

    // iOS has no equivalent of the Health Connect availability check — HealthKit
    // is simply there — so asking the plugin at all would be a wasted channel hop.
    test('iOS is available without consulting Health Connect', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(await store.status(), HealthStoreStatus.available);
      verifyNever(health.getHealthConnectSdkStatus());
    });

    test('a missing Health Connect is unavailable, not an error', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(health.getHealthConnectSdkStatus()).thenAnswer((_) async => plugin.HealthConnectSdkStatus.sdkUnavailable);

      expect(await store.status(), HealthStoreStatus.unavailable);
    });

    // Distinct from unavailable because the fix differs: an update is a nudge,
    // an install is a trip to the Play Store.
    test('an outdated Health Connect asks for an update', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(health.getHealthConnectSdkStatus()).thenAnswer(
        (_) async => plugin.HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
      );

      expect(await store.status(), HealthStoreStatus.needsUpdate);
    });

    test('the installer is an Android-only trip', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await store.openInstaller();
      verifyNever(health.installHealthConnect());

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(health.installHealthConnect()).thenAnswer((_) async {});
      await store.openInstaller();
      verify(health.installHealthConnect()).called(1);
    });
  });

  group('healthStore()', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('gives a real store on a phone', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(healthStore(), isA<DeviceHealthStore>());
    });

    test('degrades on a platform with no health store', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(healthStore(), isA<UnsupportedHealthStore>());
    });
  });
}
