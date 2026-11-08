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

import 'mocks.mocks.dart';
import 'support/harness.dart';

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

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
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
