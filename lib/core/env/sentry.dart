import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:heart/core/env/config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

FutureOr<void> initSentry(FutureOr<void> Function() appRunner, AppConfig config) {
  if (kDebugMode) return appRunner();
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
  return Sentry.captureException(exception, stackTrace: stacktrace);
}

typedef SentryInit = FutureOr<void> Function(Future<void> Function(), AppConfig);
