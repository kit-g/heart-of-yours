import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A folding phone (#327): the window changes size in the hand, and the app
/// follows it live, the bar or the rail, without losing the workout going on.
/// Sizes are iPhone Duo's displays in points: closed and open.
void main() {
  const closed = Size(466, 678);
  const open = Size(669, 951);

  late MockLocalDatabase db;
  late MockApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues(pastOnboarding());
    db = MockLocalDatabase();
    api = MockApi();
    stubStartup(db, api);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
  });

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpTimes();
  }

  testWidgets('opening and closing it swaps the bar and the rail, and the workout goes on', (tester) async {
    tester.view.physicalSize = open;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.navigationRail), findsOneWidget);

    final workouts = Workouts.of(tester.element(find.byType(ProfilePage)));
    await workouts.startWorkout(source: .blank, name: 'Push');
    await tester.pumpTimes();
    final id = workouts.activeWorkout?.id;
    expect(id, isNotNull);
    final page = tester.element(find.byType(ProfilePage));

    await resize(tester, closed);
    expect(find.byKey(AppKeys.navigationRail), findsNothing);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.element(find.byType(ProfilePage)), same(page), reason: 'the same page, kept through the fold');

    await resize(tester, open);
    expect(find.byKey(AppKeys.navigationRail), findsOneWidget);
    expect(tester.element(find.byType(ProfilePage)), same(page));
    expect(workouts.activeWorkout?.id, id, reason: 'the same workout, still going');
  });
}
