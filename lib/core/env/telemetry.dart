import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Forces this run to report even where it normally would not.
///
///     flutter run --dart-define=HEART_FORCE_TELEMETRY=true
///
/// For verifying the telemetry itself: a debug build otherwise sends nothing
/// at all — the analytics transport is the silent one and `initSentry` returns
/// early — so without this there is no way to see an event reach Firebase or a
/// span reach Sentry short of shipping a release.
///
/// It lifts the debug-build rule only. [excludedFromTelemetry] still applies:
/// a Test Lab robot must never report, whatever the build says.
const forceTelemetry = bool.fromEnvironment('HEART_FORCE_TELEMETRY');

/// A test for whether the current run should be kept out of telemetry
/// entirely: its events are noise, not signal (e.g. automated test devices).
/// Returns `true` to exclude. Register new ones in [_exclusions].
typedef TelemetryExclusion = Future<bool> Function();

/// Environments whose events pollute Sentry and Analytics alike. Add to this
/// list to expand coverage; both `initSentry` and `initAnalytics` consult it.
const List<TelemetryExclusion> _exclusions = [
  _isFirebaseTestLab,
];

/// Whether this run reports at all.
///
/// Deliberately one answer for both Sentry and Analytics. A run worth
/// excluding from one is worth excluding from the other, and two lists would
/// drift the moment either grew an entry.
///
/// `kDebugMode` is *not* folded in here: the callers each decide what debug
/// means for them, and they do not agree — Sentry wants the error printed
/// locally instead of sent, Analytics wants collection switched off in the SDK
/// as well as in the app.
/// Decided once. Three callers ask at startup — Sentry, Analytics and the HTTP
/// client — and the answer cannot change within a run, so asking the platform
/// three times would only add two channel round trips to a cold start.
Future<bool>? _decision;

Future<bool> excludedFromTelemetry() => _decision ??= _decide();

Future<bool> _decide() async {
  for (final excluded in _exclusions) {
    if (await excluded()) return true;
  }
  return false;
}

/// Google's Firebase Test Lab / Play pre-launch report robot. It drives the app
/// on virtualized devices and trips config-only errors no real user hits.
/// Detected via the documented `firebase.test.lab` system setting (Android only).
Future<bool> _isFirebaseTestLab() async {
  if (kIsWeb || defaultTargetPlatform != .android) return false;
  try {
    const channel = MethodChannel('me.heart/device');
    return await channel.invokeMethod<bool>('isFirebaseTestLab') ?? false;
  } on Exception {
    return false;
  }
}
