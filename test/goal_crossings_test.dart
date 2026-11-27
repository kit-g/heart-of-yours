// Live goal notes (#625): the rungs a workout carries over the line, worked
// out as its sets are ticked, and the Done page's goal list worked out the
// same way once it is finished. One calculation, so the two cannot disagree.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/goal_crossings.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final row = Exercise(name: 'Seated Row', category: .machine, target: .back);
  final run = Exercise(name: 'Running', category: .cardio, target: .cardio);
  final rowing = Exercise(
    name: 'Cable Row',
    category: .machine,
    target: .back,
    movement: Movement.fromJson({
      'groups': ['horizontal_pull'],
    }),
  );

  // a Thursday: the week began Monday the 3rd
  final now = DateTime(2026, 8, 6, 18);

  /// The workout's own copies, as tagged as the catalogue's.
  final GoalFold fold = (exerciseOf: (embedded) => embedded, leftOut: const {});

  Goal goal(
    GoalMetric metric,
    List<num> targets, {
    String id = 'goal-1',
    GoalCadence? cadence,
    String? exerciseId,
    String? pattern,
    String? muscle,
  }) {
    return Goal(
      id: id,
      metric: metric,
      exerciseId: exerciseId,
      pattern: pattern,
      muscle: muscle,
      cadence: cadence,
      stages: [for (final (index, target) in targets.indexed) GoalStage(id: '$id-s$index', target: target)],
    );
  }

  ExerciseSet set(Exercise exercise, {double? weight, int? reps, int? duration, double? distance}) {
    return ExerciseSet(exercise, weight: weight, reps: reps, duration: duration, distance: distance);
  }

  Workout session(List<ExerciseSet> sets, {DateTime? at}) {
    final entries = <WorkoutExercise>[];
    for (final each in sets) {
      switch (entries.where((entry) => entry.exercise.id == each.exercise.id).firstOrNull) {
        case final WorkoutExercise entry:
          entry.add(each);
        case null:
          entries.add(WorkoutExercise(starter: each));
      }
    }
    return Workout.fromExercises(entries)..start = at ?? now;
  }

  LensSets lensRow(Exercise exercise, {required int sets, String workoutId = 'w0', DateTime? start}) {
    return (
      workoutId: workoutId,
      exerciseId: exercise.id,
      start: start ?? DateTime(2026, 8, 4),
      movement: exercise.movement,
      muscles: exercise.muscles,
      target: exercise.target,
      sets: sets,
    );
  }

  LensPrior lens(Goal goal, List<LensSets> rows) => LensPrior(subjectCount(goal, rows)!);

  void tick(ExerciseSet each, {bool done = true}) => each.isCompleted = done;

  List<num> targetsCrossed(Goal goal, GoalPrior prior, Workout workout, {GoalFold? folding}) {
    return [
      for (final (goal: _, :stage) in goalCrossings([goal], (_) => prior, workout, fold: folding ?? fold)) stage.target,
    ];
  }

  group('every goal metric a set can move', () {
    test('a top set crosses the rung it reaches, and only that one', () {
      final ladder = goal(.topSetWeight, [100, 110, 120], exerciseId: bench.id);
      final heavy = set(bench, weight: 112.5, reps: 3);
      final workout = session([set(bench, weight: 60, reps: 5)..isCompleted = true, heavy]);
      final prior = SessionsPrior.of(ladder, const [102]);

      expect(targetsCrossed(ladder, prior, workout), isEmpty, reason: 'nothing heavier ticked yet');
      tick(heavy);
      expect(targetsCrossed(ladder, prior, workout), [110], reason: '100 was met before today');
    });

    test("an estimated 1RM, by the query's Brzycki", () {
      final ladder = goal(.estimatedOneRepMax, [120], exerciseId: bench.id);
      final workout = session([set(bench, weight: 100, reps: 8)..isCompleted = true]);

      // 100 / (1.0278 - 0.0278 × 8) = 124.2
      expect(targetsCrossed(ladder, SessionsPrior.of(ladder, const [110]), workout), [120]);
    });

    test("this week's volume adds today's to the week's other sessions", () {
      final weekly = goal(.totalVolume, [2000], exerciseId: bench.id, cadence: .week);
      final last = set(bench, weight: 100, reps: 5);
      final workout = session([set(bench, weight: 100, reps: 5)..isCompleted = true, last]);
      final prior = SessionsPrior.of(weekly, const [1200]);

      expect(prior.before, 1200);
      expect(targetsCrossed(weekly, prior, workout), isEmpty, reason: '1700');
      tick(last);
      expect(targetsCrossed(weekly, prior, workout), [2000]);
    });

    test('a later session in a week already won crosses nothing', () {
      final weekly = goal(.totalVolume, [2000], exerciseId: bench.id, cadence: .week);
      final workout = session([set(bench, weight: 100, reps: 5)..isCompleted = true]);

      expect(targetsCrossed(weekly, SessionsPrior.of(weekly, const [2400]), workout), isEmpty);
    });

    test('a pace is met from above', () {
      final pace = goal(.averagePace, [300], exerciseId: run.id);
      final workout = session([set(run, duration: 1450, distance: 5)..isCompleted = true]);

      expect(targetsCrossed(pace, SessionsPrior.of(pace, const [320]), workout), [300]);
    });

    test("this week's sets on a pattern", () {
      final pull = goal(.sets, [12], pattern: 'horizontal_pull', cadence: .week);
      final last = set(rowing, weight: 50, reps: 10);
      final workout = session([
        set(rowing, weight: 50, reps: 10)..isCompleted = true,
        set(rowing, weight: 50, reps: 10)..isCompleted = true,
        last,
      ]);
      final prior = lens(pull, [lensRow(rowing, sets: 9)]);

      expect(targetsCrossed(pull, prior, workout), isEmpty, reason: '9 + 2 = 11 needs the third');
      tick(last);
      expect(targetsCrossed(pull, prior, workout), [12]);
    });

    test("this week's sets on a muscle, at the group's share", () {
      final back = goal(.sets, [3], muscle: 'back', cadence: .week);
      final workout = session([
        for (final _ in List.generate(3, (_) => 0)) set(row, weight: 50, reps: 10)..isCompleted = true,
      ]);

      // an exercise nobody tagged counts toward its target's group in full
      expect(targetsCrossed(back, lens(back, const []), workout), [3]);
    });

    test("the week's sessions count when the first set on the subject is ticked", () {
      final pressing = goal(.sessions, [2], exerciseId: bench.id, cadence: .week);
      final first = set(bench, weight: 60, reps: 5);
      final second = set(bench, weight: 60, reps: 5);
      final workout = session([first, second]);
      final prior = lens(pressing, [lensRow(bench, sets: 4)]);

      expect(targetsCrossed(pressing, prior, workout), isEmpty);
      tick(first);
      expect(targetsCrossed(pressing, prior, workout), [2]);
      tick(second);
      expect(targetsCrossed(pressing, prior, workout), [2], reason: 'still the one session');
    });

    test('a workouts goal counts this one once a set is ticked', () {
      final often = goal(.workouts, [3], cadence: .week);
      final first = set(bench, weight: 60, reps: 5);
      final workout = session([first]);

      expect(targetsCrossed(often, const WorkoutsPrior(2), workout), isEmpty);
      tick(first);
      expect(targetsCrossed(often, const WorkoutsPrior(2), workout), [3]);
    });
  });

  group('the rules the record note keeps', () {
    test('an untick takes the crossing back', () {
      final ladder = goal(.topSetWeight, [110], exerciseId: bench.id);
      final heavy = set(bench, weight: 112.5, reps: 3)..isCompleted = true;
      final workout = session([heavy]);
      final prior = SessionsPrior.of(ladder, const [100]);

      expect(targetsCrossed(ladder, prior, workout), [110]);
      tick(heavy, done: false);
      expect(targetsCrossed(ladder, prior, workout), isEmpty);
    });

    test('an edit that falls short takes it back too', () {
      final ladder = goal(.topSetWeight, [110], exerciseId: bench.id);
      final heavy = set(bench, weight: 112.5, reps: 3)..isCompleted = true;
      final workout = session([heavy]);

      heavy.setMeasurements(weight: 107.5);
      expect(targetsCrossed(ladder, SessionsPrior.of(ladder, const [100]), workout), isEmpty);
    });

    test('a warm-up reaches nothing', () {
      final ladder = goal(.topSetWeight, [110], exerciseId: bench.id);
      final workout = session([
        set(bench, weight: 120, reps: 3)
          ..isCompleted = true
          ..setType = .warmup,
      ]);

      expect(targetsCrossed(ladder, SessionsPrior.of(ladder, const [100]), workout), isEmpty);
    });

    test('a set discarded under suspicious entries (#428) reaches nothing, as the store leaves it out', () {
      final ladder = goal(.topSetWeight, [110], exerciseId: bench.id);
      final odd = set(bench, weight: 1120, reps: 3)..isCompleted = true;
      final workout = session([odd]);
      final prior = SessionsPrior.of(ladder, const [100]);

      expect(targetsCrossed(ladder, prior, workout), [110]);
      expect(
        targetsCrossed(ladder, prior, workout, folding: (exerciseOf: (embedded) => embedded, leftOut: {odd.id})),
        isEmpty,
      );
    });

    test('a goal not read yet crosses nothing', () {
      final ladder = goal(.topSetWeight, [110], exerciseId: bench.id);
      final workout = session([set(bench, weight: 120, reps: 3)..isCompleted = true]);

      expect(goalCrossings([ladder], (_) => null, workout, fold: fold), isEmpty);
    });

    test('a stamped rung, or a complete goal, is never news again', () {
      // the history in hand can fall short of the one that met it: paged
      // history on a new install, the session deleted, a target edited
      final stamped = DateTime.utc(2026, 7, 1);
      final ladder = Goal(
        id: 'goal-1',
        metric: .topSetWeight,
        exerciseId: bench.id,
        stages: [
          GoalStage(id: 's0', target: 100, achievedAt: stamped),
          GoalStage(id: 's1', target: 110),
        ],
      );
      final done = Goal(
        id: 'goal-2',
        metric: .topSetWeight,
        exerciseId: bench.id,
        stages: [GoalStage(id: 's0', target: 100, achievedAt: stamped)],
      );
      final workout = session([set(bench, weight: 112.5, reps: 3)..isCompleted = true]);

      expect(targetsCrossed(ladder, SessionsPrior.of(ladder, const []), workout), [110]);
      expect(targetsCrossed(done, SessionsPrior.of(done, const []), workout), isEmpty);
    });

    test("a crossing is the goal and the rung's place, whatever its id or target", () {
      final ladder = goal(.topSetWeight, [100, 110], exerciseId: bench.id);
      final synced = Goal(
        id: ladder.id,
        metric: ladder.metric,
        exerciseId: bench.id,
        stages: [
          GoalStage(id: 'server-0', target: 100),
          GoalStage(id: 'server-1', target: 112),
        ],
      );

      expect(
        crossingKey((goal: ladder, stage: ladder.stages[1])),
        crossingKey((goal: synced, stage: synced.stages[1])),
      );
    });

    test("a goal's last rung is the hardest one, whichever way the ladder runs", () {
      final up = goal(.topSetWeight, [100, 120, 110], exerciseId: bench.id);
      final pace = goal(.averagePace, [320, 300], exerciseId: run.id);

      expect(isFinalRung((goal: up, stage: up.stages[1])), isTrue);
      expect(isFinalRung((goal: up, stage: up.stages[2])), isFalse);
      expect(isFinalRung((goal: pace, stage: pace.stages[1])), isTrue);
    });
  });

  group('the Done page agrees with the workout, read for read', () {
    // The same store, asked while the workout is going and once it has
    // finished. Going, the store holds its ticked sets (the chart queries do
    // not ask whether a workout ended) but does not count it as a workout or
    // give it lens rows; finished, it does all three. Either way the prior
    // leaves it out, and the fold puts it back.
    const userId = 'u1';
    late MockExerciseService service;
    late Exercises exercises;

    setUp(() async {
      service = MockExerciseService();
      final remote = MockRemoteExerciseService();
      when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, rowing]));
      when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
      when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
      when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
      exercises = Exercises(
        remoteService: remote,
        service: service,
        libraryService: MockExerciseLibraryService(),
        catalogService: MockLocalCatalogService(),
        preferenceService: MockRemoteExercisePreferenceService(),
      )..userId = userId;
      await exercises.init();
    });

    test("for every kind of goal, on a workout that carries the server's bare copies of its exercises", () async {
      // the server embeds an exercise as its id, category, target and name:
      // no movement and no muscles. The catalogue's copy says what it trains.
      Exercise bare(Exercise exercise) {
        return Exercise.fromJson({
          'id': exercise.id,
          'name': exercise.name,
          'category': exercise.category.value,
          'target': exercise.target.value,
        });
      }

      // a Sunday evening, and finished on Monday: still the week of the 3rd
      final sunday = DateTime(2026, 8, 9, 23, 30);
      final workout = session([
        set(bare(bench), weight: 112.5, reps: 3)..isCompleted = true,
        set(bare(bench), weight: 100, reps: 5)..isCompleted = true,
        set(bare(rowing), weight: 50, reps: 10)..isCompleted = true,
        set(bare(rowing), weight: 50, reps: 10)..isCompleted = true,
      ], at: sunday);
      final goals = [
        goal(.topSetWeight, [110, 120], id: 'top', exerciseId: bench.id),
        goal(.totalVolume, [1200], id: 'volume', exerciseId: bench.id, cadence: .week),
        goal(.sets, [6], id: 'sets', exerciseId: bench.id, cadence: .week),
        goal(.sets, [5], id: 'pull', pattern: 'horizontal_pull', cadence: .week),
        goal(.sessions, [2], id: 'sessions', exerciseId: bench.id, cadence: .week),
        goal(.workouts, [3], id: 'workouts', cadence: .week),
      ];
      final earlier = DateTime(2026, 8, 4, 9);
      final today = [
        lensRow(bench, sets: 2, workoutId: workout.id, start: sunday),
        lensRow(rowing, sets: 2, workoutId: workout.id, start: sunday),
      ];
      final before = [lensRow(bench, sets: 5, start: earlier), lensRow(rowing, sets: 3, start: earlier)];
      final GoalFold catalogued = (
        exerciseOf: (embedded) => exercises.lookup(embedded.id) ?? embedded,
        leftOut: const {},
      );

      Future<List<GoalAchievement>> crossings({required bool finished, GoalFold? folding}) async {
        when(service.getExerciseMetics(any, any, any, limit: anyNamed('limit'))).thenAnswer((invocation) async {
          final type = invocation.positionalArguments[1] as ChartPreferenceType;
          return switch (type) {
            .topSetWeight => [(112.5, workout.start), (105, earlier)],
            _ => [(837.5, workout.start), (400, earlier)],
          };
        });
        final judged = finished ? (workout..end = DateTime(2026, 8, 10, 0, 30)) : workout;
        final priors = {
          for (final each in goals)
            each: await readGoalPrior(
              each,
              judged,
              exercises: exercises,
              firstWeekday: DateTime.monday,
              workoutCount: (_) async => finished ? 3 : 2,
              lensSets: (from, to) async => [
                for (final row in [...before, if (finished) ...today])
                  if (!row.start.isBefore(from) && row.start.isBefore(to)) row,
              ],
            ),
        };
        return goalCrossings(goals, (each) => priors[each], judged, fold: folding ?? catalogued);
      }

      final live = await crossings(finished: false);
      final done = await crossings(finished: true);

      expect([for (final each in live) crossingKey(each)], [for (final each in done) crossingKey(each)]);
      expect(
        [for (final (:goal, stage: _) in done) goal.id],
        ['top', 'volume', 'sets', 'pull', 'sessions', 'workouts'],
      );
      // read off the workout's own copies, the rows trained no pattern at all
      final untagged = await crossings(finished: true, folding: fold);
      expect([for (final (:goal, stage: _) in untagged) goal.id], isNot(contains('pull')));
    });
  });
}
