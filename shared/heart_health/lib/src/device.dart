import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:health/health.dart' as plugin;
import 'package:heart_health/heart_health.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Health');

/// Reads the device's health store through the `health` plugin.
///
/// The plugin's vocabulary stops here: nothing outside this file mentions
/// `HealthDataType`, so swapping the plugin is a one-file change and the app's
/// state layer stays testable against [HealthService] alone.
class DeviceHealthStore implements HealthService {
  final plugin.Health _plugin;

  /// `configure()` is cheap but must run once before any query; this makes that
  /// the caller's non-problem.
  Future<void>? _configured;

  new({plugin.Health? health}) : _plugin = health ?? plugin.Health();

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

    try {
      // Read, explicitly, for every type. The plugin defaults to READ_WRITE when
      // `permissions` is omitted, which makes iOS ask to "access **and update**
      // your Health data" — write access we have no code to use, on a feature
      // whose entire pitch is restraint about the user's body. Tier 1 will widen
      // this deliberately, and only for the workout type it actually writes.
      return await _plugin.requestAuthorization(
        types,
        permissions: List.filled(types.length, plugin.HealthDataAccess.READ),
      );
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
  Future<void> openInstaller() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin.installHealthConnect();
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
