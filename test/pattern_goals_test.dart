import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';

/// A goal on a movement pattern or a muscle (#344) reads the pattern lens's
/// counts (#341): the same sets the weekly card shows, over the goal's period.
void main() {
  // a Thursday: the week began Monday the 3rd
  final now = DateTime(2026, 8, 6, 18);
  final tuesday = DateTime(2026, 8, 4, 18);
  final lastWeek = DateTime(2026, 7, 30, 18);

  final exercises = Exercises(
    remoteService: MockRemoteExerciseService(),
    service: MockExerciseService(),
    libraryService: MockExerciseLibraryService(),
    catalogService: MockLocalCatalogService(),
    preferenceService: MockRemoteExercisePreferenceService(),
  );

  LensSets row({
    required String workout,
    required DateTime start,
    String exercise = 'bench',
    List<String> patterns = const ['horizontal_press'],
    int sets = 3,
  }) {
    return (
      workoutId: workout,
      exerciseId: exercise,
      start: start,
      movement: Movement.fromJson({'groups': patterns}),
      muscles: MuscleTagging.empty(),
      target: .chest,
      sets: sets,
    );
  }

  final rows = [
    row(workout: 'w1', start: tuesday),
    row(workout: 'w1', start: tuesday, exercise: 'fly', patterns: ['chest_fly'], sets: 2),
    row(workout: 'w2', start: now, sets: 4),
    row(workout: 'w0', start: lastWeek, sets: 5),
  ];

  /// What [Stats.getLensSets] answers for [from, to): the rows started in it.
  Future<List<LensSets>> lensSets(DateTime from, DateTime to) async {
    return rows.where((each) => !each.start.isBefore(from) && each.start.isBefore(to)).toList();
  }

  Goal goal({GoalMetric metric = .sets, String? pattern, String? muscle, GoalCadence? cadence = .week}) {
    return Goal(
      metric: metric,
      pattern: pattern,
      muscle: muscle,
      cadence: cadence,
      stages: [GoalStage(target: 10)],
    );
  }

  Future<num?> read(Goal goal, {DateTime? without}) {
    return currentGoalValue(goal, exercises: exercises, lensSets: lensSets, asOf: now, without: without);
  }

  test("a pattern's sets this week leave last week's out", () async {
    expect(await read(goal(pattern: 'horizontal_press')), 7);
  });

  test('sessions count each workout that trained the pattern once', () async {
    expect(await read(goal(metric: .sessions, pattern: 'horizontal_press')), 2);
  });

  test('a milestone counts everything there has been', () async {
    expect(await read(goal(pattern: 'horizontal_press', cadence: null)), 12);
  });

  test('a pattern nothing trained reads as zero, not as unmeasurable', () async {
    expect(await read(goal(pattern: 'vertical_pull')), 0);
  });

  test('without leaves out the session that started then', () async {
    expect(await read(goal(pattern: 'horizontal_press'), without: now), 3);
  });

  test("a muscle takes each set at the group's share", () async {
    // fly and bench fall back to their target, chest, in full
    expect(await read(goal(muscle: 'chest')), 9);
  });

  test('a muscle key this build cannot place is unmeasurable', () async {
    expect(await read(goal(muscle: 'pectoralis_major')), isNull);
  });

  test('goals measured together read each window once', () async {
    final windows = <(DateTime, DateTime)>[];
    final shared = sharedLensSets((from, to) {
      windows.add((from, to));
      return lensSets(from, to);
    });
    final goals = [
      goal(pattern: 'horizontal_press', cadence: null),
      goal(muscle: 'chest', cadence: null),
      goal(pattern: 'horizontal_press'),
      goal(metric: .sessions, pattern: 'horizontal_press'),
    ];

    final readings = [
      for (final each in goals) await currentGoalValue(each, exercises: exercises, lensSets: shared, asOf: now),
    ];

    expect(readings, [12, 14, 7, 2]);
    // all time once, this week once
    expect(windows, hasLength(2));
  });

  test("the sets a goal shows are the weekly card's, rounded down", () {
    expect(wholeSets(9.6), 9);
    expect(wholeSets(10), 10);
    expect(wholeSets(0.5), 0);
  });

  test('a goal on one exercise counts only its sets', () async {
    final onBench = Goal(metric: .sets, exerciseId: 'bench', cadence: .week, stages: [GoalStage(target: 10)]);
    expect(await read(onBench), 7);
  });
}
