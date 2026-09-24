import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/telemetry.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

FutureOr<void> initSentry(FutureOr<void> Function() appRunner, AppConfig config) async {
  if (kDebugMode || await excludedFromTelemetry()) return appRunner();
  return SentryFlutter.init(
    (options) {
      options
        ..debug = !config.isProd
        ..enableAutoPerformanceTracing = true
        ..enableWatchdogTerminationTracking = true
        ..enableMemoryPressureBreadcrumbs = true
        ..dsn = config.sentryDsn
        // Nothing to stitch a client span to: heart-api runs no Sentry, so the
        // `sentry-trace` and `baggage` headers `SentryHttpClient` would add to
        // every request buy nothing. Left at the default `['.*']` they go to
        // the CDN as well as the API, and neither allows them through CORS —
        // both allow-lists are closed, so on the web the browser would refuse
        // the request before it left the machine. Spans are recorded either
        // way: propagation is gated on this list, span creation is not.
        // (Cleared rather than assigned: the option is a final list.)
        ..tracePropagationTargets.clear()
        // Every transaction in production is a span per API and CDN call
        // uploaded on the user's battery and bandwidth, for a volume no one
        // reads. Full rate stays where it is being watched.
        ..tracesSampleRate = switch (config.env) {
          .prod => 0.2,
          .dev || .test => 1.0,
        }
        ..diagnosticLevel = switch (config.env) {
          .dev => .debug,
          .test => .info,
          .prod => .error,
        };
    },
    appRunner: appRunner,
  );
}

/// The app's one HTTP client, instrumented where the run reports.
///
/// Wrapping is not a proxy: `SentryHttpClient` is a decorator whose `send`
/// delegates straight to [inner], so the request still goes to the gateway
/// over the same pooled socket. What it adds is a span per call — method,
/// sanitized URL, status, content length, and the throwable on a failure —
/// plus a breadcrumb trail that the next crash arrives carrying. Bodies are
/// never read.
///
/// Only wrapped in a run that will actually initialize Sentry. The client
/// consults the *global* options for `tracePropagationTargets`, and in a run
/// where `Sentry.init` never ran those are the defaults — which propagate
/// `sentry-trace` and `baggage` to every host for spans no hub will collect.
Future<http.Client> instrumentedClient({http.Client? inner}) async {
  final client = inner ?? http.Client();
  if (kDebugMode || await excludedFromTelemetry()) return client;
  return SentryHttpClient(client: client);
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
