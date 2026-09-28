// The exercise detail page's Charts tab (lib/presentation/routes/exercises/
// charts.dart) — one chart per metric relevant to the exercise's category,
// plus the per-chart "add to dashboard" toggle. Reached only through the real
// ExerciseDetailPage.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'support/exercise_detail_test_helpers.dart';
import 'support/finders.dart';

void main() {
  // .repsOnly keeps the tab to two charts (maxConsecutiveReps, totalReps)
  // instead of barbell's six, so tests only reason about a couple of rows.
  final pullUp = Exercise(name: 'Pull Up', category: .repsOnly, target: .back);

  testWidgets('with no data, only the first chart carries the empty hint', (tester) async {
    await pumpExerciseDetail(tester, pullUp, initialTab: 'charts');
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    // an empty chart shows only the illustration, never its title row (that
    // lives in ExerciseChart's "data" phase only) — so exactly one hint, and
    // neither metric's name, is on screen
    expect(find.text(l.emptyExerciseHistoryTitle), findsOneWidget);
    expect(find.text(l.maxRepsInSet), findsNothing);
    expect(find.text(l.totalReps), findsNothing);
  });

  testWidgets('data for one metric renders its timeline chart', (tester) async {
    final state = await buildExerciseDetailState();
    final now = DateTime(2024, 6, 1);
    when(
      state.exerciseService.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((invocation) async {
      final type = invocation.positionalArguments[1] as ChartPreferenceType;
      if (type != ChartPreferenceType.maxConsecutiveReps) return null;
      return [(8, now), (10, now.subtract(const Duration(days: 7)))];
    });

    await pumpExerciseDetail(tester, pullUp, initialTab: 'charts', state: state);
    await tester.pumpAndSettle();

    expect(find.byType(TimelineChart), findsOneWidget);
    final l = L.of(tester.element(find.byType(Scaffold).first));
    // the metric with data no longer shows the empty hint; the other still can't
    expect(find.text(l.emptyExerciseHistoryTitle), findsNothing);
  });

  testWidgets('the dashboard toggle adds and then removes the chart from the profile', (tester) async {
    final state = await buildExerciseDetailState();
    // the toggle lives in the chart's title row, which only ever renders once
    // the chart has reached its "data" phase (see ExerciseChart._dataChart) —
    // an empty chart shows just the illustration, no toggle at all
    final now = DateTime(2024, 6, 1);
    when(
      state.exerciseService.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => [(8, now)]);
    when(state.chartService.saveChartPreference(any, any)).thenAnswer((invocation) async {
      // the server assigns the id; removePreference only acts on a preference
      // that carries one (see Charts.removePreference)
      final preference = invocation.positionalArguments[0] as ChartPreference;
      return preference.copyWith(id: 'server-id');
    });
    when(state.chartService.deleteChartPreference(any, any)).thenAnswer((_) async {});

    await pumpExerciseDetail(tester, pullUp, initialTab: 'charts', state: state);
    await tester.pumpAndSettle();

    final l = L.of(tester.element(find.byType(Scaffold).first));
    expect(find.tooltip(l.addChartToProfile), findsNWidgets(2));

    await tester.tap(find.tooltip(l.addChartToProfile).first);
    await tester.pumpAndSettle();

    expect(find.text(l.chartAddedToProfile), findsOneWidget);
    expect(
      state.charts.any((each) => each.exerciseName == pullUp.id && each.type == .maxConsecutiveReps),
      isTrue,
    );
    expect(find.tooltip(l.removeChartFromProfile), findsOneWidget);

    await tester.tap(find.tooltip(l.removeChartFromProfile));
    await tester.pumpAndSettle();

    expect(
      state.charts.any((each) => each.exerciseName == pullUp.id && each.type == .maxConsecutiveReps),
      isFalse,
    );
    expect(find.tooltip(l.addChartToProfile), findsNWidgets(2));
  });
}
