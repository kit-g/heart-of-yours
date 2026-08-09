import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';

/// Goal rungs drawn across the dashboard's charts.
///
/// The join is the fiddly part: a chart is addressed by exercise *name* and a
/// goal by exercise *id*, and the target is stored in one unit while the series
/// is plotted in another. Both are the kind of mistake that renders — a line in
/// the wrong place looks exactly like a line in the right place.
void main() {
  late Exercises exercises;
  late Preferences preferences;

  // the factory mints the id, so goals are pointed at whatever it minted
  final bench = Exercise(name: 'Bench press', category: .barbell, target: .chest);
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);

  Goal goal({
    String id = 'goal-1',
    GoalMetric metric = GoalMetric.topSetWeight,
    String? exerciseId,
    GoalCadence? cadence,
    List<GoalStage>? stages,
  }) {
    return Goal(
      id: id,
      metric: metric,
      exerciseId: exerciseId ?? bench.id,
      cadence: cadence,
      stages: stages ?? [GoalStage(id: '${id}s0', target: 100)],
    );
  }

  setUp(() async {
    final local = MockExerciseService();
    final remote = MockRemoteExerciseService();

    when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat]));
    when(local.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(local.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(remoteService: remote, service: local);
    await exercises.init();

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  /// Runs [body] with a context that can resolve `L` and a theme.
  Future<void> withContext(WidgetTester tester, void Function(BuildContext context) body) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) {
            body(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  group('goalsOnChart', () {
    test('matches a goal to the chart of its own exercise and metric', () {
      final matching = goalsOnChart(
        [goal()],
        exerciseName: 'Bench press',
        metric: .topSetWeight,
        exercises: exercises,
      );

      expect(matching, hasLength(1));
    });

    test('leaves another exercise alone', () {
      // the id is what ties a goal to an exercise; the chart only knows the name
      final matching = goalsOnChart(
        [goal(exerciseId: squat.id)],
        exerciseName: 'Bench press',
        metric: .topSetWeight,
        exercises: exercises,
      );

      expect(matching, isEmpty);
    });

    test('leaves another metric on the same exercise alone', () {
      final matching = goalsOnChart(
        [goal(metric: .estimatedOneRepMax)],
        exerciseName: 'Bench press',
        metric: .topSetWeight,
        exercises: exercises,
      );

      expect(matching, isEmpty);
    });

    test('skips recurring goals, whose target is not on the series scale', () {
      // a per-week target against a chart of per-session values would draw a
      // line the points are not measured against
      final matching = goalsOnChart(
        [goal(cadence: .week)],
        exerciseName: 'Bench press',
        metric: .topSetWeight,
        exercises: exercises,
      );

      expect(matching, isEmpty);
    });

    test('skips a goal whose exercise the catalog has not loaded yet', () {
      final matching = goalsOnChart(
        [goal(exerciseId: 'never-seen')],
        exerciseName: 'Bench press',
        metric: .topSetWeight,
        exercises: exercises,
      );

      expect(matching, isEmpty);
    });
  });

  group('goalThresholds', () {
    final ladder = goal(
      stages: [
        GoalStage(id: 's0', target: 100, achievedAt: DateTime.utc(2026, 6, 1)),
        GoalStage(id: 's1', target: 110),
        GoalStage(id: 's2', target: 120),
      ],
    );

    testWidgets('draws the whole ladder by default', (tester) async {
      late List<ChartThreshold> drawn;
      await withContext(tester, (context) {
        drawn = goalThresholds(context, ladder, metric: .topSetWeight, settings: preferences);
      });

      expect(drawn.map((each) => each.value), [100, 110, 120]);
      expect(drawn.map((each) => each.reached), [true, false, false]);
    });

    testWidgets('draws only the rung being worked toward when asked', (tester) async {
      // the dashboard card has no room for a five-line ladder
      late List<ChartThreshold> drawn;
      await withContext(tester, (context) {
        drawn = goalThresholds(context, ladder, metric: .topSetWeight, settings: preferences, nextOnly: true);
      });

      expect(drawn.map((each) => each.value), [110]);
    });

    testWidgets('draws nothing for a finished ladder', (tester) async {
      final done = goal(
        stages: [GoalStage(id: 's0', target: 100, achievedAt: DateTime.utc(2026, 6, 1))],
      );

      late List<ChartThreshold> drawn;
      await withContext(tester, (context) {
        drawn = goalThresholds(context, done, metric: .topSetWeight, settings: preferences, nextOnly: true);
      });

      expect(drawn, isEmpty);
    });

    testWidgets('labels the line in the units the series is plotted in', (tester) async {
      late List<ChartThreshold> metric;
      late List<ChartThreshold> imperial;
      await withContext(tester, (context) {
        metric = goalThresholds(context, goal(), metric: .topSetWeight, settings: preferences);
        // the per-exercise chart page overrides the unit; a target converted
        // with the user default would land somewhere else entirely
        imperial = goalThresholds(
          context,
          goal(),
          metric: .topSetWeight,
          settings: preferences,
          unit: .imperial,
        );
      });

      expect(metric.single.value, 100);
      expect(metric.single.label, '100 kg');
      expect(imperial.single.value, closeTo(220.5, .1));
      expect(imperial.single.label, startsWith('220'));
    });

    testWidgets('stays empty before preferences have loaded, rather than throwing', (tester) async {
      // the unit fields are `late`; reading one early is what crashed the goals
      // card on launch
      late List<ChartThreshold> drawn;
      await withContext(tester, (context) {
        drawn = goalThresholds(context, goal(), metric: .topSetWeight, settings: Preferences());
      });

      expect(tester.takeException(), isNull);
      expect(drawn, isEmpty);
    });
  });
}
