// The exercise detail page's History tab (lib/presentation/routes/exercises/
// history.dart, a `part of` file reached only through the real
// ExerciseDetailPage — there is no public class to instantiate directly).
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'support/exercise_detail_test_helpers.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  testWidgets('no history yet renders the empty state', (tester) async {
    await pumpExerciseDetail(tester, bench, initialTab: 'history');
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    expect(find.text(l.emptyExerciseHistoryTitle), findsOneWidget);
    expect(find.text(l.emptyExerciseHistoryBody), findsOneWidget);
  });

  testWidgets('a failed lookup renders the error state', (tester) async {
    final state = await buildExerciseDetailState();
    when(
      state.exerciseService.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
    ).thenThrow(StateError('offline'));

    await pumpExerciseDetail(tester, bench, initialTab: 'history', state: state);
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    expect(find.text(l.errorExerciseHistoryTitle), findsOneWidget);
  });

  testWidgets('logged sets render as cards, newest first, and tapping one opens its workout', (tester) async {
    final state = await buildExerciseDetailState();
    final newer = TestExerciseAct(
      workoutId: 'w-newer',
      workoutName: 'Push Day',
      start: DateTime(2024, 6, 10, 9),
      sets: [ExerciseSet(bench, weight: 100.0, reps: 5)],
    );
    final older = TestExerciseAct(
      workoutId: 'w-older',
      workoutName: 'Pull Day',
      start: DateTime(2024, 6, 3, 9),
      sets: [ExerciseSet(bench, weight: 90.0, reps: 8)],
    );
    when(
      state.exerciseService.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
    ).thenAnswer((_) async => [older, newer]);

    String? tapped;
    await pumpExerciseDetail(
      tester,
      bench,
      initialTab: 'history',
      state: state,
      onTapWorkout: (id) async => tapped = id,
    );
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsOneWidget);
    // sorted newest first: "Push Day" (Jun 10) precedes "Push Day (last week)"
    final positions = tester.getTopLeft(find.text('Push Day')).dy;
    final olderPosition = tester.getTopLeft(find.text('Pull Day')).dy;
    expect(positions, lessThan(olderPosition));

    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('x 5')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('x 8')),
      findsOneWidget,
    );

    await tester.tap(find.text('Pull Day'));
    await tester.pumpAndSettle();
    expect(tapped, 'w-older');
  });

  testWidgets('an edit elsewhere (Workouts notifying) re-runs the query', (tester) async {
    final state = await buildExerciseDetailState();
    var calls = 0;
    when(
      state.exerciseService.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
    ).thenAnswer((_) async {
      calls++;
      return <ExerciseAct>[];
    });

    await pumpExerciseDetail(tester, bench, initialTab: 'history', state: state);
    await tester.pumpAndSettle();
    expect(calls, 1);

    state.workouts.notifyListeners();
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('bodyweight sets with no added weight read as reps only', (tester) async {
    final pushUp = Exercise(name: 'Push Up', category: .weightedBodyWeight, target: .chest);
    final state = await buildExerciseDetailState();
    when(
      state.exerciseService.getExerciseHistory(any, any, pageSize: anyNamed('pageSize'), anchor: anyNamed('anchor')),
    ).thenAnswer(
      (_) async => [
        TestExerciseAct(
          workoutId: 'w1',
          start: DateTime(2024, 6, 10),
          sets: [ExerciseSet(pushUp, reps: 12)],
        ),
      ],
    );

    await pumpExerciseDetail(tester, pushUp, initialTab: 'history', state: state);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('12 x')),
      findsOneWidget,
    );
  });
}
