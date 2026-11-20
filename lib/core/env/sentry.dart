import 'dart:async';
import 'dart:io' show HandshakeException, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show RouteSettings;
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/telemetry.dart';
import 'package:heart_api/heart_api.dart' show NetworkException;
import 'package:heart_state/heart_state.dart' show ProgramReadFailed;
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

FutureOr<void> initSentry(FutureOr<void> Function() appRunner, AppConfig config) async {
  if ((kDebugMode && !forceTelemetry) || await excludedFromTelemetry()) return appRunner();
  return SentryFlutter.init(
    (options) {
      options
        ..debug = !config.isProd
        ..enableAutoPerformanceTracing = true
        ..enableWatchdogTerminationTracking = true
        ..enableMemoryPressureBreadcrumbs = true
        // The native HTTP capture sees every request the process makes, not
        // just ours — on iOS it reported Firebase Analytics' own config fetch
        // failing. Ours are captured on the Dart side, by SentryHttpClient.
        ..captureNativeFailedRequests = false
        // Nor on the Dart side: a failed request reaches [reportToSentry]
        // through the caller that made it, grouped by status and endpoint and
        // with a dropped connection filtered out. The client's own capture
        // reported the same failures a second time, ungrouped, and an offline
        // device's DNS failure along with them.
        ..captureFailedRequests = false
        // what Sentry's own handlers catch — an un-awaited future, a stream
        // that failed offline — goes through the same filter as [reportToSentry]
        ..beforeSend = dropUnanswered
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

/// Records a move between two screens that changes no route — a pane beside a
/// list — as the navigator observer records one that does, so an issue's
/// breadcrumbs still say where the user was.
void paneBreadcrumb({required String from, required String to}) {
  Sentry.addBreadcrumb(
    RouteObserverBreadcrumb(
      navigationType: 'pane',
      from: RouteSettings(name: from),
      to: RouteSettings(name: to),
    ),
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
  if ((kDebugMode && !forceTelemetry) || await excludedFromTelemetry()) return client;
  return SentryHttpClient(client: client);
}

/// Whether reported errors are also printed. A debug run's console is where a
/// developer reads them; a `flutter test` run is not, and there every mocked
/// failure and simulated outage printed a full stack trace, burying the one
/// line that says whether the suite passed. The app suite turns it off in
/// `test/flutter_test_config.dart`.
@visibleForTesting
bool echoReportedErrors = true;

Future<void> reportToSentry(dynamic exception, {dynamic stacktrace}) {
  if (kDebugMode && echoReportedErrors) {
    debugPrint('$exception');
    if (stacktrace != null) {
      debugPrint('$stacktrace');
    }
  }
  return switch (_reportable(exception, stacktrace)) {
    (final Object error, final stacktrace) => Sentry.captureException(
      error,
      stackTrace: stacktrace,
      withScope: switch (error) {
        // One issue per status and endpoint. Grouped by stack, every async
        // chain into the same call became an issue of its own — fifteen of them
        // for what was mostly one failure. The message is the grouping key:
        // it names the status, verb and templated path, and never the body.
        NetworkException() => (scope) => scope.fingerprint = ['NetworkException', error.toString()],
        // one issue per call and cause, whichever program it was (#660)
        ProgramReadFailed() => (scope) => scope.fingerprint = ['ProgramReadFailed', error.toString()],
        _ => null,
      },
    ),
    null => Future.value(),
  };
}

/// What to report for [error], with its stack trace: the error itself, or
/// the first failure inside a wrapper that is worth reporting; null when
/// there is none, because all of it was the network not answering.
///
/// A wrapper is unwrapped because its own type says nothing: `.wait` on a
/// record of requests (`Coaching.load`) fails as a [ParallelWaitError]
/// whether a leg was offline or the server refused it, and only the leg says
/// which. Reported as the leg, a refusal groups with the same
/// [NetworkException] from anywhere else.
(Object, dynamic)? _reportable(Object? error, dynamic stacktrace) {
  return switch (error) {
    null => null,
    AsyncError(:final error, :final stackTrace) => _reportable(error, stackTrace),
    ParallelWaitError(:final errors) => switch (_legs(errors)) {
      final Iterable<Object?> legs => legs.map((each) => _reportable(each, stacktrace)).nonNulls.firstOrNull,
      // a shape not listed below: report the wrapper rather than lose it
      null => (error, stacktrace),
    },
    _ when _isOffline(error) => null,
    _ => (error, stacktrace),
  };
}

/// The legs of a [ParallelWaitError], an [AsyncError] for each that failed:
/// from a list, or from a record of the arities the app waits on; null for
/// any other shape.
Iterable<Object?>? _legs(Object? errors) {
  return switch (errors) {
    Iterable each => each,
    (final a, final b) => [a, b],
    (final a, final b, final c) => [a, b, c],
    (final a, final b, final c, final d) => [a, b, c, d],
    (final a, final b, final c, final d, final e) => [a, b, c, d, e],
    (final a, final b, final c, final d, final e, final f) => [a, b, c, d, e, f],
    _ => null,
  };
}

/// [event], unless what it reports is a request that never got an answer
/// (see [reportToSentry]): the filter for what Sentry's own handlers catch.
@visibleForTesting
SentryEvent? dropUnanswered(SentryEvent event, Hint hint) {
  return switch (event.throwable) {
    final Object error when _reportable(error, null) == null => null,
    _ => event,
  };
}

/// Whether [error] is a request that never got an answer — offline, DNS, a
/// socket closed under a backgrounded app — rather than a fault in our code or
/// a refusal from a server. Every caller already retries on the next launch or
/// resume, and there is nothing to fix.
///
/// Still reported: a status from our server (a [NetworkException]); a
/// Firebase error that is not about the network; a certificate the handshake
/// refused, which is our certificate broken or someone in the middle; and a
/// [TimeoutException], because the only deadline on a request is our own
/// (`Pushes.unregister`), there to report a server reachable but slow.
bool _isOffline(Object? error) {
  return switch (error) {
    // through the http client, which wraps whatever the socket said, or a
    // socket error raised outside it
    http.ClientException() || SocketException() => true,
    // a TLS handshake the connection ended under (HEART-OF-YOURS-2Z)
    HandshakeException() => _cutOff.hasMatch('$error'),
    // a token refresh that could not reach Google: named (HEART-OF-YOURS-1R)…
    FirebaseAuthException(code: 'network-request-failed') => true,
    // …or, on Android, sometimes only in the message of an `unknown` (-33)
    FirebaseAuthException(code: 'unknown', :final String message) => _androidOffline.hasMatch(message),
    _ => false,
  };
}

/// A handshake the connection ended under, as against one that failed on its
/// merits (`CERTIFICATE_VERIFY_FAILED` and the like).
final _cutOff = RegExp(
  'Connection terminated|Connection reset|Connection closed|Broken pipe|Software caused connection abort|timed out',
);

/// The Java network exceptions an Android Firebase error can carry as text:
/// `ConnectException`'s "Failed to connect to", `UnknownHostException`'s
/// "Unable to resolve host".
final _androidOffline = RegExp('Failed to connect to|Unable to resolve host');

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
  if (kDebugMode && echoReportedErrors) {
    // Locally the full error is far more useful than a redacted one, and it
    // goes nowhere.
    debugPrint('$exception');
    if (stacktrace != null) {
      debugPrint('$stacktrace');
    }
  }
  return Sentry.captureException(
    RedactedError(exception.runtimeType, 'health'),
    stackTrace: stacktrace,
  );
}

typedef SentryInit = FutureOr<void> Function(Future<void> Function(), AppConfig);
