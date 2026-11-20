import 'dart:async';
import 'dart:io' show HandshakeException, SocketException;

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart_api/heart_api.dart' show NetworkException;
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

/// What [reportToSentry] lets through (#682): a request that never got an
/// answer is dropped, however it arrives; a server's answer and a Firebase
/// error that is not about the network are still reported.
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

    test('a TimeoutException', () async {
      await report(TimeoutException('no answer', const Duration(seconds: 30)));
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
  });

  group('still reported', () {
    test('a status from our server, grouped by status and endpoint', () async {
      await report(const NetworkException(statusCode: 500, method: 'PUT', path: '/v1/accounts'));
      expect(sent.single.fingerprint, ['NetworkException', 'NetworkException(500 PUT /v1/accounts)']);
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
