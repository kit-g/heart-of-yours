import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:heart/core/env/config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initSentry(FutureOr<void> Function() appRunner) {
  return SentryFlutter.init(
    (options) {
      options
        ..debug = kDebugMode
        ..enableAutoPerformanceTracing = true
        ..enableWatchdogTerminationTracking = true
        ..enableMemoryPressureBreadcrumbs = true
        ..dsn = AppConfig.sentryDsn
        ..tracesSampleRate = kDebugMode ? null : 1.0
        ..profilesSampleRate = kDebugMode ? null : 1.0
        ..diagnosticLevel = switch (AppConfig.env) {
          Env.dev => SentryLevel.debug,
          Env.prod => SentryLevel.error,
        };
    },
    appRunner: appRunner,
  );
}

Future<void> reportToSentry(dynamic exception, {dynamic stacktrace}) {
  return Sentry.captureException(exception, stackTrace: stacktrace);
}
