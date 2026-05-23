import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  group(
    'Start new workout flow (keys only)',
    () {
      late MockLocalDatabase db;
      late MockApi api;
      late MockCdn configApi;
      late TestAppHarness harness;

      setUp(() {
        // Prevent SharedPreferences.getInstance() from throwing a MissingPluginException
        // which would halt the _initApp process and keep the CircularProgressIndicator spinning forever.
        SharedPreferences.setMockInitialValues({});

        db = MockLocalDatabase();
        api = MockApi();
        configApi = MockCdn();
        harness = const TestAppHarness();

        // Stubs to prevent crashes during initial profile render
        when(
          db.getWorkoutSummary(
            weeksBack: anyNamed('weeksBack'),
            userId: anyNamed('userId'),
          ),
        ).thenAnswer((_) async => WorkoutAggregation.empty());
        when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

        // Stubs to allow Exercises and Charts to finish initializing,
        // removing the CircularProgressIndicator from the Dashboard.
        when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
        when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
        when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
        when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);

        // Prevent Mockito from generating a MockWorkout which causes infinite timers
        when(db.getActiveWorkout(any)).thenAnswer((_) async => null);

        // Workouts.startWorkout will call local service startWorkout(workout, userId)
        when(db.startWorkout(any, any)).thenAnswer((_) async {});
      });

      testWidgets(
        'navigate to workout tab, start new workout, verify buttons by keys',
        (tester) async {
          // Signed-in user so the app lands on Profile and sets userId on providers
          final user = MockUser(uid: 'u1', email: 'u1@test');
          final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);

          await harness.pumpHeartApp(
            tester,
            db: db,
            api: api,
            cdn: configApi,
            firebaseAuth: firebase,
            hasLocalNotifications: false,
          );

          // 1) Go to workout stack by key
          await tester.tapByKey(AppKeys.workoutStack);
          await pumpAndSettleSafe(tester);

          // 2) Tap Start New Workout (key)
          await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);

          await pumpAndSettleSafe(tester);

          // 3) Verify we see all expected controls by keys
          expect(find.byKey(WorkoutDetailKeys.finishWorkout), findsOneWidget);
          expect(find.byKey(WorkoutDetailKeys.timer), findsOneWidget);
          expect(find.byKey(WorkoutDetailKeys.cancelWorkout), findsOneWidget);
          expect(find.byKey(WorkoutDetailKeys.addExercises), findsOneWidget);
        },
        skip: true,
      );
    },
  );
}
