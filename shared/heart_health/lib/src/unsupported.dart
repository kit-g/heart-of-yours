part of '../heart_health.dart';

/// A [HealthService] for platforms with no health store — web, and any
/// `dart:io` platform that isn't iOS or Android.
///
/// Every read is empty and every request is a refusal, so callers need no
/// platform checks of their own: ask for data, get none, render the same empty
/// state a user who declined would see.
///
/// Lives in the library proper rather than behind the conditional export in
/// `store.dart` because it depends on nothing — both branches need it, and web
/// can see it without pulling in the plugin.
class UnsupportedHealthStore implements HealthService {
  const new();

  @override
  bool get isSupported => false;

  @override
  Future<HealthStoreStatus> status() async => HealthStoreStatus.unavailable;

  @override
  Future<HealthAccess> access(Set<HealthMetric> metrics) async => HealthAccess.denied;

  @override
  Future<bool> requestAccess(Set<HealthMetric> metrics) async => false;

  @override
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  }) async {
    return const [];
  }

  @override
  Future<void> openInstaller() async {}
}
