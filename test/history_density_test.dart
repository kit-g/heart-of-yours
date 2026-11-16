import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// History's compact cards (#611): the choice of density, and what a compact
/// card carries in place of the exercise list.
void main() {
  final bench = Exercise.fromJson({
    'id': 'bench',
    'name': 'Bench Press',
    'category': 'Barbell',
    'target': 'Chest',
    'muscles': {
      'primary': {
        'ids': <String>[],
        'groups': ['chest'],
      },
      'secondary': {
        'ids': <String>[],
        'groups': ['arms'],
      },
    },
  });
  final squat = Exercise.fromJson({
    'id': 'squat',
    'name': 'Squat',
    'category': 'Barbell',
    'target': 'Legs',
    'muscles': {
      'primary': {
        'ids': <String>[],
        'groups': ['legs'],
      },
    },
  });
  final swim = Exercise.fromJson({'id': 'swim', 'name': 'Swimming', 'category': 'Cardio', 'target': 'Cardio'});

  final now = DateTime(2026, 11, 20, 12);
  void testDensity(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) => withClock(Clock.fixed(now), () => body(tester)));
  }

  Workout finished(String name, List<Exercise> exercises, DateTime start) {
    final workout = Workout(name: name)..start = start;
    for (final exercise in exercises) {
      workout.add(exercise);
    }
    workout.completeAllSets();
    return workout..finish(start.add(const Duration(hours: 1)));
  }

  // squat before bench: the line reads head to foot, not in workout order
  final mixed = finished('Upper and lower', [squat, bench], DateTime(2026, 11, 5, 9));
  final swimming = finished('Pool', [swim], DateTime(2026, 11, 6, 9));
  final both = finished('Squat then swim', [squat, swim], DateTime(2026, 11, 7, 9));

  Future<void> pumpApp(WidgetTester tester, {required Size size, required bool compact}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      if (compact) 'screen-historyDensity': 'compact',
      if (compact) 'screen-historyDensity-at': now.toUtc().toIso8601String(),
    });
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [mixed, swimming, both]);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat, swim]));
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(mockUser: MockUser(uid: 'u1', isAnonymous: true), signedIn: true),
      settle: false,
    );
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
  }

  testDensity('History keeps its full cards until compact is chosen (#611)', (tester) async {
    await pumpApp(tester, size: const Size(390, 844), compact: false);
    expect(find.byKey(AppKeys.compactWorkout(mixed.id)), findsNothing);
    expect(find.textContaining('Bench Press'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  String groupsOf(WidgetTester tester, Workout workout) {
    return tester.widget<Text>(find.byKey(AppKeys.compactWorkoutGroups(workout.id))).semanticsLabel!;
  }

  testDensity('until the library is read, the line waits rather than guess (#611)', (tester) async {
    await pumpApp(tester, size: const Size(390, 844), compact: true);
    expect(groupsOf(tester, mixed), isEmpty);

    await Exercises.of(tester.element(find.byType(HistoryPage))).init();
    await tester.pumpTimes();
    expect(groupsOf(tester, mixed), 'Chest, Legs');
  });

  // phone; tablet master pane; a single pane wider than a readable line
  for (final size in [const Size(390, 844), const Size(1194, 834), const Size(580, 900)]) {
    testDensity('a compact card names what the session trained, in place of its exercises, at $size (#611)', (
      tester,
    ) async {
      await pumpApp(tester, size: size, compact: true);
      await Exercises.of(tester.element(find.byType(HistoryPage))).init();
      await tester.pumpTimes();

      final card = find.byKey(AppKeys.compactWorkout(mixed.id));
      expect(card, findsOneWidget);
      // no exercise lines, and the groups head to foot: chest before legs,
      // and no arms, which bench works only secondarily
      expect(find.textContaining('Bench Press'), findsNothing);
      expect(groupsOf(tester, mixed), 'Chest, Legs');
      // an exercise no group answers to says what it was, alone or after the groups
      expect(groupsOf(tester, swimming), 'Swimming');
      expect(groupsOf(tester, both), 'Legs, Swimming');
      // the numbers are the day, the time and the volume — no best set
      // standing in for it, and no separator left hanging without one
      expect(find.text('Fri, Nov 6 · 1 h'), findsOneWidget);
      // the menu is still there, on each card
      expect(find.byTooltip('More options'), findsNWidgets(3));
      // and a wide pane does not stretch it
      expect(tester.getSize(card).width, lessThanOrEqualTo(readableWidth + 32));
      expect(tester.takeException(), isNull);
    });
  }

  testDensity('a compact card opens its workout, as a full one does (#611)', (tester) async {
    await pumpApp(tester, size: const Size(1194, 834), compact: true);
    await tester.tap(find.byKey(AppKeys.compactWorkout(mixed.id)));
    await tester.pumpTimes();
    expect(find.byType(WorkoutEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
