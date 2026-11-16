import 'dart:math';

import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/muscle_family.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Muscle families by colour (#617): the day's colours in the calendar, with
/// their key, the filter's chips and the compact card's line — and the names
/// always beside them.
void main() {
  Exercise exercise(String id, String target, List<String> primary) {
    return Exercise.fromJson({
      'id': id,
      'name': id,
      'category': 'Barbell',
      'target': target,
      'muscles': {
        'primary': {'ids': <String>[], 'groups': primary},
      },
    });
  }

  final bench = exercise('bench', 'Chest', ['chest']);
  final squat = exercise('squat', 'Legs', ['legs', 'glutes']);
  final curl = exercise('curl', 'Arms', ['arms']);

  final now = DateTime(2026, 11, 20, 12);
  void testColours(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) => withClock(Clock.fixed(now), () => body(tester)));
  }

  Workout finished(List<(Exercise, int)> exercises, DateTime start) {
    final workout = Workout(name: 'Session')..start = start;
    for (final (exercise, sets) in exercises) {
      workout.add(exercise);
      for (var i = 1; i < sets; i++) {
        workout.last.add(workout.last.first.copy());
      }
    }
    workout.completeAllSets();
    return workout..finish(start.add(const Duration(hours: 1)));
  }

  // more lower-body sets than chest, a little arms
  final session = finished([(bench, 2), (squat, 4), (curl, 1)], DateTime(2026, 11, 5, 9));

  Future<void> pumpApp(WidgetTester tester, {Map<String, Object> stored = const {}}) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...stored});
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [session]);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat, curl]));
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
    await Exercises.of(tester.element(find.byType(HistoryPage))).init();
    await tester.pumpTimes();
  }

  List<MuscleFamily> dotsIn(WidgetTester tester, Finder within) {
    return tester
        .widgetList<FamilyDot>(find.descendant(of: within, matching: find.byType(FamilyDot)))
        .map((dot) => dot.family)
        .toList();
  }

  testColours('a day wears its families busiest first, and says them by name (#617)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    Preferences.of(tester.element(find.byType(HistoryPage))).setHistoryView(.calendar);
    await tester.pumpTimes();

    final label = '${DateFormat.yMMMMEEEEd('en').format(session.start)}, edit workout';
    final day = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
    expect(dotsIn(tester, day), [MuscleFamily.lowerBody, MuscleFamily.chest, MuscleFamily.arms]);
    expect(tester.widget<Semantics>(day).properties.value, 'Lower body, Chest, Arms');
    // and the key to the colours, every family by name
    expect(find.byType(FamilyLegend), findsOneWidget);
    expect(find.text('Lower body'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testColours('the filter\'s chips and the compact card wear the same colours (#617)', (tester) async {
    await pumpApp(
      tester,
      stored: {'screen-historyDensity': 'compact', 'screen-historyDensity-at': now.toUtc().toIso8601String()},
    );
    final context = tester.element(find.byType(HistoryPage));
    HistoryFilter.of(context).toggle(.glutes);
    await tester.pumpTimes();

    expect(dotsIn(tester, find.byKey(AppKeys.historyFilterChips)), [MuscleFamily.lowerBody]);
    final line = find.byKey(AppKeys.compactWorkoutGroups(session.id));
    expect(dotsIn(tester, line), [
      MuscleFamily.chest,
      MuscleFamily.arms,
      MuscleFamily.lowerBody,
      MuscleFamily.lowerBody,
    ]);
    // read out as names, the dots left out
    expect(tester.widget<Text>(line).semanticsLabel, 'Chest, Arms, Glutes, Legs');
    expect(tester.takeException(), isNull);
  });

  test('every family holds 3:1 against every preset\'s ground, surface and fill (#617)', () {
    double contrast(Color one, Color two) {
      final (a, b) = (one.computeLuminance(), two.computeLuminance());
      return (max(a, b) + 0.05) / (min(a, b) + 0.05);
    }

    for (final preset in Preset.values) {
      for (final tokens in [preset.light, preset.dark]) {
        for (final family in MuscleFamily.values) {
          final color = muscleFamilyColor(family, tokens.brightness);
          for (final ground in [tokens.ground, tokens.surface, tokens.fill]) {
            expect(
              contrast(color, ground),
              greaterThanOrEqualTo(3.0),
              reason: '$family on $preset ${tokens.brightness}',
            );
          }
        }
      }
    }
  });

  test('every family has a colour in each brightness, and the two differ', () {
    for (final family in MuscleFamily.values) {
      expect(muscleFamilyColor(family, Brightness.light), isNot(muscleFamilyColor(family, Brightness.dark)));
    }
  });
}
