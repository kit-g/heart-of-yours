// The exercise detail page's Records tab (lib/presentation/routes/exercises/
// records.dart) — PRs and lifetime totals for one exercise. Reached only
// through the real ExerciseDetailPage; the tab classes are private to the
// `part of` library.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'support/exercise_detail_test_helpers.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  testWidgets('never performed renders the empty state', (tester) async {
    await pumpExerciseDetail(tester, bench, initialTab: 'records');
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    expect(find.text(l.emptyExerciseHistoryTitle), findsOneWidget);
  });

  testWidgets('a failed lookup renders the error state', (tester) async {
    final state = await buildExerciseDetailState();
    when(state.exerciseService.getRecord(any, any)).thenThrow(StateError('offline'));

    await pumpExerciseDetail(tester, bench, initialTab: 'records', state: state);
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    expect(find.text(l.errorExerciseHistoryTitle), findsOneWidget);
  });

  testWidgets('records render as tiles, rep maxes, and lifetime totals; tapping a tile opens its workout', (
    tester,
  ) async {
    final state = await buildExerciseDetailState();
    when(state.exerciseService.getRecord(any, any)).thenAnswer(
      (_) async => {
        'heaviest': {'weight': 100.0, 'reps': 5, 'at': '2024-06-01T00:00:00.000Z', 'workoutId': 'w-heaviest'},
        'oneRepMax': {
          'value': 120.0,
          'weight': 100.0,
          'reps': 5,
          'at': '2024-06-01T00:00:00.000Z',
          'workoutId': 'w-1rm',
        },
        'mostReps': {'reps': 12, 'weight': 60.0, 'at': '2024-05-01T00:00:00.000Z', 'workoutId': 'w-reps'},
        'repMaxes': [
          {'reps': 1, 'weight': 120.0, 'at': '2024-06-01T00:00:00.000Z', 'workoutId': 'w-1rm'},
          {'reps': 5, 'weight': 100.0, 'at': '2024-06-01T00:00:00.000Z', 'workoutId': 'w-heaviest'},
        ],
        'sessions': 10,
        'totalVolume': 50000.0,
        'totalReps': 500,
        'firstAt': '2023-01-01T00:00:00.000Z',
      },
    );

    String? tapped;
    await pumpExerciseDetail(
      tester,
      bench,
      initialTab: 'records',
      state: state,
      onTapWorkout: (id) async => tapped = id,
      // wider than the default phone width: the test font's metrics run
      // wider than the app's for a couple of these lifetime rows, and a
      // narrow phone isn't the point of this test
      size: const Size(430, 900),
    );
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    // record tile labels render uppercased (see _RecordTile)
    expect(find.text(l.maxWeight.toUpperCase()), findsOneWidget);
    expect(find.text(l.estimatedOneRepMax.toUpperCase()), findsOneWidget);
    expect(find.text(l.mostReps.toUpperCase()), findsOneWidget);
    expect(find.text(l.repMaxes), findsOneWidget);
    expect(find.text(l.allTime), findsOneWidget);
    expect(find.text(l.sessions), findsOneWidget);
    expect(find.text(l.totalVolume), findsOneWidget);
    // one-rep max row's reps count, formatted through repMaxCount
    expect(find.text(l.repMaxCount(1)), findsOneWidget);
    expect(find.text(l.repMaxCount(5)), findsOneWidget);

    await tester.tap(find.text(l.maxWeight.toUpperCase()));
    await tester.pumpAndSettle();
    expect(tapped, 'w-heaviest');
  });

  testWidgets('an edit elsewhere (Workouts notifying) re-runs the query', (tester) async {
    final state = await buildExerciseDetailState();
    var calls = 0;
    when(state.exerciseService.getRecord(any, any)).thenAnswer((_) async {
      calls++;
      return null;
    });

    await pumpExerciseDetail(tester, bench, initialTab: 'records', state: state);
    await tester.pumpAndSettle();
    expect(calls, 1);

    state.workouts.notifyListeners();
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
