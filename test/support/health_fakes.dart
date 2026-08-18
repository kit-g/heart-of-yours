import 'dart:async';

import 'package:heart_health/heart_health.dart';
import 'package:heart_state/heart_state.dart';

/// Stand-ins for the two things [Health] talks to.
///
/// Hand-written rather than generated: the tests need to reprogram them
/// mid-flight — flip platform support, stall a read, hand back a different
/// series on the next load — which mockito expresses far less readably.
class FakeHealthDevice implements HealthService {
  final log = <String>[];

  bool supported = true;
  HealthStoreStatus storeStatus = HealthStoreStatus.available;
  int requestAccessCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<HealthStoreStatus> status() async {
    log.add('status');
    return supported ? storeStatus : HealthStoreStatus.unavailable;
  }

  @override
  Future<HealthAccess> access(Set<HealthMetric> metrics) async => HealthAccess.unknown;

  @override
  Future<bool> requestAccess(Set<HealthMetric> metrics) async {
    log.add('requestAccess');
    requestAccessCalls++;
    return true;
  }

  /// Holds every [read] open until completed, so a test can look at the app
  /// while a sync is genuinely in flight rather than guessing at the frame.
  Completer<void>? gate;

  @override
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  }) async {
    log.add('read');
    if (gate case Completer<void> held) await held.future;
    return const [];
  }

  int historyRequests = 0;

  @override
  Future<HealthAccess> workoutWriteAccess() async => HealthAccess.granted;

  @override
  Future<bool> requestWorkoutWriteAccess() async {
    log.add('requestWorkoutWriteAccess');
    return true;
  }

  @override
  Future<bool> writeWorkout({
    required WorkoutActivity activity,
    required DateTime start,
    required DateTime end,
    String? title,
  }) async {
    log.add('writeWorkout');
    return true;
  }

  @override
  Future<bool> requestHistoryAccess() async {
    log.add('requestHistoryAccess');
    historyRequests++;
    return true;
  }

  @override
  Future<void> openInstaller() async => log.add('openInstaller');

  /// Whether the platform has somewhere to send the user. False is the Android
  /// answer, and the one that makes the caller fall back.
  bool permissionsReachable = true;

  @override
  Future<bool> openPermissions() async {
    log.add('openPermissions');
    return permissionsReachable;
  }
}

/// The local mirror, as a map of already-reconciled daily values.
class FakeHealthStore implements HealthSampleStore {
  final daily = <HealthMetric, List<HealthDailyValue>>{};
  final deleted = <String>[];

  @override
  Future<void> storeHealthSamples(Iterable<HealthSample> samples, String userId) async {}

  @override
  Future<List<HealthSample>> getHealthSamples({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<DateTime?> lastHealthSampleAt({required String userId, required HealthMetric metric}) async => null;

  @override
  Future<List<HealthDailyValue>> getDailyHealth({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async => daily[metric] ?? const [];

  final backfilled = <(String, HealthMetric), DateTime>{};

  @override
  Future<DateTime?> healthBackfilledTo({required String userId, required HealthMetric metric}) async {
    return backfilled[(userId, metric)];
  }

  @override
  Future<void> setHealthBackfilledTo(DateTime at, {required String userId, required HealthMetric metric}) async {
    backfilled[(userId, metric)] = at;
  }

  @override
  Future<void> clearHealthBackfill(String userId) async {
    backfilled.removeWhere((key, _) => key.$1 == userId);
  }

  @override
  Future<void> deleteHealthSamples(String userId) async {
    deleted.add(userId);
    daily.clear();
  }
}

/// [Preferences] over an empty shared-preferences store.
Future<Preferences> freshPreferences() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = Preferences();
  await preferences.init();
  return preferences;
}
