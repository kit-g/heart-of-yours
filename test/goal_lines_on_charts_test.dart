// A goal on an exercise metric draws its next rung on every chart of that
// exercise and metric, not only inside the goal's own sheet (#627). The goal
// that went missing was a weekly one: "a 100 kg top set this week".
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'support/exercise_detail_test_helpers.dart';

class _Goals extends Fake implements LocalGoalService {
  final List<Goal> goals;

  new(this.goals);

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return switch (archived) {
      true => const [],
      false => goals,
    };
  }
}

void main() {
  final bench = Exercise(name: 'Bench press', category: .barbell, target: .chest);

  Future<ExerciseDetailState> withGoals(List<Goal> goals) async {
    final base = await buildExerciseDetailState();
    final state = ExerciseDetailState(
      exercises: base.exercises,
      workouts: base.workouts,
      preferences: base.preferences,
      charts: base.charts,
      goals: Goals(service: _Goals(goals), remoteService: FakeGoalService())..userId = 'u1',
      exerciseService: base.exerciseService,
      workoutService: base.workoutService,
      chartService: base.chartService,
    );
    await state.goals.init();
    final now = DateTime(2026, 6, 1);
    when(
      state.exerciseService.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => [(80, now), (85, now.add(const Duration(days: 7)))]);
    return state;
  }

  for (final cadence in <GoalCadence?>[null, .week]) {
    testWidgets("the About tab's chart draws the rung being worked toward (cadence: $cadence)", (tester) async {
      final state = await withGoals([
        Goal(
          id: 'g1',
          metric: .topSetWeight,
          exerciseId: bench.id,
          cadence: cadence,
          stages: [GoalStage(id: 's0', target: 100)],
        ),
      ]);
      expect(state.goals.length, 1, reason: 'the goal is loaded before the page reads it');

      await pumpExerciseDetail(tester, bench, initialTab: 'charts', state: state);
      await tester.pumpAndSettle();

      final lines = tester
          .widgetList<HistoryChart>(find.byType(HistoryChart))
          .expand((chart) => chart.thresholds)
          .map((line) => line.value);
      expect(lines, contains(100));
    });
  }
}
