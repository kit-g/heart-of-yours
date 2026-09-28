// _CupertinoExerciseDetailPage (lib/presentation/routes/exercises/
// cupertino.dart) — the iOS/macOS-styled variant of the whole detail page: a
// CupertinoSlidingSegmentedControl instead of a TabBar, a PageView instead of
// a TabBarView. Reached by overriding Theme.of(context).platform, as
// `ExerciseDetailPage` itself dispatches on it.
//
// Every test wraps its body in try/finally to reset
// debugDefaultTargetPlatformOverride itself: flutter_test's end-of-test
// invariant check runs before addTearDown callbacks fire, so resetting there
// (the more usual pattern in this suite) is too late for this one flag.
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'support/exercise_detail_test_helpers.dart';
import 'support/finders.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final mine = Exercise(name: 'My Curl', category: .dumbbell, target: .arms, isMine: true);

  testWidgets('renders a segmented control with one segment per section, no About', (tester) async {
    try {
      await pumpExerciseDetail(tester, bench, initialTab: 'history', platform: TargetPlatform.iOS);
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is CupertinoSlidingSegmentedControl), findsOneWidget);
      final l = L.of(tester.element(find.byType(Scaffold).first));
      expect(find.text(l.history), findsOneWidget);
      expect(find.text(l.charts), findsOneWidget);
      expect(find.text(l.records), findsOneWidget);
      expect(find.text(l.about), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tapping a segment pages to that section', (tester) async {
    try {
      final state = await buildExerciseDetailState();
      when(state.exerciseService.getRecord(any, any)).thenAnswer(
        (_) async => {
          'heaviest': {'weight': 100.0, 'reps': 5, 'at': '2024-06-01T00:00:00.000Z', 'workoutId': 'w1'},
        },
      );

      await pumpExerciseDetail(tester, bench, initialTab: 'history', state: state, platform: TargetPlatform.iOS);
      await tester.pumpAndSettle();

      final l = L.of(tester.element(find.byType(Scaffold).first));
      expect(find.text(l.emptyExerciseHistoryTitle), findsOneWidget); // empty History tab

      await tester.tap(find.text(l.records));
      await tester.pumpAndSettle();

      expect(find.text(l.maxWeight.toUpperCase()), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a library exercise offers Share; the user\'s own offers the exercise menu', (tester) async {
    try {
      await pumpExerciseDetail(tester, bench, initialTab: 'history', platform: TargetPlatform.iOS);
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(Scaffold).first));
      expect(find.tooltip(l.share), findsOneWidget);
      expect(find.tooltip(l.exerciseOptions), findsNothing);

      await pumpExerciseDetail(tester, mine, initialTab: 'history', platform: TargetPlatform.iOS);
      await tester.pumpAndSettle();
      expect(find.tooltip(l.exerciseOptions), findsOneWidget);
      expect(find.tooltip(l.share), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the add-to-workout action only shows once a workout is active, and calls back', (tester) async {
    try {
      final state = await buildExerciseDetailState();

      Exercise? added;
      await pumpExerciseDetail(
        tester,
        bench,
        initialTab: 'history',
        state: state,
        platform: TargetPlatform.iOS,
        onAddToWorkout: (exercise) async => added = exercise,
      );
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(Scaffold).first));
      expect(find.tooltip(l.addToActiveWorkout), findsNothing);

      await state.workouts.startWorkout(source: .blank);
      await tester.pumpAndSettle();

      expect(find.tooltip(l.addToActiveWorkout), findsOneWidget);
      await tester.tap(find.tooltip(l.addToActiveWorkout));
      await tester.pumpAndSettle();
      expect(added, bench);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
