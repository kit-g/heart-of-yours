import 'package:flutter_test/flutter_test.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  group('Analytics', () {
    late MockAnalyticsService service;
    late Analytics sut;

    setUp(() {
      service = MockAnalyticsService();
      sut = Analytics(service: service);
    });

    /// The parameters of the one event [name] that was logged.
    Map<Object?, Object?> parametersOf(String name) {
      return verify(service.logEvent(name, captureAny)).captured.single as Map<Object?, Object?>;
    }

    test('every parameter reaches the SDK as a String or a num', () {
      sut.signupStarted(provider: .google, fromAnonymous: true);

      final parameters = parametersOf('signup_started');
      expect(parameters['provider'], 'google');
      expect(
        parameters['from_anonymous'],
        'true',
        reason: 'a bool trips an assert in firebase_analytics, so it is encoded here',
      );
      expect(parameters.values.every((each) => each is String || each is num), isTrue);
    });

    test('a replay reports its counts as numbers and its outcome as a flag', () {
      sut.replayFinished(rows: 42, uploaded: 3, existing: 23, skipped: 16, durationMs: 1200, ok: false);

      final parameters = parametersOf('upsync_replay_finished');
      expect(parameters['rows'], 42);
      expect(parameters['durationMs'], isNull, reason: 'the wire key is snake_case');
      expect(parameters['duration_ms'], 1200);
      expect(parameters['ok'], 'false');
    });

    test('the arrival of an account is named, not inferred from the event', () {
      sut.signupCompleted(provider: .apple, arrival: .takeover);

      expect(parametersOf('signup_completed'), {'provider': 'apple', 'arrival': 'takeover'});
    });

    test('a minted token reports its purpose and expiry, and a purpose left blank is named (#271)', () {
      sut.apiTokenCreated(purpose: .aiAssistant, expiry: .never);
      expect(parametersOf('api_token_created'), {'purpose': 'aiAssistant', 'expiry': 'never'});

      sut.apiTokenCreated(purpose: null, expiry: .year);
      expect(parametersOf('api_token_created'), {'purpose': 'unset', 'expiry': 'year'});
    });

    test('a set type goes as its wire word (#151)', () {
      sut.setTypeChanged(type: .warmup);

      expect(parametersOf('set_type_changed'), {'set_type': 'warmup'});
    });

    test('a session with no account behind it clears the property rather than leaving the last answer', () {
      sut.setAuthProvider(null);

      verify(service.setUserProperty('auth_provider', null)).called(1);
    });

    test('a transport failure is reported and goes no further', () async {
      final failure = Exception('the channel is not there');
      when(service.logEvent(any, any)).thenAnswer((_) => Future.error(failure));
      Object? reported;
      final sut = Analytics(
        service: service,
        onError: (error, {stacktrace}) => reported = error,
      );

      // The call itself must not throw — nothing awaits these, so a rejected
      // future with no handler would surface as an unhandled async error and
      // fail whatever unrelated test happened to be running.
      sut.anonymousSessionMinted();
      await Future<void>.delayed(Duration.zero);

      expect(reported, same(failure));
    });
  });
}
