import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/goals_widget.dart';
import 'package:heart_models/heart_models.dart';

/// How full the Goals widget's bar is (#368): the same rung the goal row
/// reads, as a share.
void main() {
  Goal goal(GoalMetric metric, List<GoalStage> stages) => Goal(id: 'g', metric: metric, stages: stages);

  test('more is better: the reading over the current rung', () {
    expect(goalProgress(goal(.workouts, [GoalStage(target: 4)]), 3), 0.75);
    expect(goalProgress(goal(.workouts, [GoalStage(target: 4)]), 6), 1);
  });

  test('a rung already met moves the bar to the next one', () {
    final ladder = goal(.totalVolume, [
      GoalStage(target: 1000, achievedAt: DateTime.utc(2026, 9)),
      GoalStage(target: 2000),
    ]);
    expect(goalProgress(ladder, 1500), 0.75);
  });

  test('lower is better: the rung over the reading', () {
    expect(goalProgress(goal(.averagePace, [GoalStage(target: 300)]), 400), 0.75);
    expect(goalProgress(goal(.averagePace, [GoalStage(target: 300)]), 250), 1);
  });

  test('nothing measured is empty; a finished ladder is full', () {
    expect(goalProgress(goal(.workouts, [GoalStage(target: 4)]), null), 0);
    expect(goalProgress(goal(.workouts, [GoalStage(target: 4, achievedAt: DateTime.utc(2026, 9))]), null), 1);
  });
}
