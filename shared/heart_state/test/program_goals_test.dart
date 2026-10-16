import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

void main() {
  final start = DateTime(2026, 9, 7);

  Program program({int? perWeek = 3, int? weeks = 12, Map<String, GrowthRule> rules = const {}}) {
    return Program(
      id: 'p1',
      name: 'Upper / Lower',
      perWeek: perWeek,
      weeks: weeks,
      rules: rules,
      sessions: const ['s1'],
      joined: {'s1': start},
      createdAt: start,
    );
  }

  ProgramBase base(String exerciseId, num value, DateTime at) {
    return ProgramBase(programId: 'p1', exerciseId: exerciseId, value: value, at: at);
  }

  /// [program] in week [week]: one session a cycle, so each mark is a week.
  ProgramPosition weekOf(Program program, int week) {
    return ProgramPosition.of(
      program,
      marks: [
        for (var each = 1; each < week; each++)
          ProgramMark(
            templateId: 's1',
            at: start.add(Duration(days: 7 * each - 6)),
            isWorkout: true,
          ),
      ],
      actions: const [],
      now: start.add(Duration(days: 7 * week - 5)),
    );
  }

  group('impliedGoals', () {
    test('a weekly target is a weekly workouts goal, labelled by its program', () {
      final [implied] = impliedGoals(program(), bases: const [], held: const []);
      expect(implied.program.id, 'p1');
      expect(implied.goal.metric, GoalMetric.workouts);
      expect(implied.goal.cadence, GoalCadence.week);
      expect(implied.goal.stages.single.target, 3);
      expect(implied.goal.id, startsWith('program:'));
      expect(implied.kept.id, isNull);
    });

    test('a weight rule over a fixed length is a milestone at its end, from the first base', () {
      final implied = impliedGoals(
        program(perWeek: null, rules: {'bench': const AddWeight(step: 2.5)}),
        bases: [base('bench', 60, start), base('bench', 65, start.add(const Duration(days: 14)))],
        held: const [],
      );
      final goal = implied.single.goal;
      expect(goal.metric, GoalMetric.topSetWeight);
      expect(goal.exerciseId, 'bench');
      // 60 + 2.5 a week for 12 weeks, from the first base, not the latest
      expect(goal.stages.single.target, 90);
      expect(goal.stages.single.dueOn, start.add(const Duration(days: 84)));
    });

    test('a share of a max reads as the one-rep max it implies', () {
      final implied = impliedGoals(
        program(
          perWeek: null,
          rules: {
            'squat': const ShareOfMax(
              step: 5,
              waves: [
                [WaveSet(share: .65, reps: 5)],
                [WaveSet(share: .75, reps: 5)],
                [WaveSet(share: .85, reps: 5)],
              ],
            ),
          },
        ),
        bases: [base('squat', 90, start)],
        held: const [],
      );
      final goal = implied.single.goal;
      expect(goal.metric, GoalMetric.estimatedOneRepMax);
      // a max of 90 + 5 a wave of three weeks, over 12: 110, as a one-rep max
      // of 122.2, down to whole steps
      expect(goal.stages.single.target, 120);
    });

    test('a target the user already holds is never shown twice', () {
      final held = [
        Goal(metric: .workouts, cadence: .week, stages: [GoalStage(target: 4)]),
        Goal(metric: .topSetWeight, exerciseId: 'bench', stages: [GoalStage(target: 100)]),
      ];
      final implied = impliedGoals(
        program(rules: {'bench': const AddWeight(step: 2.5)}),
        bases: [base('bench', 60, start)],
        held: held,
      );
      expect(implied, isEmpty);
    });

    test('an ongoing program implies no milestone, and a ladder no weight', () {
      final implied = impliedGoals(
        program(
          perWeek: null,
          weeks: null,
          rules: {'bench': const AddWeight(step: 2.5)},
        ),
        bases: [base('bench', 60, start)],
        held: const [],
      );
      expect(implied, isEmpty);
      expect(weeklyGain(const Ladder(rungs: ['a', 'b'], top: 12, bottom: 8)), isNull);
    });
  });

  group('forecastOf', () {
    final rules = {'bench': const AddWeight(step: 2.5)};
    final goal = Goal(metric: .topSetWeight, exerciseId: 'bench', stages: [GoalStage(target: 85)]);

    test('the bases set the slope once they span a week', () {
      final running = program(rules: rules);
      final forecast = forecastOf(
        goal,
        current: 70,
        program: running,
        position: weekOf(running, 5),
        // 60 → 70 over four weeks: 2.5 a week, 15 to go: six weeks, this one the first
        bases: [base('bench', 60, start), base('bench', 70, start.add(const Duration(days: 28)))],
        sessionsDone: 4,
      );
      expect(forecast, isA<ForecastOnTrack>().having((each) => each.week, 'week', 10));
    });

    test('before the bases move, kept sessions scale the rule own pace', () {
      final running = program(perWeek: 2, rules: rules);
      final forecast = forecastOf(
        goal,
        current: 70,
        program: running,
        position: weekOf(running, 3),
        bases: [base('bench', 70, start)],
        // two of four planned: half the pace, 1.25 a week, 12 weeks to go
        sessionsDone: 2,
      );
      expect(forecast, isA<ForecastPastEnd>().having((each) => each.week, 'week', 14));
    });

    test('met is reached, flat is too early, and a cadence is not the program to say', () {
      final running = program(rules: rules);
      final position = weekOf(running, 2);
      expect(
        forecastOf(goal, current: 90, program: running, position: position, bases: const [], sessionsDone: 1),
        isA<ForecastReached>(),
      );
      expect(
        forecastOf(goal, current: null, program: running, position: position, bases: const [], sessionsDone: 1),
        isA<ForecastTooEarly>(),
      );
      expect(
        forecastOf(
          goal,
          current: 70,
          program: running,
          position: position,
          bases: [base('bench', 70, start), base('bench', 70, start.add(const Duration(days: 14)))],
          sessionsDone: 1,
        ),
        isA<ForecastTooEarly>(),
      );
      final weekly = Goal(metric: .workouts, cadence: .week, stages: [GoalStage(target: 3)]);
      expect(
        forecastOf(weekly, current: 1, program: running, position: position, bases: const [], sessionsDone: 1),
        isNull,
      );
    });
  });
}
