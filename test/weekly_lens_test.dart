import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// The weekly sets card on the profile (#341): sets and sessions a week, by
/// movement pattern or by muscle group. Baseline, so no offer and no switch.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 7);
  // inside the eight weeks whatever the first day of the week is
  final weeksAgo = DateTime(now.year, now.month, now.day - 21, 7);

  LensSets row(
    String workout,
    DateTime start, {
    List<String> patterns = const [],
    String? muscles,
    Target target = .other,
    int sets = 3,
  }) {
    return (
      workoutId: workout,
      exerciseId: 'e1',
      start: start,
      movement: Movement.fromJson({'groups': patterns}),
      muscles: switch (muscles) {
        String json => MuscleTagging.fromJson(jsonDecode(json)),
        null => MuscleTagging.empty(),
      },
      target: target,
      sets: sets,
    );
  }

  const chestAndArms = '{"primary": {"groups": ["chest"]}, "secondary": {"groups": ["arms"]}}';

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    required List<LensSets> rows,
    bool history = true,
    Size size = const Size(1200, 2400),
  }) async {
    SharedPreferences.setMockInitialValues(pastOnboarding());
    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => history ? WorkoutAggregation.dummy() : WorkoutAggregation.empty());
    when(db.getLensSets(any, any, userId: anyNamed('userId'))).thenAnswer((_) async => rows);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
  }

  Finder card() => find.byKey(AppKeys.lensCard, skipOffstage: false);
  Finder inCard(String text) => find.descendant(of: card(), matching: find.text(text, skipOffstage: false));

  testWidgets('counts a week\'s sets and sessions by pattern, the most trained first', (tester) async {
    await pumpProfile(
      tester,
      rows: [
        row('w1', today, patterns: ['horizontal_press'], sets: 4),
        row('w1', today, patterns: ['horizontal_row'], sets: 2),
        row('w0', weeksAgo, patterns: ['horizontal_row'], sets: 5),
      ],
      // a phone's single column, where the order is top to bottom
      size: const Size(400, 2400),
    );

    expect(card(), findsOneWidget);
    expect(inCard('Horizontal Press'), findsOneWidget);
    expect(inCard('4 sets in 1 session this week'), findsOneWidget);
    expect(inCard('2 sets in 1 session this week'), findsOneWidget);
    expect(
      tester.getTopLeft(inCard('Horizontal Press')).dy,
      lessThan(tester.getTopLeft(inCard('Horizontal Row')).dy),
    );
  });

  testWidgets('by muscle, a secondary muscle counts half a set and shows whole numbers', (tester) async {
    await pumpProfile(
      tester,
      rows: [
        row('w1', today, muscles: chestAndArms, sets: 3),
        // a custom exercise nobody tagged falls to its target's group
        row('w1', today, target: .back, sets: 2),
      ],
    );

    await tester.ensureVisible(inCard('Muscles'));
    await tester.tap(inCard('Muscles'));
    await tester.pumpTimes();

    expect(inCard('3 sets in 1 session this week'), findsOneWidget);
    // 1.5 sets of arms reads 1, rounded down as a goal reads it (#344): no
    // decimal reaches the screen, and never a set more than was done
    expect(inCard('2 sets in 1 session this week'), findsOneWidget);
    expect(inCard('1 set in 1 session this week'), findsOneWidget);
    expect(find.descendant(of: card(), matching: find.textContaining('.5', skipOffstage: false)), findsNothing);
  });

  testWidgets('a pattern trained only in earlier weeks says so for this one', (tester) async {
    await pumpProfile(
      tester,
      rows: [
        row('w0', weeksAgo, patterns: ['hip_hinge_stifflegged']),
      ],
    );

    expect(inCard('None this week'), findsOneWidget);
  });

  testWidgets('with no patterns among the sets, it points at the muscles', (tester) async {
    await pumpProfile(tester, rows: [row('w1', today, target: .chest)]);

    expect(
      inCard('None of the last eight weeks\' exercises has a movement pattern. Muscles counts them all.'),
      findsOneWidget,
    );
  });

  testWidgets('folds after six lines, and unfolds on request', (tester) async {
    final patterns = ['calf_raise', 'chest_dip', 'chest_fly', 'core_bracing', 'forearm', 'front_raise', 'shrug'];
    await pumpProfile(
      tester,
      rows: [
        for (final pattern in patterns) row('w1', today, patterns: [pattern]),
      ],
    );

    expect(inCard('Show all 7'), findsOneWidget);
    expect(inCard('3 sets in 1 session this week'), findsNWidgets(6));

    await tester.ensureVisible(find.byKey(AppKeys.lensShowAll));
    await tester.tapByKey(AppKeys.lensShowAll);
    await tester.pumpTimes();

    expect(inCard('3 sets in 1 session this week'), findsNWidgets(7));
    expect(inCard('Show fewer'), findsOneWidget);
  });

  testWidgets('is absent with nothing logged', (tester) async {
    await pumpProfile(tester, rows: const [], history: false);

    expect(card(), findsNothing);
  });

  testWidgets('a line reads its weeks to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpProfile(
      tester,
      rows: [
        row('w1', today, patterns: ['horizontal_press'], sets: 4),
      ],
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'^Horizontal Press\. 4 sets in 1 session this week\. Week by week: 0, 0, 0, 0, 0, 0, 0, 4$'),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
