part of '../heart_health.dart';

/// Read access to the device's health store — HealthKit on iOS, Health Connect
/// on Android.
///
/// An interface so state and tests never touch the plugin. The only
/// implementations are [DeviceHealthStore] and [UnsupportedHealthStore]; pick
/// one with [DeviceHealthStore.forPlatform].
///
/// **Nothing read through here may be sent to a server.** Health data is
/// device-only by decision — the OS store is already the system of record and
/// already backed up, so copying it up buys nothing but liability. See
/// `docs/2026-08-02.wearables.md`.
abstract interface class HealthService {
  /// Whether this platform has a health store at all. False on web and desktop,
  /// where every other method is a no-op returning empty.
  bool get isSupported;

  /// Whether the store can be reached right now.
  ///
  /// Always [HealthStoreStatus.available] on a supported iOS device. On Android
  /// it can report that Health Connect is missing or too old, which is a state
  /// the user can fix — hence [openInstaller].
  Future<HealthStoreStatus> status();

  /// What we know about read access to [metrics].
  ///
  /// Read [HealthAccess.unknown]'s documentation before building UI on this. On
  /// iOS the honest answer is almost always "unknown", and that is not a bug.
  Future<HealthAccess> access(Set<HealthMetric> metrics);

  /// Shows the OS permission sheet for [metrics].
  ///
  /// Returns whether the sheet was presented without error — **not** whether
  /// the user granted anything. On iOS those are genuinely different questions
  /// and only the first is answerable. Call [read] afterwards and see whether
  /// data arrives.
  Future<bool> requestAccess(Set<HealthMetric> metrics);

  /// Every sample of [metrics] overlapping `[from, to)`.
  ///
  /// Faithful to the store: samples from different sources covering the same
  /// window are all returned, because they are distinct readings rather than
  /// duplicates. Summing them is a bug for any [HealthMetric.isCumulative]
  /// metric — see [HealthSample.source].
  ///
  /// Returns empty rather than throwing when access was refused; a refusal is
  /// a normal state, not an error.
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  });

  /// Sends the user to install or update Health Connect. Android only; a no-op
  /// everywhere else.
  Future<void> openInstaller();
}

/// Whether the device's health store can be used.
enum HealthStoreStatus {
  available,

  /// Health Connect is not installed, or the platform has no store at all.
  /// Recoverable on Android via [HealthService.openInstaller].
  unavailable,

  /// Health Connect is installed but too old. Also recoverable.
  needsUpdate,
}

/// What is known about read access.
enum HealthAccess {
  granted,
  denied,

  /// The platform will not say.
  ///
  /// This is the normal iOS answer and the reason [HealthService.requestAccess]
  /// promises so little. HealthKit deliberately refuses to disclose whether
  /// *read* permission was granted, because telling an app "you may not see the
  /// user's heart data" leaks that the user has heart data to hide. The API
  /// returns the same thing whether the user granted everything or nothing.
  ///
  /// Practical consequence: **never render a "Health connected ✓" state from a
  /// permission check.** The only evidence that access exists is samples coming
  /// back from [HealthService.read]. Drive the UI off whether there is data,
  /// and when there is none, say so neutrally — "no data yet" is true whether
  /// the user declined or simply hasn't worn a watch.
  unknown,
}
