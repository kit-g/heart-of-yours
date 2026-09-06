import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/onboarding/onboarding.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A Firebase project with the anonymous provider switched off answers every
/// anonymous sign-in with `admin-restricted-operation`.
class _NoAnonymousSignIn extends MockFirebaseAuth {
  new() : super(signedIn: false);

  @override
  Future<UserCredential> signInAnonymously() {
    throw FirebaseAuthException(code: 'admin-restricted-operation');
  }
}

void main() {
  group('Navigation and routing (HeartRouter)', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockCdn cdn;
    late TestAppHarness harness;

    setUp(
      () {
        // Prevent SharedPreferences.getInstance() from throwing a MissingPluginException
        SharedPreferences.setMockInitialValues(pastOnboarding());

        db = MockLocalDatabase();
        api = MockApi();
        cdn = MockCdn();
        harness = const TestAppHarness();

        // Stats.init is invoked by ProfilePage's after-first-layout path; stub DB calls used by Stats
        when(
          db.getWorkoutSummary(
            weeksBack: anyNamed('weeksBack'),
            userId: anyNamed('userId'),
          ),
        ).thenAnswer((_) async => WorkoutAggregation.empty());
        when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

        when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
        when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
        when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
        when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);

        when(db.getActiveWorkout(any)).thenAnswer((_) async => null);

        when(
          db.getWorkoutGallery(userId: anyNamed('userId')),
        ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));

        when(
          api.getWorkoutGallery(cursor: anyNamed('cursor')),
        ).thenAnswer(
          (_) async => ProgressGalleryResponse.fromJson({}),
        );
      },
    );

    testWidgets('initial route: no user lands in the app as an anonymous session, on ProfilePage', (tester) async {
      // no sign-in gate on mobile: Auth replaces the missing user with an
      // anonymous one, and the profile's logout slot says so instead
      final firebase = MockFirebaseAuth(signedIn: false);
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
        settle: false,
      );
      await tester.pumpTimes();

      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byKey(AppKeys.noAccount), findsOneWidget);
      // nothing went to the server on the anonymous uid
      verifyNever(api.getExercises());
      verifyNever(api.getOwnExercises());
      verifyNever(api.registerAccount(any));
    });

    testWidgets('initial route: signed-in user lands on ProfilePage', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

      // the dashboard animates indefinitely, so pump a fixed number of frames
      // rather than settling
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
        settle: false,
      );

      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('deep link: goToExercise navigates to WorkoutPage', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);
      final router = HeartRouter();

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        router: router,
        hasLocalNotifications: false,
        settle: false,
      );

      // Ensure we're not already on the workout page (initial is Profile)
      expect(find.byType(ProfilePage), findsOneWidget);

      // Trigger the router helper
      router.goToExercise('bench-press');
      await tester.pumpTimes();

      expect(find.byType(WorkoutPage), findsOneWidget);
    });

    testWidgets('a device that cannot get a session at all falls back to LoginPage', (tester) async {
      // a first launch offline, or a Firebase project with the anonymous
      // provider switched off: the gate is the one page that can still act
      final firebase = _NoAnonymousSignIn();

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
      );

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the no-account dialog leads to LoginPage, and signing in leads back to ProfilePage', (tester) async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final router = HeartRouter();

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        router: router,
        hasLocalNotifications: false,
        settle: false,
      );
      await tester.pumpTimes();
      expect(find.byType(ProfilePage), findsOneWidget);

      // the login page is reached by name, from the dialog — never by redirect
      await tester.tapByKey(AppKeys.noAccount);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.noAccountLogIn);
      await tester.pumpTimes();

      expect(find.byType(LoginPage), findsOneWidget);

      // Sign in; Auth listens to userChanges and HeartApp wires onUserChange -> router.refresh()
      await firebase.signInWithEmailAndPassword(email: 'a@b.c', password: 'x');
      await tester.pumpTimes();

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byKey(AppKeys.noAccount), findsNothing);
    });

    testWidgets('cold-start deep link is never dropped on the profile page', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

      // A universal link opening the dead app: the platform reports the link
      // as the initial route, before the exercise catalog has loaded. The
      // redirect must park on the link until the catalog lands — bouncing to
      // `/exercises?from=…` instead used to loop with the top-level `from`
      // handler until go_router gave up and dumped the link on `/profile`.
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/exercises/Bench%20Press%20(Barbell)';
      addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      final bench = Exercise(name: 'Bench Press (Barbell)', category: .barbell, target: .chest);
      when(api.getExercises()).thenAnswer((_) async => [bench]);

      final router = HeartRouter();
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        router: router,
        hasLocalNotifications: false,
        settle: false,
      );
      await tester.pumpTimes();
      // App startup runs in Zone.root (see _initApp), whose futures starve
      // under the fake clock until the test body returns — the catalog can
      // never land here, so ride the redirect's own timeout out instead. What
      // matters is where the link ends up: on the exercise routes (parked,
      // resolved, or timed out to the list), never dropped on the profile.
      await tester.pump(const Duration(seconds: 11));

      final location = router.config.routerDelegate.currentConfiguration.uri.toString();
      expect(location, contains('exercises'));
      expect(find.byType(ProfilePage), findsNothing);
    });

    group('first-launch onboarding', () {
      /// A device that has never launched the app.
      setUp(() => SharedPreferences.setMockInitialValues({}));

      Future<void> pumpFreshInstall(WidgetTester tester, {FirebaseAuth? firebase}) async {
        await harness.pumpHeartApp(
          tester,
          db: db,
          api: api,
          cdn: cdn,
          firebaseAuth: firebase ?? MockFirebaseAuth(signedIn: false),
          hasLocalNotifications: false,
          settle: false,
        );
        await tester.pumpTimes();
      }

      testWidgets('a fresh install opens on the onboarding, not the app', (tester) async {
        await pumpFreshInstall(tester);

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.byType(ProfilePage), findsNothing);
        // a way out on the first screen already
        expect(find.byKey(AppKeys.onboardingSkip), findsOneWidget);
      });

      testWidgets('Skip lands in the app and is remembered', (tester) async {
        await pumpFreshInstall(tester);

        await tester.tapByKey(AppKeys.onboardingSkip);
        await tester.pumpTimes();

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(ProfilePage), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(Preferences.onboardingSeenKey), isTrue);
      });

      testWidgets('Next walks the three screens; Continue on the last lands in the app', (tester) async {
        await pumpFreshInstall(tester);

        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);
        expect(find.byKey(AppKeys.onboardingSkip), findsOneWidget);
        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);

        // the last screen trades Next for the two ways out
        expect(find.byKey(AppKeys.onboardingNext), findsNothing);
        expect(find.byKey(AppKeys.onboardingSkip), findsOneWidget);
        expect(find.byKey(AppKeys.onboardingSignIn), findsOneWidget);

        await tester.tapByKey(AppKeys.onboardingContinue);
        await tester.pumpTimes();

        expect(find.byType(ProfilePage), findsOneWidget);
        expect(find.byKey(AppKeys.noAccount), findsOneWidget);
      });

      testWidgets('Log in on the last screen goes to LoginPage, and is remembered too', (tester) async {
        await pumpFreshInstall(tester);

        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);
        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);
        await tester.tapByKey(AppKeys.onboardingSignIn);
        await tester.pumpTimes();

        expect(find.byType(LoginPage), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(Preferences.onboardingSeenKey), isTrue);
      });

      testWidgets('a device that has seen it opens straight into the app', (tester) async {
        SharedPreferences.setMockInitialValues(pastOnboarding());
        await pumpFreshInstall(tester);

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(ProfilePage), findsOneWidget);
      });

      testWidgets('an account never sees it, even on a device that has not', (tester) async {
        await pumpFreshInstall(
          tester,
          firebase: MockFirebaseAuth(
            mockUser: MockUser(uid: 'u1', email: 'u1@test'),
            signedIn: true,
          ),
        );

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(ProfilePage), findsOneWidget);
      });

      testWidgets('a deep link opening a fresh install is honoured after Skip', (tester) async {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/workout';
        addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
        final router = HeartRouter();

        await harness.pumpHeartApp(
          tester,
          db: db,
          api: api,
          cdn: cdn,
          firebaseAuth: MockFirebaseAuth(signedIn: false),
          router: router,
          hasLocalNotifications: false,
          settle: false,
        );
        await tester.pumpTimes();
        expect(find.byType(OnboardingPage), findsOneWidget);

        await tester.tapByKey(AppKeys.onboardingSkip);
        await tester.pumpTimes();

        expect(find.byType(WorkoutPage), findsOneWidget);
        expect(router.config.routerDelegate.currentConfiguration.uri.path, '/workout');
      });
    });

    testWidgets('bottom navigation: tapping items by AppKeys switches stacks', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
        settle: false,
      );

      // Initially on Profile
      expect(find.byType(ProfilePage), findsOneWidget);

      // Workout tab
      await tester.tapByKey(AppKeys.workoutStack);
      expect(find.byType(WorkoutPage), findsOneWidget);

      // History tab
      await tester.tapByKey(AppKeys.historyStack);
      expect(find.byType(HistoryPage), findsOneWidget);

      // Exercises tab
      await tester.tapByKey(AppKeys.exercisesStack);
      expect(find.byType(ExercisesPage), findsOneWidget);

      // Back to Profile
      await tester.tapByKey(AppKeys.profileStack);
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });
}
