import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

/// The Coaching space (#566): there only with Coach people on, for an account
/// that may coach; otherwise the app is as it was before coaching was built.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  /// The account as the server answers it, with or without the coach
  /// entitlement.
  void account({required bool coach}) {
    when(api.registerAccount(any)).thenAnswer((invocation) async {
      final user = invocation.positionalArguments.single as User;
      return User(
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        settings: user.settings,
        entitlements: [if (coach) 'coach'],
      );
    });
  }

  final share = _FakeShare();
  setUpAll(() => SharePlatform.instance = share);

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer((_) async => (items: <Invitation>[], cursor: null));
    share.shared.clear();
  });

  /// A phone by default. Settings is swept wide, as the a11y harness does:
  /// under the test font its pickers overflow a phone's width.
  Future<void> pump(WidgetTester tester, Map<String, Object> prefs, {bool wide = false}) async {
    tester.view.physicalSize = wide ? const Size(1200, 2400) : const Size(1179, 2556);
    tester.view.devicePixelRatio = wide ? 1 : 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
  }

  testWidgets('off, there is no way in, and nothing is read from the server', (tester) async {
    account(coach: true);
    await pump(tester, {});

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byKey(AppKeys.coachingButton), findsNothing);
    verifyNever(api.getConnections());
  });

  testWidgets('on, but for an account that may not coach, it is still not there', (tester) async {
    account(coach: false);
    await pump(tester, {'feature-coachPeople': 'on'});

    expect(find.byKey(AppKeys.coachingButton), findsNothing);
    verifyNever(api.getConnections());
  });

  testWidgets('on for a coach: the button opens the space, and the way back returns to Profile', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on'});

    verify(api.getConnections()).called(1);
    await tester.tapByKey(AppKeys.coachingButton);
    await tester.pumpTimes();

    expect(find.byType(ClientsPage), findsOneWidget);
    expect(find.byKey(AppKeys.profileStack), findsNothing, reason: "the space's tabs replace the app's");
    final context = tester.element(find.byType(ClientsPage));
    expect(Preferences.of(context).inCoachingSpace, isTrue);

    await tester.tapByKey(AppKeys.coachingMessagesStack);
    await tester.pumpTimes();
    expect(find.byType(CoachMessagesPage), findsOneWidget);

    await tester.tapByKey(AppKeys.coachingYourTraining);
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(Preferences.of(tester.element(find.byType(ProfilePage))).inCoachingSpace, isFalse);
  });

  testWidgets('the app opens in the space it was left in', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

    expect(find.byType(ClientsPage), findsOneWidget);
  });

  testWidgets('left in the space but switched off since, the app opens on Profile', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'off', 'coachingSpace': true});

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ClientsPage), findsNothing);
  });

  testWidgets('switched off from inside, the space goes', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
    expect(find.byType(ClientsPage), findsOneWidget);

    Preferences.of(tester.element(find.byType(ClientsPage))).setFeature(.coachPeople, on: false);
    await tester.pumpTimes();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ClientsPage), findsNothing);
  });

  testWidgets("a workout of the user's own still going is one line, and the way back to it", (tester) async {
    account(coach: true);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    // wide: under the test font the Workout tab's header overflows a phone
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
    expect(find.byKey(AppKeys.coachingBackToWorkout), findsNothing);

    await Workouts.of(tester.element(find.byType(ClientsPage))).startWorkout(source: .blank, name: 'Push');
    await tester.pumpTimes();
    expect(find.text('Your workout is still going'), findsOneWidget);

    await tester.tapByKey(AppKeys.coachingBackToWorkout);
    await tester.pumpTimes();
    expect(find.byType(ClientsPage), findsNothing, reason: 'back in their own space');
    expect(find.byKey(AppKeys.workoutStack), findsOneWidget, reason: 'on the Workout tab, the sheet over it');
    expect(Preferences.of(tester.element(find.byType(Scaffold).first)).inCoachingSpace, isFalse);
  });

  group('inviting someone (#553)', () {
    Invitation invitation({String? token, String status = 'pending'}) => Invitation(
      id: 'i1',
      name: 'Biscuit',
      status: status,
      role: 'COACH',
      domain: 'fitness',
      expiresAt: DateTime.utc(2026, 11, 15),
      createdAt: DateTime.utc(2026, 11, 8),
      token: token,
    );

    testWidgets('a name makes a link, which goes to the share sheet and waits on Clients', (tester) async {
      account(coach: true);
      when(api.createInvitation(any, programId: anyNamed('programId')))
          .thenAnswer((_) async => invitation(token: 'abc'));
      // wide: under the test font the dialog's buttons overflow a phone
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      await tester.tapByKey(AppKeys.coachingInvite);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingMakeLink), findsNothing, reason: 'no one to make it for yet');
      await tester.enterText(find.byKey(AppKeys.coachingInviteName), '  Biscuit ');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingMakeLink);
      await tester.pumpTimes();

      verify(api.createInvitation('Biscuit', programId: null)).called(1);
      expect(share.shared.single.text, contains('/invite.html?t=abc'));
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsOneWidget);
      expect(find.text('Waiting to hear back'), findsOneWidget);
    });

    testWidgets("the beta's refusal says so, and shares nothing", (tester) async {
      account(coach: true);
      when(api.createInvitation(any, programId: anyNamed('programId'))).thenAnswer(
        (_) async => throw {'code': 'coaching_beta'},
      );
      // wide: under the test font the dialog's buttons overflow a phone
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      await tester.tapByKey(AppKeys.coachingInvite);
      await tester.pumpTimes();
      await tester.enterText(find.byKey(AppKeys.coachingInviteName), 'Biscuit');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingMakeLink);
      await tester.pumpTimes();

      expect(find.text('Inviting is open to testers for now.'), findsOneWidget);
      expect(share.shared, isEmpty);
    });

    testWidgets('a waiting invitation can be cancelled from its menu', (tester) async {
      account(coach: true);
      when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (items: [invitation()], cursor: null),
      );
      when(api.cancelInvitation('i1')).thenAnswer((_) async {});
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpTimes();
      await tester.tap(find.text('Cancel invitation'));
      await tester.pumpTimes();

      verify(api.cancelInvitation('i1')).called(1);
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsNothing);
      expect(find.byKey(AppKeys.coachingInvite), findsOneWidget, reason: 'back to the empty state, and its button');
    });
  });

  group('Settings › Features', () {
    Future<void> openFeatures(WidgetTester tester) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/profile/settings/features');
      await tester.pumpTimes();
    }

    testWidgets("Coach people's switch is there only for an account that may coach", (tester) async {
      account(coach: false);
      await pump(tester, {'feature-recaps': 'off'}, wide: true);
      await openFeatures(tester);
      expect(find.text('Coach people'), findsNothing);
    });

    testWidgets("for a coach, Coach people's switch is there; Your coach's waits for an invitation", (tester) async {
      account(coach: true);
      // the server's copy of the account, entitlements and all, arrives here
      // through settings sync, which an answer to any feature sets off: the
      // sign-in's own registration waits on startup a widget test never ends
      await pump(tester, {'feature-recaps': 'off'}, wide: true);
      await openFeatures(tester);
      await tester.scrollUntilVisible(find.text('Coach people'), 200);
      expect(find.text('Coach people'), findsOneWidget);
      expect(find.text('Your coach'), findsNothing);
    });

    testWidgets("once asked about, Your coach's switch is there", (tester) async {
      account(coach: false);
      await pump(tester, {'feature-yourCoach': 'off'}, wide: true);
      await openFeatures(tester);
      await tester.scrollUntilVisible(find.text('Your coach'), 200);
      expect(find.text('Your coach'), findsOneWidget);
    });
  });
}
