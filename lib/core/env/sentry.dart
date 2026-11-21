import 'dart:async';
import 'dart:io' show HandshakeException, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show RouteSettings;
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/telemetry.dart';
import 'package:heart_api/heart_api.dart' show NetworkException;
import 'package:heart_models/heart_models.dart' show ServerRefusal;
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
  return Future.wait([
    for (final (error, trace) in _reportable(exception, stacktrace))
      Sentry.captureException(
        error,
        stackTrace: trace,
        withScope: switch (error) {
          // One issue per status and endpoint. Grouped by stack, every async
          // chain into the same call became an issue of its own — fifteen of
          // them for what was mostly one failure. The message is the grouping
          // key: it names the status, verb and templated path, and never the
          // body.
          NetworkException() => (scope) => scope.fingerprint = ['NetworkException', error.toString()],
          // A refusal no caller had a meaning for, one issue per code and
          // route (#681); never its details, which can echo what was sent. One
          // a caller handled is an answer, never reported at all.
          ServerRefusal(:final code, :final method, :final route) => (scope) => scope.fingerprint = [
            'ServerRefusal',
            '$code $method $route',
          ],
          // one issue per call and cause, whichever program it was (#660)
          ProgramReadFailed() => (scope) => scope.fingerprint = ['ProgramReadFailed', error.toString()],
          _ => null,
        },
      ),
  ]);
}

/// What to report for [error], each with its stack trace: the error itself,
/// or every failure inside a wrapper that is worth reporting; nothing when
/// all of it was the network not answering.
///
/// Only what a caller caught and handed here is filtered. An offline error
/// that escapes to Sentry's own handlers is still reported: nothing caught
/// it, and that missing catch is the bug (HEART-OF-YOURS-34 found one).
///
/// A wrapper is unwrapped because its own type says nothing: `.wait` on a
/// record of requests (`Coaching.load`) fails as a [ParallelWaitError]
/// whether a leg was offline or the server refused it, and only the legs say
/// which. Each leg worth it is reported as itself, so a [NetworkException]
/// leg groups with the same failure from anywhere else.
List<(Object?, dynamic)> _reportable(Object? error, dynamic stacktrace) {
  return switch (error) {
    // an AsyncError of something that isn't an [Error] carries an empty
    // trace: the caller's is the better one then
    AsyncError(:final error, :final stackTrace) => _reportable(
      error,
      stackTrace == StackTrace.empty ? stacktrace : stackTrace,
    ),
    ParallelWaitError(:final errors) => switch (_legs(errors)) {
      final Iterable<Object?> legs => [for (final leg in legs) ..._reportable(leg, stacktrace)],
      // a shape not listed below: report the wrapper rather than lose it
      null => [(error, stacktrace)],
    },
    _ when _isOffline(error) => const [],
    // a null included: a call site handing over nothing is a bug to find
    _ => [(error, stacktrace)],
  };
}

/// The legs of a [ParallelWaitError] that failed, each an [AsyncError]: from
/// a list, or from a record of any arity `.wait` takes (two to nine); null
/// for any other shape.
Iterable<Object?>? _legs(Object? errors) {
  return switch (errors) {
    Iterable each => each.nonNulls,
    (final a, final b) => [a, b].nonNulls,
    (final a, final b, final c) => [a, b, c].nonNulls,
    (final a, final b, final c, final d) => [a, b, c, d].nonNulls,
    (final a, final b, final c, final d, final e) => [a, b, c, d, e].nonNulls,
    (final a, final b, final c, final d, final e, final f) => [a, b, c, d, e, f].nonNulls,
    (final a, final b, final c, final d, final e, final f, final g) => [a, b, c, d, e, f, g].nonNulls,
    (final a, final b, final c, final d, final e, final f, final g, final h) => [a, b, c, d, e, f, g, h].nonNulls,
    (final a, final b, final c, final d, final e, final f, final g, final h, final i) => [
      a,
      b,
      c,
      d,
      e,
      f,
      g,
      h,
      i,
    ].nonNulls,
    _ => null,
  };
}

/// Whether [error] is a request that never got an answer — offline, DNS, a
/// socket closed under a backgrounded app, a deadline passed with no reply —
/// rather than a fault in our code or a refusal from a server. Nothing can
/// be fixed from a report of it; whatever the caller does with the failure
/// (a retry on the next launch or resume, an error state) is the caller's.
///
/// Still reported: a status from our server (a [NetworkException]); a
/// Firebase error that is not about the network; a certificate the handshake
/// refused, which is our certificate broken or someone in the middle; and a
/// socket the device ran out of, which is a leak in our code.
bool _isOffline(Object? error) {
  return switch (error) {
    // through the http client, which wraps whatever the socket said
    http.ClientException() => true,
    // a socket error raised outside it, unless the device ran out of them
    SocketException(:final osError) => !_exhausted.contains(osError?.errorCode),
    // a deadline put on a request, passed without an answer
    TimeoutException() => true,
    // a TLS handshake the connection ended under (HEART-OF-YOURS-2Z)
    HandshakeException() => _cutOff.hasMatch('$error'),
    // a token refresh that could not reach Google: named (HEART-OF-YOURS-1R)…
    FirebaseAuthException(code: 'network-request-failed') => true,
    // …or, on Android, sometimes only in the message of an `unknown` (-33)
    FirebaseAuthException(code: 'unknown', :final String message) => _androidOffline.hasMatch(message),
    _ => false,
  };
}

/// EMFILE and ENFILE: too many open files, in the process or the system.
const _exhausted = {23, 24};

/// A handshake the connection ended under, as against one that failed on its
/// merits (`CERTIFICATE_VERIFY_FAILED` and the like): including a socket iOS
/// reclaimed while the app was suspended (HEART-OF-YOURS-2S).
final _cutOff = RegExp(
  'Connection terminated|Connection reset|Connection closed|Broken pipe|Software caused connection abort|timed out'
  '|Bad file descriptor|Socket is not connected',
);

/// The Java network failures an Android Firebase error can carry as text:
/// `ConnectException`, `UnknownHostException`, a socket timeout, a reset or
/// aborted connection, an SSL read cut short.
final _androidOffline = RegExp(
  'Failed to connect to|Unable to resolve host|\\[ timeout \\]|Connection reset|Software caused connection abort'
  '|I/O error during system call',
);

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
