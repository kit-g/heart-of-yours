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

    test('a replaced exercise says how far it reaches and whether it was suggested, never which (#354)', () {
      sut.exerciseReplaced(scope: .program, suggested: true);

      expect(parametersOf('exercise_replaced'), {'replace_scope': 'program', 'suggested': 'true'});
    });

    test('a program from the library names which one by its key, and one from a folder names none (#352)', () {
      sut.programCreated(source: .library, sessions: 6, library: 'strength_waves');
      expect(parametersOf('program_created'), {
        'source': 'library',
        'sessions': 6,
        'library_program': 'strength_waves',
      });

      sut.programCreated(source: .folder, sessions: 3);
      expect(parametersOf('program_created'), {'source': 'folder', 'sessions': 3});
    });

    test('a program\'s constraint says it was set or cleared, never which (#355)', () {
      sut.programConstraint(set: true);
      expect(parametersOf('program_constraint'), {'action': 'set'});
      sut.programConstraint(set: false);
      expect(parametersOf('program_constraint'), {'action': 'cleared'});
    });

    test('a set type goes as its wire word (#151)', () {
      sut.setTypeChanged(type: .warmup);

      expect(parametersOf('set_type_changed'), {'set_type': 'warmup'});
    });

    group('coaching (tier 4)', () {
      test('a feature switch names the feature, the answer and where it was given', () {
        sut.featureSwitched(feature: .yourCoach, on: false, source: .ask);
        expect(parametersOf('feature_switched'), {'feature': 'yourCoach', 'on': 'false', 'source': 'ask'});

        sut.featureSwitched(feature: .coachPeople, on: true, source: .settings);
        expect(parametersOf('feature_switched'), {'feature': 'coachPeople', 'on': 'true', 'source': 'settings'});
      });

      test('an invitation says whether it carried a program, and an answer whether it was a yes', () {
        sut.invitationCreated(withProgram: false);
        expect(parametersOf('invitation_created'), {'with_program': 'false'});

        sut.invitationAnswered(accepted: true);
        expect(parametersOf('invitation_answered'), {'accepted': 'true'});
      });

      test("a connection's change names this account's side and what became of it", () {
        sut.coachingChanged(role: .student, action: .paused);
        expect(parametersOf('coaching_changed'), {'role': 'student', 'coaching_action': 'paused'});

        sut.coachingChanged(role: .coach, action: .ended);
        expect(parametersOf('coaching_changed'), {'role': 'coach', 'coaching_action': 'ended'});
      });

      test("a client's copy edited names the part, as its wire word", () {
        sut.clientProgramEdited(edit: .sessionDeleted);
        expect(parametersOf('client_program_edited'), {'coaching_action': 'session_deleted'});
      });

      test('the counts go as numbers', () {
        sut.programSent(clients: 3);
        expect(parametersOf('program_sent'), {'clients': 3});

        sut.workoutLoggedFor(exerciseCount: 2, setCount: 5);
        expect(parametersOf('workout_logged_for'), {'exercise_count': 2, 'set_count': 5});
      });

      test('a look at a client, and a note deleted, carry nothing', () {
        sut.clientReviewed();
        expect(parametersOf('client_reviewed'), isEmpty);

        sut.coachNoteDeleted();
        expect(parametersOf('coach_note_deleted'), isEmpty);
      });

      test('a message and a deletion carry the side when it is known, and nothing in its place when not', () {
        sut.messageSent(role: .coach);
        expect(parametersOf('message_sent'), {'role': 'coach'});

        sut.messageSent();
        expect(parametersOf('message_sent'), isEmpty);

        sut.conversationDeleted(role: .student);
        expect(parametersOf('conversation_deleted'), {'role': 'student'});
      });

      test("a report carries the tag's wire word and two flags, never its wording", () {
        sut.personReported(reason: .unsafeAdvice, withMessages: true, alsoBlocked: false);
        expect(parametersOf('person_reported'), {
          'reason': 'unsafe_advice',
          'with_messages': 'true',
          'also_blocked': 'false',
        });
      });

      test('a note says whether it was new', () {
        sut.coachNoteSaved(edited: true);
        expect(parametersOf('coach_note_saved'), {'edited': 'true'});
      });

      test('the coaching role is a user property, cleared with no account', () {
        sut.setCoachingRole(.both);
        verify(service.setUserProperty('coaching_role', 'both')).called(1);

        sut.setCoachingRole(null);
        verify(service.setUserProperty('coaching_role', null)).called(1);
      });

      test('the role follows from the two sides', () {
        expect(CoachingRole.of(coaches: true, coached: true), CoachingRole.both);
        expect(CoachingRole.of(coaches: true, coached: false), CoachingRole.coach);
        expect(CoachingRole.of(coaches: false, coached: true), CoachingRole.student);
        expect(CoachingRole.of(coaches: false, coached: false), CoachingRole.none);
      });
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
