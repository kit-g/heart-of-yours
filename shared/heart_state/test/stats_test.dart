import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/lens.dart';
import 'package:heart_state/src/recaps.dart';
import 'package:heart_state/src/stats.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class RecordingStatsService implements LocalStatsService {
  WorkoutAggregation workoutSummary = WorkoutAggregation.empty();
  final List<DateTime> weeklyCountCalls = [];
  final List<String?> weeklyCountUsers = [];
  int weeklyCountToReturn = 0;
  final List<(DateTime, String?)> monthlyCountCalls = [];
  int monthlyCountToReturn = 0;

  /// Each read takes the next of these, if any, and waits on it: what a
  /// session change or a later read can overtake.
  final summaryGates = <Completer<void>>[];

  /// What the next read throws, once.
  Object? summaryError;

  @override
  Future<WorkoutAggregation> getWorkoutSummary({int? weeksBack, String? userId}) async {
    final summary = workoutSummary;
    final error = summaryError;
    summaryError = null;
    if (summaryGates.isNotEmpty) await summaryGates.removeAt(0).future;
    if (error != null) throw error;
    return summary;
  }

  @override
  Future<int> getWeeklyWorkoutCount(DateTime d, {String? userId}) async {
    weeklyCountCalls.add(d);
    weeklyCountUsers.add(userId);
    return weeklyCountToReturn;
  }

  final List<(DateTime, DateTime, String?)> betweenCalls = [];
  int betweenCountToReturn = 0;

  @override
  Future<int> getWorkoutCountBetween(DateTime from, DateTime to, {String? userId}) async {
    betweenCalls.add((from, to, userId));
    return betweenCountToReturn;
  }

  @override
  Future<int> getMonthlyWorkoutCount(DateTime d, {String? userId}) async {
    monthlyCountCalls.add((d, userId));
    return monthlyCountToReturn;
  }

  final List<String?> totalCountCalls = [];
  int totalCountToReturn = 0;

  @override
  Future<int> getTotalWorkoutCount({String? userId}) async {
    totalCountCalls.add(userId);
    return totalCountToReturn;
  }

  final List<(DateTime, DateTime, String?)> muscleSetsCalls = [];
  List<MuscleSets> muscleSetsToReturn = [];

  @override
  Future<List<MuscleSets>> getMuscleSets(DateTime from, DateTime to, {String? userId}) async {
    muscleSetsCalls.add((from, to, userId));
    return muscleSetsToReturn;
  }

  final List<(DateTime, DateTime, String?)> lensSetsCalls = [];
  List<LensSets> lensSetsToReturn = [];

  @override
  Future<List<LensSets>> getLensSets(DateTime from, DateTime to, {String? userId}) async {
    lensSetsCalls.add((from, to, userId));
    return lensSetsToReturn;
  }

  final List<(DateTime, DateTime, String?)> totalsCalls = [];
  List<WorkoutTotals> totalsToReturn = [];

  @override
  Future<List<WorkoutTotals>> getTrainingTotals(DateTime from, DateTime to, {String? userId}) async {
    totalsCalls.add((from, to, userId));
    return totalsToReturn;
  }

  final List<(DateTime, DateTime, String?)> recapCalls = [];
  List<RecapWorkout> recapWorkoutsToReturn = [];
  List<RecapSet> recapSetsToReturn = [];

  @override
  Future<List<RecapWorkout>> getRecapWorkouts(DateTime from, DateTime to, {String? userId}) async {
    recapCalls.add((from, to, userId));
    return recapWorkoutsToReturn;
  }

  @override
  Future<List<RecapSet>> getRecapSets(DateTime from, DateTime to, {String? userId}) async {
    recapCalls.add((from, to, userId));
    return recapSetsToReturn;
  }
}

void main() {
  group('Stats (unit)', () {
    late RecordingStatsService service;
    late Stats stats;
    late int notifications;

    setUp(() {
      service = RecordingStatsService();
      stats = Stats(onError: null, service: service);
      notifications = 0;
      stats.addListener(() => notifications++);
    });

    test('init sets workouts and notifies when local summary is non-empty', () async {
      // Prepare a non-empty aggregation
      final nonEmpty = WorkoutAggregation.fromRows([
        {
          'id': '2025-08-01T10:00:00Z',
          'name': 'Morning',
          'start': '2025-08-01T10:00:00Z',
        },
      ]);
      service.workoutSummary = nonEmpty;

      expect(stats.workouts.isNotEmpty, isFalse, reason: 'starts empty');
      expect(notifications, 0);

      await stats.init();

      expect(stats.workouts, equals(nonEmpty));
      expect(stats.workouts.isNotEmpty, isTrue);
      expect(notifications, 1);
    });

    test("an empty read replaces the last user's chart: a user with no workouts sees none", () async {
      service.workoutSummary = WorkoutAggregation.fromRows([
        {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
      ]);
      stats.userId = 'old';
      await stats.init();
      expect(stats.workouts.isNotEmpty, isTrue);

      stats.userId = 'new';
      service.workoutSummary = WorkoutAggregation.empty();
      notifications = 0;
      await stats.init();

      expect(stats.workouts.isNotEmpty, isFalse);
      expect(notifications, 1, reason: 'the chart on screen goes with it');
    });

    test("a read the session changed under is dropped: the last user's chart never lands on the next", () async {
      stats.userId = 'old';
      final gate = Completer<void>();
      service
        ..workoutSummary = WorkoutAggregation.fromRows([
          {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
        ])
        ..summaryGates.add(gate);
      final stale = stats.init();

      stats
        ..onSignOut()
        ..userId = 'new';
      notifications = 0;
      gate.complete();
      await stale;

      expect(stats.workouts.isNotEmpty, isFalse);
      expect(notifications, 0, reason: 'a dropped read changes nothing, so says nothing');
    });

    // #719 as it happens: Log out clears, then awaits the push unregister, and
    // only then is the next uid keyed. The Profile's re-read for the account
    // that left lands in that gap.
    test('a read for the session that ended, landing before the next is keyed, leaves the chart empty', () async {
      stats.userId = 'old';
      final gate = Completer<void>();
      service
        ..workoutSummary = WorkoutAggregation.fromRows([
          {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
        ])
        ..summaryGates.add(gate);
      final stale = stats.init();

      stats.onSignOut();
      expect(stats.userId, isNull, reason: 'the session it was keyed on is gone');
      notifications = 0;
      gate.complete();
      await stale;
      expect(notifications, 0);

      stats.userId = 'new';
      service.workoutSummary = WorkoutAggregation.empty();
      await stats.init();

      expect(stats.workouts.isNotEmpty, isFalse);
    });

    test('overlapping reads land in the order they were asked for: the later one wins', () async {
      stats.userId = 'u1';
      final (first, second) = (Completer<void>(), Completer<void>());
      service
        ..summaryGates.addAll([first, second])
        ..workoutSummary = WorkoutAggregation.fromRows([
          {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
        ]);
      final older = stats.init();
      final latest = WorkoutAggregation.fromRows([
        {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
        {'id': '2025-08-02T10:00:00Z', 'name': 'Evening', 'start': '2025-08-02T10:00:00Z'},
      ]);
      service.workoutSummary = latest;
      final newer = stats.init();

      second.complete();
      await newer;
      first.complete();
      await older;

      expect(stats.workouts, same(latest));
      expect(notifications, 1, reason: 'the outdated read is dropped');
    });

    test('a failed read is reported, and leaves what was held', () async {
      final errors = <Object>[];
      stats = Stats(onError: (error, {stacktrace}) => errors.add(error), service: service)..userId = 'u1';
      service.workoutSummary = WorkoutAggregation.fromRows([
        {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
      ]);
      await stats.init();
      final held = stats.workouts;
      final revision = stats.revision;

      service.summaryError = StateError('disk');
      await stats.init();

      expect(errors, [isA<StateError>()]);
      expect(stats.workouts, same(held));
      expect(stats.revision, revision);
    });

    test('every read that lands moves the revision, and one that changed nothing keeps the aggregation', () async {
      stats.userId = 'u1';
      await stats.init();
      expect(stats.revision, 1, reason: 'empty over empty: the longer windows may still have moved');
      expect(notifications, 1);

      service.workoutSummary = WorkoutAggregation.fromRows([
        {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
      ]);
      await stats.init();
      final held = stats.workouts;

      service.workoutSummary = WorkoutAggregation.fromRows([
        {'id': '2025-08-01T10:00:00Z', 'name': 'Morning', 'start': '2025-08-01T10:00:00Z'},
      ]);
      await stats.init();

      expect(stats.workouts, same(held), reason: 'the same weeks: nothing for the chart to redraw');
      expect(stats.revision, 3);
      expect(notifications, 3);
    });

    test('onSignOut resets workouts to empty and says so', () async {
      // Put some non-empty state in
      service.workoutSummary = WorkoutAggregation.fromRows([
        {
          'id': '2025-08-02T10:00:00Z',
          'name': 'Run',
          'start': '2025-08-02T10:00:00Z',
        },
      ]);
      await stats.init();
      expect(stats.workouts.isNotEmpty, isTrue);
      notifications = 0;

      stats.onSignOut();

      expect(stats.workouts, WorkoutAggregation.empty());
      expect(stats.workouts.isNotEmpty, isFalse);
      expect(notifications, 1, reason: 'what was on screen goes, for whatever is still showing it (#671)');
      expect(stats.userId, isNull);
    });

    test('getWeeklyWorkoutCount counts the week that starts on the chosen day, for the user', () async {
      // a Sunday: the first day of its week when weeks start on Sunday, the
      // last when they start on Monday (#339)
      final when = DateTime(2025, 8, 10, 18);
      service.betweenCountToReturn = 5;
      stats.userId = 'u1';

      expect(await stats.getWeeklyWorkoutCount(when, firstWeekday: DateTime.sunday), 5);
      await stats.getWeeklyWorkoutCount(when, firstWeekday: DateTime.monday);

      expect(service.betweenCalls, [
        (DateTime(2025, 8, 10), DateTime(2025, 8, 17), 'u1'),
        (DateTime(2025, 8, 4), DateTime(2025, 8, 11), 'u1'),
      ]);
      expect(service.weeklyCountCalls, isEmpty, reason: "the shared signature's week is always Monday's");
    });

    test('getMuscleSets delegates with the user, and holds nothing or notifies', () async {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 8);
      final rows = [(start: from, muscles: MuscleTagging.empty(), target: Target.other, sets: 3)];
      service.muscleSetsToReturn = rows;
      stats.userId = 'u1';

      expect(await stats.getMuscleSets(from, to), rows);
      expect(service.muscleSetsCalls, [(from, to, 'u1')]);
      expect(notifications, 0);
    });

    test('getLensSets delegates with the user, and holds nothing or notifies', () async {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 8);
      stats.userId = 'u1';

      expect(await stats.getLensSets(from, to), isEmpty);
      expect(service.lensSetsCalls, [(from, to, 'u1')]);
      expect(notifications, 0);
    });

    test('getRecap reads the period for the user and folds it, holding nothing or notifying', () async {
      final period = RecapPeriod.month(DateTime(2026, 9, 18));
      final start = DateTime(2026, 9, 2, 18);
      service.recapWorkoutsToReturn = [(id: 'w1', start: start, trained: const Duration(minutes: 50))];
      service.recapSetsToReturn = [
        (
          workoutId: 'w1',
          exerciseId: 'bench',
          start: start,
          category: Category.barbell,
          movement: Movement.empty(),
          muscles: MuscleTagging.empty(),
          target: Target.chest,
          weight: 60.0,
          reps: 5,
          duration: null,
          distance: null,
          drop: false,
          continuesEffort: false,
        ),
      ];
      stats.userId = 'u1';

      final recap = await stats.getRecap(
        period,
        firstWeekday: DateTime.monday,
        weightUnit: MeasurementUnit.metric,
        now: DateTime(2026, 10, 1),
      );

      expect(service.recapCalls, [
        (DateTime(2026, 9), DateTime(2026, 10), 'u1'),
        (DateTime(2026, 9), DateTime(2026, 10), 'u1'),
      ]);
      expect(recap.workouts, 1);
      expect(recap.volume, 300);
      expect(notifications, 0);
    });

    test('getRecapMonths reads every finished workout before this month, for the user', () async {
      service.recapWorkoutsToReturn = [
        (id: 'w1', start: DateTime(2026, 9, 2, 18), trained: const Duration(minutes: 50)),
        (id: 'w2', start: DateTime(2026, 7, 2, 18), trained: const Duration(minutes: 50)),
      ];
      stats.userId = 'u1';

      final months = await stats.getRecapMonths(now: DateTime(2026, 10, 18));

      expect(service.recapCalls, [(DateTime(1970), DateTime(2026, 10), 'u1')]);
      expect(months, {DateTime(2026, 9): 1, DateTime(2026, 7): 1});
    });
  });

  group('training charts (#137)', () {
    late RecordingStatsService service;
    late Stats stats;

    // a Wednesday; weeks start on Monday unless a test says otherwise
    final now = DateTime(2026, 10, 14, 18);

    WorkoutTotals workout(DateTime start, {int minutes = 60, int sets = 10, double volume = 1000}) {
      return (start: start, duration: Duration(minutes: minutes), sets: sets, volume: volume);
    }

    setUp(() {
      service = RecordingStatsService();
      stats = Stats(onError: null, service: service)..userId = 'muffin';
    });

    test('a weekly series reads eight of the user\'s weeks, newest first, a quiet week a zero', () async {
      service.totalsToReturn = [
        workout(DateTime(2026, 10, 12, 9), volume: 1500),
        workout(DateTime(2026, 10, 13, 9), volume: 500),
        workout(DateTime(2026, 9, 29, 9), volume: 800),
      ];

      final series = await stats.getTrainingSeries(.volume, .week, firstWeekday: DateTime.monday, now: now);

      expect(service.totalsCalls.single, (DateTime(2026, 8, 24), DateTime(2026, 10, 15), 'muffin'));
      expect(series, hasLength(trainingWeeks));
      expect(series[0], (2000.0, DateTime(2026, 10, 12)));
      expect(series[1], (0.0, DateTime(2026, 10, 5)));
      expect(series[2], (800.0, DateTime(2026, 9, 28)));
    });

    test('the first weekday moves where a workout falls', () async {
      // a Sunday: the end of a Monday week, the start of a Sunday one
      service.totalsToReturn = [workout(DateTime(2026, 10, 11, 9), sets: 12)];

      final monday = await stats.getTrainingSeries(.sets, .week, firstWeekday: DateTime.monday, now: now);
      final sunday = await stats.getTrainingSeries(.sets, .week, firstWeekday: DateTime.sunday, now: now);

      expect(monday[1], (12, DateTime(2026, 10, 5)));
      expect(sunday[0], (12, DateTime(2026, 10, 11)));
    });

    test('a monthly series reads six calendar months', () async {
      service.totalsToReturn = [
        workout(DateTime(2026, 10, 1, 9), sets: 4),
        workout(DateTime(2026, 9, 30, 21), sets: 6),
      ];

      final series = await stats.getTrainingSeries(.sets, .month, firstWeekday: DateTime.monday, now: now);

      expect(service.totalsCalls.single.$1, DateTime(2026, 5));
      expect(series.map((point) => point.$2), [
        for (final month in [10, 9, 8, 7, 6, 5]) DateTime(2026, month),
      ]);
      expect(series.take(2), [(4, DateTime(2026, 10)), (6, DateTime(2026, 9))]);
    });

    test('duration is the average workout, and a period with none has no point', () async {
      service.totalsToReturn = [
        workout(DateTime(2026, 10, 12, 9), minutes: 40),
        workout(DateTime(2026, 10, 13, 9), minutes: 80),
        workout(DateTime(2026, 9, 29, 9), minutes: 50),
      ];

      final series = await stats.getTrainingSeries(.duration, .week, firstWeekday: DateTime.monday, now: now);

      expect(series, [(3600.0, DateTime(2026, 10, 12)), (3000.0, DateTime(2026, 9, 28))]);
    });

    test('a workout with no time leaves the average duration alone', () async {
      service.totalsToReturn = [
        workout(DateTime(2026, 10, 12, 9), minutes: 60),
        workout(DateTime(2026, 10, 13, 9), minutes: 0),
      ];

      final series = await stats.getTrainingSeries(.duration, .week, firstWeekday: DateTime.monday, now: now);

      expect(series.first, (3600.0, DateTime(2026, 10, 12)));
    });

    test('nothing but zeros is no series at all', () async {
      service.totalsToReturn = [workout(DateTime(2026, 10, 12, 9), volume: 0)];

      expect(await stats.getTrainingSeries(.volume, .week, firstWeekday: DateTime.monday, now: now), isEmpty);
      expect(await stats.getTrainingSeries(.sets, .week, firstWeekday: DateTime.monday, now: now), isNotEmpty);
    });

    test('exercise days add up one exercise\'s sets per local day', () async {
      LensSets row(String exercise, DateTime start, int sets) {
        return (
          workoutId: 'w',
          exerciseId: exercise,
          start: start,
          movement: Movement.empty(),
          muscles: MuscleTagging.empty(),
          target: Target.chest,
          sets: sets,
        );
      }

      service.lensSetsToReturn = [
        row('bench', DateTime(2026, 10, 12, 8), 3),
        row('bench', DateTime(2026, 10, 12, 19), 2),
        row('squat', DateTime(2026, 10, 12, 8), 5),
        row('bench', DateTime(2026, 10, 1, 8), 4),
      ];

      final days = await stats.getExerciseDays('bench', firstWeekday: DateTime.monday, now: now);

      expect(service.lensSetsCalls.single.$1, DateTime(2026, 7, 27));
      expect(days, {DateTime(2026, 10, 12): 5, DateTime(2026, 10, 1): 4});
    });
  });

  group('Stats with Provider (widget)', () {
    testWidgets('of(context) returns the same instance as provided', (tester) async {
      late Stats fromOf;
      final service = RecordingStatsService();
      final provided = Stats(onError: null, service: service);

      await tester.pumpWidget(
        ChangeNotifierProvider<Stats>.value(
          value: provided,
          child: Builder(
            builder: (context) {
              fromOf = Stats.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(fromOf, provided), isTrue);
    });

    testWidgets('the chart rebuilds when the weeks change, not on a read that found the same ones', (tester) async {
      final service = RecordingStatsService();
      final provided = Stats(onError: null, service: service)..userId = 'u1';

      var builds = 0;
      // what the Profile's chart listens with
      final consumer = Selector<Stats, WorkoutAggregation>(
        selector: (_, stats) => stats.workouts,
        builder: (_, workouts, _) {
          builds++;
          return Text('empty=${workouts.isEmpty}', textDirection: TextDirection.ltr);
        },
      );

      await tester.pumpWidget(ChangeNotifierProvider<Stats>.value(value: provided, child: consumer));
      expect(builds, 1);

      // empty over empty: the revision moves, the chart stays
      await provided.init();
      await tester.pump();
      expect(provided.revision, 1);
      expect(builds, 1);

      service.workoutSummary = WorkoutAggregation.fromRows([
        {'id': '2025-08-03T10:00:00Z', 'name': 'Evening', 'start': '2025-08-03T10:00:00Z'},
      ]);
      await provided.init();
      await tester.pump();
      expect(builds, 2);
      expect(find.text('empty=false'), findsOneWidget);
    });
  });
}
