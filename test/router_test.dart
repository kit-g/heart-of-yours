import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  group('Navigation and routing (HeartRouter)', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockConfigApi configApi;
    late TestAppHarness harness;

    setUp(
      () {
        db = MockLocalDatabase();
        api = MockApi();
        configApi = MockConfigApi();
        harness = const TestAppHarness();

        // Stats.init is invoked by ProfilePage's after-first-layout path; stub DB calls used by Stats
        when(
          db.getWorkoutSummary(
            weeksBack: anyNamed('weeksBack'),
            userId: anyNamed('userId'),
          ),
        ).thenAnswer((_) async => WorkoutAggregation.empty());
        when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

        when(
          api.getWorkoutGallery(cursor: anyNamed('cursor')),
        ).thenAnswer(
          (_) async => ProgressGalleryResponse.fromJson({}),
        );
      },
    );

    testWidgets('initial route: signed-out user is redirected to LoginPage', (tester) async {
      final firebase = MockFirebaseAuth(signedIn: false);
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
      );

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('initial route: signed-in user lands on ProfilePage', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
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
        config: configApi,
        firebaseAuth: firebase,
        router: router,
        hasLocalNotifications: false,
      );

      // Ensure we're not already on the workout page (initial is Profile)
      expect(find.byType(ProfilePage), findsOneWidget);

      // Trigger the router helper
      router.goToExercise('bench-press');
      await pumpAndSettleSafe(tester);

      expect(find.byType(WorkoutPage), findsOneWidget);
    });

    testWidgets('router.refresh reacts to Auth user change: LoginPage -> ProfilePage', (tester) async {
      final firebase = MockFirebaseAuth(signedIn: false);
      final router = HeartRouter();

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        firebaseAuth: firebase,
        router: router,
        hasLocalNotifications: false,
      );

      expect(find.byType(LoginPage), findsOneWidget);

      // Sign in; Auth listens to userChanges and HeartApp wires onUserChange -> router.refresh()
      await firebase.signInWithEmailAndPassword(email: 'a@b.c', password: 'x');
      await pumpAndSettleSafe(tester);

      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('bottom navigation: tapping items by AppKeys switches stacks', (tester) async {
      final user = MockUser(uid: 'u1', email: 'u1@test');
      final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        firebaseAuth: firebase,
        hasLocalNotifications: false,
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
