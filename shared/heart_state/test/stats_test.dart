import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/stats.dart';
import 'package:provider/provider.dart';

class RecordingStatsService implements StatsService {
  WorkoutAggregation workoutSummary = WorkoutAggregation.empty();
  final List<DateTime> weeklyCountCalls = [];
  int weeklyCountToReturn = 0;

  @override
  Future<WorkoutAggregation> getWorkoutSummary({int? weeksBack, String? userId}) async {
    return workoutSummary;
  }

  @override
  Future<int> getWeeklyWorkoutCount(DateTime d) async {
    weeklyCountCalls.add(d);
    return weeklyCountToReturn;
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

    test('init does nothing and does not notify when local summary is empty', () async {
      service.workoutSummary = WorkoutAggregation.empty();

      expect(stats.workouts.isNotEmpty, isFalse);
      await stats.init();

      expect(stats.workouts.isNotEmpty, isFalse);
      expect(notifications, 0);
    });

    test('onSignOut resets workouts to empty without notifying', () async {
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
      expect(notifications, 0, reason: 'onSignOut should not call notifyListeners');
    });

    test('getWeeklyWorkoutCount delegates to service and returns expected value', () async {
      final when = DateTime(2025, 8, 10);
      service.weeklyCountToReturn = 5;

      final result = await stats.getWeeklyWorkoutCount(when);

      expect(result, 5);
      expect(service.weeklyCountCalls, [when]);
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

    testWidgets('watch(context) rebuilds only when notifyListeners is called by init with data', (tester) async {
      final service = RecordingStatsService();
      final provided = Stats(onError: null, service: service);

      // First: empty summary -> init should not notify
      service.workoutSummary = WorkoutAggregation.empty();

      var builds = 0;
      Widget consumer() {
        return Builder(
          builder: (context) {
            final isEmpty = Stats.watch(context).workouts.isEmpty;
            builds++;
            return Text('empty=$isEmpty', textDirection: TextDirection.ltr);
          },
        );
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<Stats>.value(
          value: provided,
          child: consumer(),
        ),
      );

      final initialBuilds = builds;
      expect(initialBuilds, 1);

      // init with empty -> no notify/rebuild
      await provided.init();
      await tester.pump();
      expect(builds, initialBuilds);

      // Now set non-empty and call init again -> should notify and rebuild
      service.workoutSummary = WorkoutAggregation.fromRows([
        {
          'id': '2025-08-03T10:00:00Z',
          'name': 'Evening',
          'start': '2025-08-03T10:00:00Z',
        },
      ]);
      await provided.init();
      await tester.pump();
      expect(builds, initialBuilds + 1);

      // Widget still present
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
