import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';

import '../test/mocks.mocks.dart';
import '../test/support/harness.dart';

/// Which navigation frame the app is showing.
///
/// Runs on Firebase Test Lab, which is where the Android tablet coverage comes
/// from — nobody on the team has one. Deps are mocked so the result depends on
/// the device's screen and nothing else.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('responsive frame', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockCdn cdn;
    late TestAppHarness harness;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      db = MockLocalDatabase();
      api = MockApi();
      cdn = MockCdn();
      harness = const TestAppHarness();

      when(
        db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
      ).thenAnswer((_) async => WorkoutAggregation.empty());
      when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
      when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
      when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
      when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);
      // a MockWorkout here spawns timers that never settle
      when(db.getActiveWorkout(any)).thenAnswer((_) async => null);
    });

    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', email: 'u1@test'), signedIn: true),
        settle: false,
      );
    }

    testWidgets('a phone gets the bottom bar, not the rail', (tester) async {
      await pumpAt(tester, const Size(390, 844));

      expect(find.byKey(AppKeys.navigationRail), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('a tablet gets the rail, not the bottom bar', (tester) async {
      await pumpAt(tester, const Size(1194, 834));

      expect(find.byKey(AppKeys.navigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    // 600 is the breakpoint; a device sitting on it counts as wide
    testWidgets('the breakpoint itself is wide', (tester) async {
      await pumpAt(tester, const Size(600, 900));

      expect(find.byKey(AppKeys.navigationRail), findsOneWidget);
    });
  });
}
