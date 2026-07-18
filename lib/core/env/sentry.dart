import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A test for whether the current run should be kept out of Sentry entirely:
/// its events are noise, not signal (e.g. automated test devices). Returns
/// `true` to exclude. Register new ones in [_sentryExclusions].
typedef SentryExclusion = Future<bool> Function();

/// Environments whose events pollute Sentry. Add to this list to expand
/// coverage; [initSentry] skips setup if any one matches.
const List<SentryExclusion> _sentryExclusions = [
  _isFirebaseTestLab,
];

Future<bool> _excludedFromSentry() async {
  for (final excluded in _sentryExclusions) {
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

FutureOr<void> initSentry(FutureOr<void> Function() appRunner, AppConfig config) async {
  if (kDebugMode || await _excludedFromSentry()) return appRunner();
  return SentryFlutter.init(
    (options) {
      options
        ..debug = !config.isProd
        ..enableAutoPerformanceTracing = true
        ..enableWatchdogTerminationTracking = true
        ..enableMemoryPressureBreadcrumbs = true
        ..dsn = config.sentryDsn
        ..tracesSampleRate = 1.0
        ..diagnosticLevel = switch (config.env) {
          .dev => .debug,
          .test => .info,
          .prod => .error,
        };
    },
    appRunner: appRunner,
  );
}

Future<void> reportToSentry(dynamic exception, {dynamic stacktrace}) {
  if (kDebugMode) {
    print(exception);
    if (stacktrace != null) {
      print(stacktrace);
    }
  }
  return Sentry.captureException(exception, stackTrace: stacktrace);
}

typedef SentryInit = FutureOr<void> Function(Future<void> Function(), AppConfig);
