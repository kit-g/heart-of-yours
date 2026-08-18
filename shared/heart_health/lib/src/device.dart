import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:health/health.dart' as plugin;
import 'package:heart_health/heart_health.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = Logger('Health');

/// Reads the device's health store through the `health` plugin, and writes
/// finished workouts back to it.
///
/// The plugin's vocabulary stops here: nothing outside this file mentions
/// `HealthDataType`, so swapping the plugin is a one-file change and the app's
/// state layer stays testable against [HealthService] alone.
class DeviceHealthStore implements HealthService {
  final plugin.Health _plugin;

  /// `configure()` is cheap but must run once before any query; this makes that
  /// the caller's non-problem.
  Future<void>? _configured;

  /// How [openPermissions] leaves the app. A seam only so tests can assert
  /// *where* it sends the user, which is the part that was wrong.
  final Future<bool> Function(Uri url) _launch;

  /// The host app's side of [healthPlatformChannel]. Android only.
  final MethodChannel _channel;

  new({plugin.Health? health, Future<bool> Function(Uri url)? launch, MethodChannel? channel})
    : _plugin = health ?? plugin.Health(),
      _launch = launch ?? launchUrl,
      _channel = channel ?? const MethodChannel(healthPlatformChannel);

  @override
  bool get isSupported => true;

  Future<void> _ensureConfigured() => _configured ??= _plugin.configure();

  @override
  Future<HealthStoreStatus> status() async {
    // Runs during app start-up, so it must not be able to take start-up down.
    // A missing plugin registration — an unbuilt platform, a stale pod, a
    // widget test — throws here and means exactly one thing to the user:
    // there is no health store. Say that instead of crashing.
    try {
      await _ensureConfigured();

      if (defaultTargetPlatform == .iOS) {
        return HealthStoreStatus.available;
      }

      return switch (await _plugin.getHealthConnectSdkStatus()) {
        plugin.HealthConnectSdkStatus.sdkAvailable => .available,
        plugin.HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => .needsUpdate,
        _ => .unavailable,
      };
    } catch (error, stacktrace) {
      _logger.warning('Health store unreachable', error, stacktrace);
      return .unavailable;
    }
  }

  @override
  Future<HealthAccess> access(Set<HealthMetric> metrics) async {
    await _ensureConfigured();
    final types = _typesFor(metrics);
    if (types.isEmpty) return .denied;

    // Null is the plugin's "the platform won't say", which is the standing iOS
    // answer for read access. Reporting it as denied would be a lie that puts a
    // "reconnect" button in front of users who granted everything.
    return switch (await _plugin.hasPermissions(types)) {
      true => .granted,
      false => .denied,
      null => .unknown,
    };
  }

  @override
  Future<bool> requestAccess(Set<HealthMetric> metrics) async {
    await _ensureConfigured();
    final types = _typesFor(metrics);
    if (types.isEmpty) return false;

    // Read, explicitly, for every metric. The plugin defaults to READ_WRITE when
    // `permissions` is omitted, which would make iOS ask to "access **and
    // update** your Health data" for all of it — write access we have no code
    // to use, on a feature whose entire pitch is restraint about the user's
    // body. So the two lists are built in step: one access per type, and the
    // only WRITE in it belongs to the workout.
    final permissions = List<plugin.HealthDataAccess>.filled(types.length, .READ, growable: true);

    if (_plugin.isDataTypeAvailable(_workoutType)) {
      types.add(_workoutType);
      permissions.add(.WRITE);
    }

    try {
      return await _plugin.requestAuthorization(types, permissions: permissions);
    } catch (error, stacktrace) {
      // Deliberately not reported upward: a permission failure is a normal
      // outcome, and the payload could name the health types being asked for.
      _logger.warning('Health authorization failed', error, stacktrace);
      return false;
    }
  }

  @override
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureConfigured();
    final types = _typesFor(metrics);
    if (types.isEmpty) return const [];

    try {
      final points = await _plugin.getHealthDataFromTypes(
        types: types,
        startTime: from,
        endTime: to,
      );
      return points.map(_toSample).nonNulls.toList();
    } catch (error, stacktrace) {
      // A refusal surfaces here as an exception on some platforms. Empty is the
      // honest answer either way — we cannot distinguish "declined" from
      // "nothing recorded", and the UI must not pretend otherwise.
      if (_isUnauthorized(error)) {
        // Not a failure: this is what every launch looks like before the user
        // has been asked, and what it keeps looking like if they say no. iOS
        // will not answer [access] honestly, so attempting the read *is* how we
        // find out — six of these at WARNING on a first run is us logging the
        // normal case as a fault.
        _logger.fine('Health read unauthorized', error);
        return const [];
      }

      _logger.warning('Health read failed', error, stacktrace);
      return const [];
    }
  }

  /// Whether [error] is the platform declining rather than something broken.
  ///
  /// Matched on the message because that is all either platform gives us —
  /// HealthKit raises a generic `HEALTH_ERROR` whose text is the only thing
  /// distinguishing "you never asked" from a genuine query failure. Narrow by
  /// design: anything unrecognised stays a warning.
  bool _isUnauthorized(Object error) {
    if (error is! PlatformException) return false;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('authorization not determined') || message.contains('not authorized');
  }

  @override
  Future<HealthAccess> workoutWriteAccess() async {
    await _ensureConfigured();
    if (!_plugin.isDataTypeAvailable(_workoutType)) return .denied;

    try {
      return switch (await _plugin.hasPermissions(
        [_workoutType],
        permissions: [.WRITE],
      )) {
        true => .granted,
        // Covers a refusal *and* never having asked — the bridge returns
        // `status == .sharingAuthorized`, so the two are one answer. See
        // [HealthService.workoutWriteAccess].
        false => .denied,
        // Reserved for reads on this platform; a write always answers.
        null => .unknown,
      };
    } catch (error, stacktrace) {
      _logger.warning('Could not read workout write access', error, stacktrace);
      return .denied;
    }
  }

  @override
  Future<bool> requestWorkoutWriteAccess() async {
    await _ensureConfigured();
    if (!_plugin.isDataTypeAvailable(_workoutType)) return false;

    try {
      return await _plugin.requestAuthorization(
        [_workoutType],
        permissions: [.WRITE],
      );
    } catch (error, stacktrace) {
      _logger.warning('Workout write authorization failed', error, stacktrace);
      return false;
    }
  }

  @override
  Future<bool> writeWorkout({
    required WorkoutActivity activity,
    required DateTime start,
    required DateTime end,
    String? title,
  }) async {
    await _ensureConfigured();

    // The store rejects a zero-length or inverted session, and a workout with
    // no elapsed time is not one the user did — catch it here rather than let
    // the platform throw across a channel.
    if (!end.isAfter(start)) {
      _logger.fine('Not writing a workout that did not elapse');
      return false;
    }

    try {
      return await _plugin.writeWorkoutData(
        activityType: _activityType(activity),
        start: start,
        end: end,
        title: title,
        // Energy stays nil, on purpose. There is no measurement of it without a
        // watch session, and an estimate that disagrees with the Watch's own
        // reading is worse than an absence. Same for distance, which lifting
        // does not have. See [HealthService.writeWorkout].
      );
    } catch (error, stacktrace) {
      // Never fatal to finishing a workout. The session is already saved in
      // Heart's own database and on the server; the mirror in Health is the
      // part the user can live without, and a refused permission arrives here
      // looking exactly like a real failure.
      if (_isUnauthorized(error)) {
        _logger.fine('Health write unauthorized', error);
        return false;
      }

      _logger.warning('Health workout write failed', error, stacktrace);
      return false;
    }
  }

  @override
  Future<bool> requestHistoryAccess() async {
    if (defaultTargetPlatform != .android) return true;

    try {
      await _ensureConfigured();
      if (!await _plugin.isHealthDataHistoryAvailable()) return false;
      if (await _plugin.isHealthDataHistoryAuthorized()) return true;

      final granted = await _plugin.requestHealthDataHistoryAuthorization();
      if (!granted) {
        _logger.info('Health history access declined; reads will not reach past 30 days');
      }
      return granted;
    } catch (error, stacktrace) {
      // Declined is survivable — a month of history is still a chart. Never
      // asking is not, so this must not take the surrounding request down.
      _logger.warning('Health history request failed', error, stacktrace);
      return false;
    }
  }

  @override
  Future<void> openInstaller() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin.installHealthConnect();
    }
  }

  @override
  Future<bool> openPermissions() async {
    // Health Connect's permission screen is an implicit intent, not a URL, so
    // it needs the host app to fire it — see [healthPlatformChannel].
    if (defaultTargetPlatform == .android) {
      try {
        return await _channel.invokeMethod<bool>('openHealthConnectSettings') ?? false;
      } catch (error, stacktrace) {
        _logger.warning('Could not open Health Connect settings', error, stacktrace);
        return false;
      }
    }

    if (defaultTargetPlatform != .iOS) return false;

    try {
      // Undocumented but long-standing, and the only handle Apple gives out:
      // there is no API for deep-linking to Heart's own row, so this lands on
      // the Health summary and the user walks the last two steps.
      //
      // Launched without a `canLaunchUrl` check on purpose — that one calls
      // `canOpenURL`, which answers false for any scheme absent from
      // `LSApplicationQueriesSchemes`. Opening reports its own failure.
      return await _launch(Uri.parse('x-apple-health://'));
    } catch (error, stacktrace) {
      // A simulator has no Health app, and neither will anything else that
      // fails here. The caller's fallback is the answer, not a crash.
      _logger.warning('Could not open the Health app', error, stacktrace);
      return false;
    }
  }

  List<plugin.HealthDataType> _typesFor(Set<HealthMetric> metrics) {
    return metrics
        .map(_dataType)
        .nonNulls
        // A metric can be absent on a platform; asking anyway throws.
        .where(_plugin.isDataTypeAvailable)
        .toList();
  }

  HealthSample? _toSample(plugin.HealthDataPoint point) {
    final metric = _metricOf(point.type);
    if (metric == null) return null;

    final value = switch (point.value) {
      plugin.NumericHealthValue(:final numericValue) => numericValue.toDouble(),
      // Audiograms, ECGs, nutrition blobs — nothing we asked for, but the
      // plugin's value type is a union, so guard rather than cast.
      _ => null,
    };
    if (value == null) return null;

    // The plugin's default unit per type already matches HealthMetric.unit for
    // everything we read (kg, kcal, bpm, ms, %, count, minutes). Verify instead
    // of converting, so a plugin change surfaces as a log line rather than as
    // silently wrong numbers on a chart.
    if (!_unitMatches(metric, point.unit)) {
      _logger.warning('Unexpected unit ${point.unit} for ${metric.value}; dropping sample');
      return null;
    }

    return HealthSample(
      id: point.uuid,
      metric: metric,
      value: value,
      start: point.dateFrom,
      end: point.dateTo,
      source: HealthSource(
        id: point.sourceId,
        name: point.sourceName,
        deviceModel: point.deviceModel,
      ),
      isManual: point.recordingMethod == plugin.RecordingMethod.manual,
    );
  }
}

/// What a Heart session is, in the platform's vocabulary.
///
/// Not a [HealthMetric] and deliberately not made one: [HealthMetric] is the
/// vocabulary of things Heart *reads and charts*, and a workout is neither — it
/// is the one thing written out.
const _workoutType = plugin.HealthDataType.WORKOUT;

/// Heart's activity as the platform in front of us spells it.
///
/// The two stores overlap but do not agree, and the plugin enforces the
/// difference: an activity a platform does not know throws `HealthException`
/// rather than degrading, so every branch here has to land on something that
/// platform actually accepts. The disagreements are not exotic — they cover
/// most of what Heart logs:
///
/// - **Lifting.** `STRENGTH_TRAINING` is Health Connect's; Apple splits it in
///   two, where *functional* is bodyweight and kettlebell work and
///   *traditional* is machines and free weights, which is what Heart logs.
/// - **Swimming.** `SWIMMING` is iOS-only; Health Connect wants a pool or open
///   water, and a Heart session is the pool.
/// - **Indoor variants.** Apple does not distinguish a stationary bike or a
///   treadmill from the real thing; Health Connect does.
/// - **iOS-only ideas.** `CROSS_TRAINING`, `MIXED_CARDIO`, `CORE_TRAINING`,
///   `FLEXIBILITY` and `JUMP_ROPE` have no Health Connect equivalent worth
///   pretending to, so they fall to `OTHER` rather than to a neighbouring
///   activity that would be a small lie in the user's own health record.
///   `JUMP_ROPE` is the one to be careful about: the plugin's enum lists it
///   under a comment saying "Both", and only `_isOnAndroid` — the list that
///   actually throws — reveals it is not.
plugin.HealthWorkoutActivityType _activityType(WorkoutActivity activity) {
  final isIos = defaultTargetPlatform == TargetPlatform.iOS;

  return switch (activity) {
    .strength => isIos ? .TRADITIONAL_STRENGTH_TRAINING : .STRENGTH_TRAINING,
    .crossTraining => isIos ? .CROSS_TRAINING : .OTHER,
    .mixedCardio => isIos ? .MIXED_CARDIO : .OTHER,
    .cycling => .BIKING,
    .cyclingIndoor => isIos ? .BIKING : .BIKING_STATIONARY,
    .elliptical => .ELLIPTICAL,
    .hiking => .HIKING,
    .rowing => isIos ? .ROWING : .ROWING_MACHINE,
    .running => .RUNNING,
    .runningTreadmill => isIos ? .RUNNING : .RUNNING_TREADMILL,
    .skating => .SKATING,
    .skiing => .DOWNHILL_SKIING,
    .snowboarding => .SNOWBOARDING,
    .swimming => isIos ? .SWIMMING : .SWIMMING_POOL,
    .walking => .WALKING,
    .climbing => isIos ? .CLIMBING : .ROCK_CLIMBING,
    .coreTraining => isIos ? .CORE_TRAINING : .CALISTHENICS,
    .flexibility => isIos ? .FLEXIBILITY : .OTHER,
    .yoga => .YOGA,
    .cardioDance => .CARDIO_DANCE,
    .highIntensity => .HIGH_INTENSITY_INTERVAL_TRAINING,
    .jumpRope => isIos ? .JUMP_ROPE : .OTHER,
    .other => .OTHER,
  };
}

/// Our metric to the platform's quantity.
///
/// HRV is the one that differs: Apple exposes SDNN, Health Connect exposes
/// RMSSD. Both are beat-to-beat variability in milliseconds and neither
/// converts to the other — see [HealthMetric.isPlatformDependent].
plugin.HealthDataType? _dataType(HealthMetric metric) {
  return switch (metric) {
    .restingHeartRate => .RESTING_HEART_RATE,
    .heartRate => .HEART_RATE,
    .heartRateVariability => switch (defaultTargetPlatform) {
      .iOS => .HEART_RATE_VARIABILITY_SDNN,
      _ => .HEART_RATE_VARIABILITY_RMSSD,
    },
    .steps => .STEPS,
    .activeEnergy => .ACTIVE_ENERGY_BURNED,
    .bodyMass => .WEIGHT,
    .bodyFatPercentage => .BODY_FAT_PERCENTAGE,
    .sleepAsleep => .SLEEP_ASLEEP,
    .sleepDeep => .SLEEP_DEEP,
    .sleepRem => .SLEEP_REM,
  };
}

/// The platform's quantity back to our metric. Both HRV flavours collapse into
/// one metric, which is exactly why that metric is flagged platform-dependent.
HealthMetric? _metricOf(plugin.HealthDataType type) {
  return switch (type) {
    .RESTING_HEART_RATE => .restingHeartRate,
    .HEART_RATE => .heartRate,
    .HEART_RATE_VARIABILITY_SDNN => .heartRateVariability,
    .HEART_RATE_VARIABILITY_RMSSD => .heartRateVariability,
    .STEPS => .steps,
    .ACTIVE_ENERGY_BURNED => .activeEnergy,
    .WEIGHT => .bodyMass,
    .BODY_FAT_PERCENTAGE => .bodyFatPercentage,
    .SLEEP_ASLEEP => .sleepAsleep,
    .SLEEP_DEEP => .sleepDeep,
    .SLEEP_REM => .sleepRem,
    _ => null,
  };
}

bool _unitMatches(HealthMetric metric, plugin.HealthDataUnit unit) {
  return switch ((metric.unit, unit)) {
    (.bpm, .BEATS_PER_MINUTE) => true,
    (.milliseconds, .MILLISECOND) => true,
    (.count, .COUNT) => true,
    (.kilocalories, .KILOCALORIE) => true,
    (.kilograms, .KILOGRAM) => true,
    (.percent, .PERCENT) => true,
    (.minutes, .MINUTE) => true,
    _ => false,
  };
}

/// The store this platform can offer.
///
/// iOS and Android get the real thing; macOS and desktop compile the plugin but
/// have no native side behind it, so they get the same empty behaviour as web.
HealthService healthStore() {
  return switch (defaultTargetPlatform) {
    .iOS || .android => DeviceHealthStore(),
    _ => const UnsupportedHealthStore(),
  };
}
