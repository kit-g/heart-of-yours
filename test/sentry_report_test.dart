import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, OSError, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart_api/heart_api.dart' show Api, NetworkException;
import 'package:heart_models/heart_models.dart' show User;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as testing;
import 'package:sentry_flutter/sentry_flutter.dart';

/// What [reportToSentry] lets through (#682): a request that never got an
/// answer is dropped, however it arrives and whatever wraps it; a server's
/// answer, a refused certificate, our own deadline and a Firebase error that
/// is not about the network are still reported, and a server's answer never
/// with its body (#681).
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

    test('a wait whose every failed leg was offline', () async {
      await report(await waited(const SocketException('Failed host lookup'), http.ClientException('reset')));
      expect(sent, isEmpty);
    });
  });

  group('still reported', () {
    test('a status from our server, grouped by status and endpoint', () async {
      await report(const NetworkException(statusCode: 500, method: 'PUT', path: '/v1/accounts'));
      expect(sent.single.fingerprint, ['NetworkException', 'NetworkException(500 PUT /v1/accounts)']);
    });

    test("the Api's own failure, by its request and without its body", () async {
      Api(
        gateway: 'api.example.com',
        client: testing.MockClient(
          (request) async => http.Response(
            jsonEncode({'code': 'server_error', 'error': 'muffin@example.com'}),
            500,
            request: request,
          ),
        ),
      );
      final thrown = await Api.instance.registerAccount(User(id: '42')).then<Object?>((_) => null, onError: (e) => e);

      await report(thrown!);

      final event = sent.single;
      expect(event.fingerprint, ['NetworkException', 'NetworkException(500 PUT /v1/accounts)']);
      final json = jsonEncode(event.toJson());
      // the exception is in the event as sent, so its absence below means something
      expect(json, contains('NetworkException(500 PUT /v1/accounts)'));
      expect(json, isNot(contains('muffin@example.com')));
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

    test('a deadline of our own, on a server reachable but slow', () async {
      await report(TimeoutException('no answer', const Duration(seconds: 5)));
      expect(sent, hasLength(1));
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
