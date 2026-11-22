import 'dart:async';
import 'dart:io' show HandshakeException, OSError, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart_api/heart_api.dart' show NetworkException, UnreadableAnswer;
import 'package:heart_models/heart_models.dart' show ServerRefusal;
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

/// What [reportToSentry] lets through (#682): a request that never got an
/// answer is dropped, however it arrives and whatever wraps it; a server's
/// answer, a refused certificate, our own deadline and a Firebase error that
/// is not about the network are still reported.
void main() {
  final sent = <SentryEvent>[];

  setUpAll(() async {
    await Sentry.init((options) {
      options
        ..dsn = 'https://public@sentry.example.com/1'
        // the transport is never reached: each event is kept and dropped here
        ..beforeSend = (event, hint) {
          sent.add(event);
          return null;
        };
    });
  });

  tearDownAll(Sentry.close);

  setUp(sent.clear);

  Future<void> report(Object error) => reportToSentry(error, stacktrace: StackTrace.current);

  /// What `.wait` on a record of two requests throws when they fail as given.
  Future<Object> waited(Object? first, Object? second) async {
    Future<int> leg(Object? error) => switch (error) {
      final Object error => Future.error(error),
      null => Future.value(1),
    };
    try {
      await (leg(first), leg(second)).wait;
    } catch (error) {
      return error;
    }
    fail('the wait did not fail');
  }

  group('dropped as offline', () {
    test('a ClientException from the http client', () async {
      await report(http.ClientException('Bad file descriptor', Uri.parse('https://api.example.com/v1/accounts')));
      expect(sent, isEmpty);
    });

    test('a SocketException raised outside the client', () async {
      await report(const SocketException('Failed host lookup'));
      expect(sent, isEmpty);
    });

    test('a TLS handshake cut off', () async {
      await report(const HandshakeException('Connection terminated during handshake'));
      expect(sent, isEmpty);
    });

    test("Firebase's network-request-failed", () async {
      await report(FirebaseAuthException(code: 'network-request-failed', message: 'A network error has occurred.'));
      expect(sent, isEmpty);
    });

    test("Android's unknown Firebase error that could not connect", () async {
      await report(
        FirebaseAuthException(
          code: 'unknown',
          message: 'An internal error has occurred. [ Failed to connect to securetoken.googleapis.com/1.2.3.4:443',
        ),
      );
      expect(sent, isEmpty);
    });

    test('an AsyncError around one', () async {
      await report(AsyncError(const SocketException('Failed host lookup'), StackTrace.current));
      expect(sent, isEmpty);
    });

    test('a deadline put on a request, passed without an answer', () async {
      await report(TimeoutException('no answer', const Duration(seconds: 5)));
      expect(sent, isEmpty);
    });

    test('a handshake on a socket iOS reclaimed while suspended', () async {
      await report(const HandshakeException('Handshake error in client', OSError('Bad file descriptor', 9)));
      expect(sent, isEmpty);
    });

    test("Android's unknown Firebase error that timed out", () async {
      await report(
        FirebaseAuthException(code: 'unknown', message: 'An internal error has occurred. [ timeout ]'),
      );
      expect(sent, isEmpty);
    });

    test('a wait whose every failed leg was offline', () async {
      await report(await waited(const SocketException('Failed host lookup'), http.ClientException('reset')));
      expect(sent, isEmpty);
    });
  });

  test('a wait of a shape not unpacked is reported as the wrapper', () async {
    await report(ParallelWaitError<Object?, Object?>(null, 'not a list or a record'));
    expect(sent, hasLength(1));
  });

  group('still reported', () {
    test('a status from our server, grouped by status and endpoint', () async {
      await report(const NetworkException(statusCode: 500, method: 'PUT', path: '/v1/accounts'));
      expect(sent.single.fingerprint, ['NetworkException', 'NetworkException(500 PUT /v1/accounts)']);
    });

    test('a refusal nobody handled, grouped by code and route, never by its details (#681)', () async {
      await report(
        const ServerRefusal(
          status: 404,
          code: 'goal_not_found',
          method: 'PUT',
          route: '/v1/goals/{id}',
          details: {'message': 'Goal g1 not found'},
        ),
      );
      expect(sent.single.fingerprint, ['ServerRefusal', 'goal_not_found PUT /v1/goals/{id}']);
      expect('${sent.single.throwable}', isNot(contains('Goal g1')));
    });

    test('a 2xx that could not be read groups with the other failed requests', () async {
      await report(const UnreadableAnswer(statusCode: 200, method: 'GET', path: '/v1/templates'));
      expect(sent.single.fingerprint, ['NetworkException', 'NetworkException(200 GET /v1/templates)']);
    });

    test('a handshake that refused the certificate', () async {
      await report(
        const HandshakeException(
          'Handshake error in client',
          OSError('CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate'),
        ),
      );
      expect(sent, hasLength(1));
    });

    test('a socket the device ran out of: a leak in our code', () async {
      await report(const SocketException('Too many open files', osError: OSError('Too many open files', 24)));
      expect(sent, hasLength(1));
    });

    test('every failed leg the server answered, each as itself', () async {
      // unlike any other test's: Sentry drops an exception object it has
      // already sent, and two equal consts are one object
      const forbidden = NetworkException(statusCode: 403, method: 'GET', path: '/v1/connections/pending');
      const broken = NetworkException(statusCode: 500, method: 'GET', path: '/v1/hidden-workouts');
      await report(await waited(forbidden, broken));
      expect(sent.map((each) => each.fingerprint), [
        ['NetworkException', 'NetworkException(403 GET /v1/connections/pending)'],
        ['NetworkException', 'NetworkException(500 GET /v1/hidden-workouts)'],
      ]);
    });

    test("an AsyncError with no trace of its own keeps the caller's", () async {
      final caller = StackTrace.current;
      await reportToSentry(AsyncError(StateError('a bug'), StackTrace.empty), stacktrace: caller);
      expect(sent.single.exceptions?.single.stackTrace?.frames, isNotEmpty);
    });

    test("a wait's failed leg that the server answered, as that leg", () async {
      const refused = NetworkException(statusCode: 403, method: 'GET', path: '/v1/connections');
      await report(await waited(const SocketException('Failed host lookup'), refused));
      expect(sent.single.fingerprint, ['NetworkException', 'NetworkException(403 GET /v1/connections)']);
    });

    test('a Firebase error that is not about the network', () async {
      await report(FirebaseAuthException(code: 'user-disabled'));
      expect(sent, hasLength(1));
    });

    test('an unknown Firebase error that names no network failure', () async {
      await report(FirebaseAuthException(code: 'unknown', message: 'An internal error has occurred.'));
      expect(sent, hasLength(1));
    });

    test('anything else', () async {
      await report(StateError('a bug'));
      expect(sent, hasLength(1));
    });
  });
}
