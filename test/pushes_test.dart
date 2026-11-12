import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/push.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart' show ClientsPage;
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// The push client (#567) and its settings (#554): opt-in through the
/// coaching switches, so with both off nothing reaches FCM or the server, and
/// the app looks as it did before pushes were built.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late _FakeClient client;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    client = _FakeClient();
    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(
      api.registerDevice(
        platform: anyNamed('platform'),
        token: anyNamed('token'),
        utcOffsetMinutes: anyNamed('utcOffsetMinutes'),
      ),
    ).thenAnswer((_) async {});
    when(api.getPushSettings()).thenAnswer(
      (_) async => PushSettings(
        topics: [
          PushSetting(
            topic: 'coaching.message',
            group: 'coaching',
            name: 'Messages',
            description: 'When someone you train with writes to you',
            delivery: 'instant',
            options: ['instant', 'off'],
          ),
          // one this build has never heard of: the server words it, so it
          // still shows and changes
          PushSetting(
            topic: 'coaching.weekly_summary',
            group: 'coaching',
            name: 'Weekly summary',
            description: 'Once a week',
            delivery: 'daily',
            options: ['daily', 'off'],
          ),
        ],
      ),
    );
    when(api.setPushSetting(any, any, connectionId: anyNamed('connectionId'))).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    Map<String, Object> prefs, {
    bool anonymous = false,
    MockFirebaseAuth? firebaseAuth,
  }) async {
    // swept wide, as the a11y harness does: under the test font Settings'
    // pickers overflow a phone's width
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth:
          firebaseAuth ??
          MockFirebaseAuth(
            mockUser: MockUser(uid: 'muffin', email: 'muffin@test', isAnonymous: anonymous),
            signedIn: true,
          ),
      pushClient: client,
      settle: false,
    );
    await tester.pumpTimes();
  }

  void go(WidgetTester tester, String path) {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
  }

  testWidgets('both coaching switches off: no token, nothing registered, and Settings as it was', (tester) async {
    await pump(tester, {});

    expect(client.calls, isNot(contains('start')));
    verifyNever(
      api.registerDevice(
        platform: anyNamed('platform'),
        token: anyNamed('token'),
        utcOffsetMinutes: anyNamed('utcOffsetMinutes'),
      ),
    );

    go(tester, '/profile/settings');
    await tester.pumpTimes();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byKey(AppKeys.pushSettings), findsNothing, reason: 'the row opens the system settings, as before');

    // and a link to the page is one the app has no screen for
    go(tester, '/profile/settings/notifications');
    await tester.pumpTimes();
    expect(find.byType(PushSettingsPage), findsNothing);
  });

  testWidgets('an anonymous session has no account to push to', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'}, anonymous: true);

    expect(client.calls, isNot(contains('start')));
  });

  testWidgets('Your coach on: the device registers its token with its offset, once', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});

    expect(client.calls, containsAllInOrder(['channels Comments Messages Coaching', 'start']));
    verify(
      api.registerDevice(
        platform: DevicePlatform.android,
        token: 'fcm-1',
        utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      ),
    ).called(1);
    expect(client.calls, isNot(contains('ask')), reason: 'the permission is asked in context, never at launch');
  });

  testWidgets('a new token is registered too', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});

    client.newTokens.add('fcm-2');
    await tester.pumpTimes();

    verify(
      api.registerDevice(
        platform: anyNamed('platform'),
        token: 'fcm-2',
        utcOffsetMinutes: anyNamed('utcOffsetMinutes'),
      ),
    ).called(1);
  });

  testWidgets('turning the switch off drops the token and the channels, live', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});

    final context = tester.element(find.byType(Navigator).first);
    Preferences.of(context).answerOffer(.yourCoach, yes: false);
    await tester.pumpTimes();

    expect(client.calls, containsAllInOrder(['start', 'stop', 'delete channels']));
  });

  testWidgets('a quick on and off makes no token and leaves nothing listening', (tester) async {
    client.channelsMade = Completer();
    await pump(tester, {'feature-yourCoach': 'on'});

    // off while the start still waits on the platform for its channels
    final context = tester.element(find.byType(Navigator).first);
    Preferences.of(context).answerOffer(.yourCoach, yes: false);
    client.channelsMade!.complete();
    await tester.pumpTimes();

    expect(client.calls, isNot(contains('start')));
    expect(client.calls, containsAllInOrder(['channels Comments Messages Coaching', 'stop', 'delete channels']));
    expect(client.newTokens.hasListener, isFalse);
    expect(client.arrivals.hasListener, isFalse);
    verifyNever(
      api.registerDevice(
        platform: anyNamed('platform'),
        token: anyNamed('token'),
        utcOffsetMinutes: anyNamed('utcOffsetMinutes'),
      ),
    );
  });

  testWidgets('off while the token is being made: it is dropped right after', (tester) async {
    client.tokenMade = Completer();
    await pump(tester, {'feature-yourCoach': 'on'});

    final context = tester.element(find.byType(Navigator).first);
    Preferences.of(context).answerOffer(.yourCoach, yes: false);
    client.tokenMade!.complete();
    await tester.pumpTimes();

    expect(client.calls, containsAllInOrder(['start', 'stop', 'delete channels']));
    expect(client.newTokens.hasListener, isFalse);
  });

  group('a coach with only Coach people on', () {
    setUp(() {
      // the server's copy of the account, with the entitlement: it arrives
      // through settings sync, which an answered feature sets off
      when(api.registerAccount(any)).thenAnswer((invocation) async {
        final user = invocation.positionalArguments.single as User;
        return User(id: user.id, email: user.email, settings: user.settings, entitlements: ['coach']);
      });
      when(api.getClients(former: anyNamed('former'), cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: <ClientSummary>[], cursor: null));
      when(api.getCoachFeed(cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: <CoachFeedItem>[], cursor: null));
      when(
        api.getInvitations(cursor: anyNamed('cursor')),
      ).thenAnswer((_) async => (items: <Invitation>[], cursor: null));
    });

    testWidgets('a launch keeps the token: the account reads as no coach only until the server says', (
      tester,
    ) async {
      await pump(tester, {'feature-coachPeople': 'on', 'feature-recaps': 'off'});

      expect(client.calls, ['channels Comments Messages Coaching', 'start']);
    });

    testWidgets('a change Firebase reports to the account keeps the token too', (tester) async {
      final firebase = MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      );
      await pump(tester, {'feature-coachPeople': 'on', 'feature-recaps': 'off'}, firebaseAuth: firebase);

      // a new name or photo: Firebase hands over the account again, with
      // nothing of what the server granted
      firebase.userChangedStreamController.add(firebase.currentUser);
      await tester.pumpTimes();

      expect(client.calls, ['channels Comments Messages Coaching', 'start']);
    });
  });

  testWidgets('a visible push that came in the background is fetched on the way back in', (tester) async {
    when(api.getProgram('p1')).thenAnswer(
      (_) async =>
          Program(id: 'p1', name: 'Strength block', perWeek: 2, sessions: const [], createdAt: DateTime.utc(2026)),
    );
    when(api.getProgramActions('p1')).thenAnswer((_) async => []);
    when(api.getProgramBases('p1')).thenAnswer((_) async => []);
    await pump(tester, {'feature-yourCoach': 'on'});
    clearInteractions(api);

    for (final AppLifecycleState state in [.inactive, .hidden, .paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(.resumed));
    // the system showed it; the person opens Heart from its icon instead
    client.pending.add(Push.of({'topic': 'coaching.program_received', 'programId': 'p1'})!);
    for (final AppLifecycleState state in [.hidden, .inactive, .resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpTimes();

    verify(api.getProgram('p1')).called(1);
    expect(client.pending, isEmpty);
  });

  testWidgets('a silent push fetches the one program it names, and nothing else', (tester) async {
    when(api.getProgram('p1')).thenAnswer(
      (_) async =>
          Program(id: 'p1', name: 'Strength block', perWeek: 2, sessions: const [], createdAt: DateTime.utc(2026)),
    );
    when(api.getProgramActions('p1')).thenAnswer((_) async => []);
    when(api.getProgramBases('p1')).thenAnswer((_) async => []);
    await pump(tester, {'feature-yourCoach': 'on'});
    clearInteractions(api);

    client.arrivals.add((push: Push.of({'topic': 'coaching.program_changed', 'programId': 'p1'})!, title: null));
    await tester.pumpTimes();

    verify(api.getProgram('p1')).called(1);
    verifyNever(api.getPrograms());
    expect(client.calls, isNot(contains('show')), reason: 'a silent push shows nothing');
  });

  testWidgets('a visible push in front is shown by the app, with its title alone', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});

    client.arrivals.add((push: Push.of({'topic': 'coaching.message', 'threadId': 't1'})!, title: 'Dana messaged you'));
    await tester.pumpTimes();

    expect(client.calls, contains('show coaching.message Dana messaged you'));
  });

  testWidgets("a coach's tap on an accepted invitation opens Coaching's clients", (tester) async {
    // the server's copy of the account, with the entitlement: it arrives
    // through settings sync, which an answered feature sets off
    when(api.registerAccount(any)).thenAnswer((invocation) async {
      final user = invocation.positionalArguments.single as User;
      return User(id: user.id, email: user.email, settings: user.settings, entitlements: ['coach']);
    });
    when(api.getClients(former: anyNamed('former'), cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <ClientSummary>[], cursor: null));
    when(api.getCoachFeed(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachFeedItem>[], cursor: null));
    when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer((_) async => (items: <Invitation>[], cursor: null));
    await pump(tester, {'feature-coachPeople': 'on', 'feature-recaps': 'off'});
    go(tester, '/profile/settings');
    await tester.pumpTimes();

    client.taps.add(Push.of({'topic': 'coaching.invitation_accepted'})!);
    await tester.pumpTimes();

    expect(find.byType(ClientsPage), findsOneWidget);
  });

  testWidgets('a tap on a push about nothing this build can open leaves the app where it was', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});
    go(tester, '/profile/settings');
    await tester.pumpTimes();

    client.taps.add(Push.of({'topic': 'reaction.created', 'workoutId': 'w1'})!);
    await tester.pumpTimes();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  group('Settings › Notifications (#554)', () {
    testWidgets('on, the row opens the topics the server lists, its own words and all', (tester) async {
      await pump(tester, {'feature-yourCoach': 'on'});
      go(tester, '/profile/settings');
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.pushSettings);
      await tester.pumpTimes();

      expect(find.byType(PushSettingsPage), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Weekly summary'), findsOneWidget);
      expect(find.text('System settings'), findsOneWidget);
    });

    testWidgets('a choice reaches the server', (tester) async {
      await pump(tester, {'feature-yourCoach': 'on'});
      go(tester, '/profile/settings/notifications');
      await tester.pumpTimes();

      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('pushTopic-coaching.message')), matching: find.text('Off')),
      );
      await tester.pumpTimes();

      verify(api.setPushSetting('coaching.message', 'off')).called(1);
    });

    testWidgets('the list keeps to a readable width on a tablet', (tester) async {
      await pump(tester, {'feature-yourCoach': 'on'});
      go(tester, '/profile/settings/notifications');
      await tester.pumpTimes();

      final list = tester.getSize(find.descendant(of: find.byType(PushSettingsPage), matching: find.byType(ListView)));
      expect(list.width, lessThanOrEqualTo(480));
    });

    testWidgets('a failed read says so and offers to try again', (tester) async {
      when(api.getPushSettings()).thenThrow({'error': 'unavailable'});
      await pump(tester, {'feature-yourCoach': 'on'});
      go(tester, '/profile/settings/notifications');
      await tester.pumpTimes();

      expect(find.text("Your notification settings didn't make it here."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

class _FakeClient implements PushClient {
  final calls = <String>[];
  final newTokens = StreamController<String>.broadcast();
  final arrivals = StreamController<({Push push, String? title})>.broadcast();
  final taps = StreamController<Push>.broadcast();
  final pending = <Push>[];

  /// Holds [createChannels] until completed, when set.
  Completer<void>? channelsMade;

  /// Holds [start] until completed, when set.
  Completer<void>? tokenMade;

  @override
  Stream<String> get tokens => newTokens.stream;

  @override
  Stream<({Push push, String? title})> get arrived => arrivals.stream;

  @override
  Stream<Push> get opened => taps.stream;

  @override
  Future<String?> start() async {
    calls.add('start');
    await tokenMade?.future;
    return 'fcm-1';
  }

  @override
  Future<bool> stop() async {
    calls.add('stop');
    return true;
  }

  @override
  Future<Push?> launchedBy() async => null;

  @override
  Future<List<Push>> takePending() async {
    final taken = [...pending];
    pending.clear();
    return taken;
  }

  @override
  Future<void> createChannels({required String comments, required String messages, required String coaching}) async {
    calls.add('channels $comments $messages $coaching');
    await channelsMade?.future;
  }

  @override
  Future<void> deleteChannels() async => calls.add('delete channels');

  @override
  Future<void> show(Push push, {required String title}) async => calls.add('show ${push.topic} $title');

  @override
  Future<bool> askPermission({Analytics? analytics}) async {
    calls.add('ask');
    return true;
  }
}
