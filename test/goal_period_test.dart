import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/presentation/widgets/chart_dimension.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// What a recurring goal is currently worth.
///
/// "Per week" is not one piece of arithmetic: volume accumulates across the
/// week's sessions, a top set is the week's best, a pace is an average. Getting
/// that wrong reads as progress the user has not made — or, for pace, as a
/// target already met.
void main() {
  late MockExerciseService service;
  late Exercises exercises;

  const userId = 'user-1';
  final press = Exercise(name: 'Arnold Press (Dumbbell)', category: .dumbbell, target: .shoulder);

  // a Thursday, so the week's Monday is the 3rd and last week is still in reach
  final now = DateTime(2026, 8, 6, 18);
  final monday = DateTime(2026, 8, 3);

  Goal goal({
    GoalMetric metric = GoalMetric.totalVolume,
    GoalCadence? cadence = GoalCadence.week,
    num target = 2000,
  }) {
    return Goal(
      id: 'goal-1',
      metric: metric,
      exerciseId: press.id,
      cadence: cadence,
      stages: [GoalStage(id: 's0', target: target)],
    );
  }

  /// Stubs the metric history the queries would return, newest first.
  void history(List<(num, DateTime)> sessions) {
    when(
      service.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => sessions);
  }

  setUp(() async {
    service = MockExerciseService();
    final remote = MockRemoteExerciseService();

    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [press]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(remoteService: remote, service: service)..userId = userId;
    await exercises.init();
  });

  Future<num?> read(Goal g) {
    return currentGoalValue(g, exercises: exercises, asOf: now);
  }

  group('goalPeriod', () {
    test('a week runs Monday midnight to the next Monday', () {
      final (from, to) = goalPeriod(.week, now);

      expect(from, monday);
      expect(to, DateTime(2026, 8, 10));
    });

    test('a month runs the first to the first', () {
      final (from, to) = goalPeriod(.month, now);

      expect(from, DateTime(2026, 8));
      expect(to, DateTime(2026, 9));
    });

    test('a December month rolls into next January', () {
      // month + 1 is 13; DateTime normalises rather than overflowing
      final (_, to) = goalPeriod(.month, DateTime(2026, 12, 20));

      expect(to, DateTime(2027));
    });
  });

  group('a recurring per-exercise goal', () {
    test('sums the volume logged inside the week', () async {
      history([
        (240, DateTime(2026, 8, 6, 9)),
        (600, DateTime(2026, 8, 4, 9)),
      ]);

      expect(await read(goal()), 840);
    });

    test('leaves last week out of this week', () async {
      // the ladder resets each period, so Sunday night is a different goal
      history([
        (240, DateTime(2026, 8, 6, 9)),
        (5000, DateTime(2026, 8, 2, 22)),
      ]);

      expect(await read(goal()), 240);
    });

    test('reads zero when nothing has been logged in the period yet', () async {
      // an honest "0 of 2000 kg this week" rather than a blank line, which is
      // what an unanswered goal used to render as
      history([(5000, DateTime(2026, 7, 30))]);

      expect(await read(goal()), 0);
    });

    test('reads zero when the exercise has no history at all', () async {
      history([]);

      expect(await read(goal()), 0);
    });

    test('takes the best top set of the week, not the sum of them', () async {
      // summing would claim a 190 kg press off sessions of 60, 60 and 70
      history([
        (60, DateTime(2026, 8, 6)),
        (70, DateTime(2026, 8, 5)),
        (60, DateTime(2026, 8, 4)),
      ]);

      expect(await read(goal(metric: .topSetWeight, target: 100)), 70);
    });

    test('averages a pace across the week, since each session is already one', () async {
      history([
        (300, DateTime(2026, 8, 6)),
        (360, DateTime(2026, 8, 4)),
      ]);

      expect(await read(goal(metric: .averagePace, target: 300)), 330);
    });

    test('leaves pace unanswered in an empty period rather than reading zero', () async {
      // lower is better for pace, so a zero would sit under every target and
      // render as though the week had already been won
      history([(300, DateTime(2026, 7, 30))]);

      expect(await read(goal(metric: .averagePace, target: 300)), isNull);
    });

    test('can answer what the period was worth before one session', () async {
      // the workout summary asks twice — with and without the session that just
      // ended — and announces only when the difference crosses the target
      final session = DateTime(2026, 8, 6, 9);
      history([
        (240, session),
        (600, DateTime(2026, 8, 4, 9)),
      ]);

      expect(await read(goal()), 840);
      expect(
        await currentGoalValue(goal(), exercises: exercises, asOf: now, without: session),
        600,
      );
    });

    test('sums a month the same way it sums a week', () async {
      history([
        (240, DateTime(2026, 8, 6)),
        (600, DateTime(2026, 8, 1)),
        (900, DateTime(2026, 7, 31)),
      ]);

      expect(await read(goal(cadence: .month)), 840);
    });
  });

  test('a milestone still reads the latest session, not the period', () async {
    history([
      (150, DateTime(2026, 8, 6)),
      (200, DateTime(2026, 8, 4)),
    ]);

    expect(await read(goal(metric: .topSetWeight, cadence: null, target: 220)), 150);
  });

  group('a whole-workout goal', () {
    Goal workoutsGoal({GoalCadence? cadence, num target = 8}) {
      return Goal(
        id: 'goal-w',
        metric: .workouts,
        cadence: cadence,
        stages: [GoalStage(id: 's0', target: target)],
      );
    }

    /// Records which period the resolver asked about.
    (List<GoalCadence?>, Future<int> Function(GoalCadence?)) counter(int answer) {
      final asked = <GoalCadence?>[];
      return (
        asked,
        (period) async {
          asked.add(period);
          return answer;
        },
      );
    }

    test('counts every workout there has ever been for a milestone', () async {
      // "do 8 workouts" is not a weekly or monthly question, and answering it
      // with null drew an empty bar and skipped the achievement
      final (asked, count) = counter(7);

      expect(await currentGoalValue(workoutsGoal(), exercises: exercises, workoutCount: count), 7);
      expect(asked, [null]);
    });

    test('asks about the week for a weekly goal', () async {
      final (asked, count) = counter(3);

      expect(
        await currentGoalValue(
          workoutsGoal(cadence: .week),
          exercises: exercises,
          workoutCount: count,
        ),
        3,
      );
      expect(asked, [GoalCadence.week]);
    });

    test('asks about the month for a monthly goal', () async {
      final (asked, count) = counter(11);

      expect(
        await currentGoalValue(
          workoutsGoal(cadence: .month),
          exercises: exercises,
          workoutCount: count,
        ),
        11,
      );
      expect(asked, [GoalCadence.month]);
    });

    test('stays unanswered when nobody supplied a counter', () async {
      expect(await currentGoalValue(workoutsGoal(), exercises: exercises), isNull);
    });
  });

  group('PeriodAggregate', () {
    test('sums, peaks and averages', () {
      expect(PeriodAggregate.sum.of([1, 2, 3]), 6);
      expect(PeriodAggregate.best.of([1, 3, 2]), 3);
      expect(PeriodAggregate.mean.of([1, 2, 6]), 3);
    });

    test('every dimension folds one of the three ways', () {
      // a new dimension has to say what a period of it means; the switch is
      // exhaustive, so this only guards against a silent default creeping in
      for (final type in ChartPreferenceType.values) {
        expect(type.periodAggregate, isA<PeriodAggregate>(), reason: type.name);
      }
    });
  });
}
