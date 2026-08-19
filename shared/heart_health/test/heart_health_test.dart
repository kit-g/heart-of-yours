import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
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
  TestWidgetsFlutterBinding.ensureInitialized();

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
    // The permission ask is the whole promise the feature makes about itself:
    // Heart reads the body's data and writes back only the session it watched
    // the user do. A metric quietly acquiring WRITE here is the regression this
    // group exists to catch.
    ({List<plugin.HealthDataType> types, List<plugin.HealthDataAccess> permissions}) requestedAccess() {
      final captured = verify(
        health.requestAuthorization(captureAny, permissions: captureAnyNamed('permissions')),
      ).captured;
      return (
        types: captured[0] as List<plugin.HealthDataType>,
        permissions: captured[1] as List<plugin.HealthDataAccess>,
      );
    }

    test('asks to read every metric and to write nothing but the workout', () async {
      when(health.isDataTypeAvailable(any)).thenReturn(true);
      when(
        health.requestAuthorization(any, permissions: anyNamed('permissions')),
      ).thenAnswer((_) async => true);

      await store.requestAccess({HealthMetric.steps, HealthMetric.bodyMass});

      final (:types, :permissions) = requestedAccess();

      expect(permissions, hasLength(types.length), reason: 'the plugin throws when the lengths differ');

      final asked = Map.fromIterables(types, permissions);
      expect(asked[plugin.HealthDataType.STEPS], plugin.HealthDataAccess.READ);
      expect(asked[plugin.HealthDataType.WEIGHT], plugin.HealthDataAccess.READ);
      expect(asked[plugin.HealthDataType.WORKOUT], plugin.HealthDataAccess.WRITE);

      // The one that matters: nothing about the user's body is writable.
      expect(
        asked.entries.where((e) => e.value != plugin.HealthDataAccess.READ).map((e) => e.key),
        [plugin.HealthDataType.WORKOUT],
      );
    });

    test('skips the workout type where the platform has none', () async {
      when(health.isDataTypeAvailable(any)).thenReturn(true);
      when(health.isDataTypeAvailable(plugin.HealthDataType.WORKOUT)).thenReturn(false);
      when(
        health.requestAuthorization(any, permissions: anyNamed('permissions')),
      ).thenAnswer((_) async => true);

      await store.requestAccess({HealthMetric.steps});

      final (:types, :permissions) = requestedAccess();

      expect(types, isNot(contains(plugin.HealthDataType.WORKOUT)));
      expect(permissions, everyElement(plugin.HealthDataAccess.READ));
      expect(permissions, hasLength(types.length));
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

    // The bug this whole method exists to prevent: the app used to offer "open
    // settings" and land the user on Settings › Heart, which lists cellular
    // data, Siri and search and nothing about health. HealthKit permissions are
    // in the Health app or nowhere.
    group('writeWorkout', () {
      Future<bool> write({
        WorkoutActivity activity = WorkoutActivity.strength,
        DateTime? start,
        DateTime? end,
        String? title,
      }) {
        return store.writeWorkout(
          activity: activity,
          start: start ?? DateTime.utc(2026, 8, 17, 18),
          end: end ?? DateTime.utc(2026, 8, 17, 19, 12),
          title: title,
        );
      }

      void stubWrite({bool accepted = true}) {
        when(
          health.writeWorkoutData(
            activityType: anyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: anyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: anyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: anyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        ).thenAnswer((_) async => accepted);
      }

      // Every activity, on both platforms, pinned to the exact value the store
      // accepts. This table is the guard on the trap that makes this mapping
      // necessary at all: the plugin throws `HealthException` for an activity
      // the platform does not know rather than degrading, so a wrong entry is
      // a crash the moment a user finishes that kind of session.
      //
      // The platform columns were derived from the plugin's own `_isOnIOS` and
      // `_isOnAndroid` lists (`health_plugin.dart`), which is where to re-check
      // them after a dependency bump. They cannot be asserted against here —
      // the plugin gates on `dart:io`'s `Platform`, which is neither iOS nor
      // Android under `flutter test`, so its validation never runs.
      const expected = <WorkoutActivity, (plugin.HealthWorkoutActivityType, plugin.HealthWorkoutActivityType)>{
        // activity: (iOS, Android)
        .strength: (.TRADITIONAL_STRENGTH_TRAINING, .STRENGTH_TRAINING),
        .crossTraining: (.CROSS_TRAINING, .OTHER),
        .mixedCardio: (.MIXED_CARDIO, .OTHER),
        .cycling: (.BIKING, .BIKING),
        .cyclingIndoor: (.BIKING, .BIKING_STATIONARY),
        .elliptical: (.ELLIPTICAL, .ELLIPTICAL),
        .hiking: (.HIKING, .HIKING),
        .rowing: (.ROWING, .ROWING_MACHINE),
        .running: (.RUNNING, .RUNNING),
        .runningTreadmill: (.RUNNING, .RUNNING_TREADMILL),
        .skating: (.SKATING, .SKATING),
        .skiing: (.DOWNHILL_SKIING, .DOWNHILL_SKIING),
        .snowboarding: (.SNOWBOARDING, .SNOWBOARDING),
        .swimming: (.SWIMMING, .SWIMMING_POOL),
        .walking: (.WALKING, .WALKING),
        .climbing: (.CLIMBING, .ROCK_CLIMBING),
        .coreTraining: (.CORE_TRAINING, .CALISTHENICS),
        .flexibility: (.FLEXIBILITY, .OTHER),
        .yoga: (.YOGA, .YOGA),
        .cardioDance: (.CARDIO_DANCE, .CARDIO_DANCE),
        .highIntensity: (.HIGH_INTENSITY_INTERVAL_TRAINING, .HIGH_INTENSITY_INTERVAL_TRAINING),
        // The enum declares JUMP_ROPE under a comment saying "Both". It is not:
        // only `_isOnAndroid` — the list that throws — settles it. Android takes
        // the nearest honest neighbour rather than `OTHER`, so a skipping
        // session still reads as conditioning.
        .jumpRope: (.JUMP_ROPE, .HIGH_INTENSITY_INTERVAL_TRAINING),
        .other: (.OTHER, .OTHER),
      };

      Future<plugin.HealthWorkoutActivityType> activityWritten(WorkoutActivity activity) async {
        await write(activity: activity);

        final captured = verify(
          health.writeWorkoutData(
            activityType: captureAnyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: anyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: anyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: anyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        ).captured;

        return captured.last as plugin.HealthWorkoutActivityType;
      }

      test('every activity has a value on iOS', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubWrite();

        for (final MapEntry(key: activity, value: (ios, _)) in expected.entries) {
          expect(await activityWritten(activity), ios, reason: '$activity on iOS');
        }
      });

      test('every activity has a value on Android', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        stubWrite();

        for (final MapEntry(key: activity, value: (_, android)) in expected.entries) {
          expect(await activityWritten(activity), android, reason: '$activity on Android');
        }
      });

      // A new activity with no entry above is a value nobody has checked either
      // platform accepts — which is exactly how the iOS-only ones got in.
      test('no activity is left unmapped', () {
        expect(expected.keys, containsAll(WorkoutActivity.values));
      });

      // The constraint the whole feature is built around: without a watch
      // session there is no measurement of energy, only an estimate from
      // bodyweight and duration, and a number Heart invented sitting next to
      // the Watch's own reading is worse than an absence. This test is the
      // guard on that, and it should outlive any refactor of the file.
      test('never reports energy, because there is none to report', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubWrite();

        await write();

        final captured = verify(
          health.writeWorkoutData(
            activityType: anyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: captureAnyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: captureAnyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: anyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        ).captured;

        expect(captured[0], isNull, reason: 'estimated calories are a fabrication');
        expect(captured[1], isNull, reason: 'lifting has no distance');
      });

      test('passes the session name through as the title', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubWrite();

        await write(title: 'Evening Workout');

        final captured = verify(
          health.writeWorkoutData(
            activityType: anyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: anyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: anyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: captureAnyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        ).captured;

        expect(captured.single, 'Evening Workout');
      });

      test('reports the store refusing it', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubWrite(accepted: false);

        expect(await write(), isFalse);
      });

      // A session with no elapsed time is not one the user did, and the store
      // rejects it anyway — better caught here than thrown across a channel.
      test('does not write a workout that did not elapse', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        stubWrite();

        final at = DateTime.utc(2026, 8, 17, 18);
        expect(await write(start: at, end: at), isFalse);
        expect(await write(start: at, end: at.subtract(const Duration(minutes: 1))), isFalse);

        verifyNever(
          health.writeWorkoutData(
            activityType: anyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: anyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: anyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: anyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        );
      });

      // Finishing a workout must not be able to fail because HealthKit did.
      test('a refused or broken write is a false, not a throw', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        when(
          health.writeWorkoutData(
            activityType: anyNamed('activityType'),
            start: anyNamed('start'),
            end: anyNamed('end'),
            totalEnergyBurned: anyNamed('totalEnergyBurned'),
            totalEnergyBurnedUnit: anyNamed('totalEnergyBurnedUnit'),
            totalDistance: anyNamed('totalDistance'),
            totalDistanceUnit: anyNamed('totalDistanceUnit'),
            title: anyNamed('title'),
            recordingMethod: anyNamed('recordingMethod'),
          ),
        ).thenThrow(PlatformException(code: 'HEALTH_ERROR', message: 'Authorization not determined'));

        expect(await write(), isFalse);
      });
    });

    group('openPermissions', () {
      final launched = <Uri>[];
      final invoked = <String>[];
      late DeviceHealthStore store;

      /// The host app's side of [healthPlatformChannel]. Absent in tests unless
      /// stubbed, which is itself the "Health Connect could not answer" case.
      void answerChannel({bool? opened}) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(healthPlatformChannel),
          (call) async {
            invoked.add(call.method);
            return opened;
          },
        );
      }

      setUp(() {
        launched.clear();
        invoked.clear();
        store = DeviceHealthStore(
          health: health,
          launch: (url) async {
            launched.add(url);
            return true;
          },
        );
      });

      tearDown(answerChannel);

      test('sends an iOS user to the Health app, not to the app settings', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        expect(await store.openPermissions(), isTrue);
        expect(launched, [Uri.parse('x-apple-health://')]);
      });

      // Health Connect's permission screen is an implicit intent, not a URL, so
      // it goes through the host app rather than through url_launcher.
      test('sends an Android user to Health Connect, through the host app', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answerChannel(opened: true);

        expect(await store.openPermissions(), isTrue);
        expect(invoked, ['openHealthConnectSettings']);
        expect(launched, isEmpty, reason: 'an intent is not a URL');
      });

      // Health Connect can be absent, or too old to answer the action at all.
      test('reports an Android device that could not get there', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answerChannel(opened: false);

        expect(await store.openPermissions(), isFalse);
      });

      test('has nowhere to send anyone off a phone', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

        expect(await store.openPermissions(), isFalse);
        expect(launched, isEmpty);
        expect(invoked, isEmpty);
      });

      // A simulator has no Health app, so this is the everyday path in testing
      // and must leave the caller with a fallback rather than an exception.
      test('reports a failure to open rather than throwing', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final failing = DeviceHealthStore(health: health, launch: (_) async => throw Exception('no such app'));

        expect(await failing.openPermissions(), isFalse);
      });
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
