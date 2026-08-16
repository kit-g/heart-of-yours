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

/// An error whose payload was dropped before it could reach Sentry, leaving
/// only what is safe: the original type, and the stack trace it came with.
@visibleForTesting
class const RedactedError(final Type original, final String domain) implements Exception {
  @override
  String toString() => '$original in $domain (message withheld — $domain data stays on device)';
}

/// Reports a health failure without its message.
///
/// Health data is device-only, and an exception message is a side channel that
/// quietly breaks that promise. The risk is not theoretical: a sqflite error
/// carries the failing SQL **and its bound arguments**, so a insert that blows
/// up on a bad row would ship the user's heart rate to a third party inside the
/// error string. Platform channel errors can echo the payload just as happily.
///
/// So nothing but the type and the stack trace survives. Both are about our
/// code rather than the user's body, and together they are enough to find the
/// bug — which is the only reason to report at all.
///
/// Use this for anything touching [Health]; never pass a health error to
/// [reportToSentry].
Future<void> reportHealthFailure(dynamic exception, {dynamic stacktrace}) {
  if (kDebugMode) {
    // Locally the full error is far more useful than a redacted one, and it
    // goes nowhere.
    print(exception);
    if (stacktrace != null) {
      print(stacktrace);
    }
  }
  return Sentry.captureException(
    RedactedError(exception.runtimeType, 'health'),
    stackTrace: stacktrace,
  );
}

typedef SentryInit = FutureOr<void> Function(Future<void> Function(), AppConfig);
