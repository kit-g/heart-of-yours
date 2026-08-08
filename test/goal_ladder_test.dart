import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The rung list — where a ladder is actually built.
///
/// Its rules are the ones a row could never express: which rung you are on,
/// when an earlier one fell, and whether this shape of goal has a ladder at all.
void main() {
  late Preferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Goal ladder(List<GoalStage> stages, {GoalCadence? cadence, GoalMetric metric = GoalMetric.topSetWeight}) {
    return Goal(
      id: 'goal-1',
      metric: metric,
      exerciseId: metric.isWholeWorkout ? null : 'exercise-1',
      cadence: cadence,
      stages: stages,
    );
  }

  Future<void> pump(WidgetTester tester, Goal goal) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalLadder(goal: goal, settings: preferences),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('lists every rung with its target', (tester) async {
    await pump(
      tester,
      ladder([
        GoalStage(id: 's0', target: 100),
        GoalStage(id: 's1', target: 140),
      ]),
    );

    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('140 kg'), findsOneWidget);
  });

  testWidgets('states when a rung fell rather than when it was due', (tester) async {
    // once a target has been met its old deadline stops being the useful fact
    await pump(
      tester,
      ladder([
        GoalStage(
          id: 's0',
          target: 100,
          dueOn: DateTime(2026, 12, 25),
          achievedAt: DateTime.utc(2026, 6, 1),
        ),
      ]),
    );

    expect(find.textContaining('Achieved'), findsOneWidget);
    expect(find.textContaining('Due'), findsNothing);
  });

  testWidgets('shows a deadline on a rung still ahead', (tester) async {
    await pump(tester, ladder([GoalStage(id: 's0', target: 100, dueOn: DateTime(2026, 12, 25))]));

    expect(find.textContaining('Due'), findsOneWidget);
  });

  testWidgets('says so when a rung has no deadline', (tester) async {
    await pump(tester, ladder([GoalStage(id: 's0', target: 100)]));

    expect(find.text('No deadline'), findsOneWidget);
  });

  testWidgets('offers another rung on a milestone goal', (tester) async {
    await pump(tester, ladder([GoalStage(id: 's0', target: 100)]));

    expect(find.byKey(AppKeys.addRung), findsOneWidget);
  });

  testWidgets('offers no rungs on a recurring goal, which has one standing target', (tester) async {
    // the server enforces this too: a cadence goal is allowed exactly one stage
    await pump(
      tester,
      ladder(
        [GoalStage(id: 's0', target: 4)],
        cadence: .week,
        metric: .workouts,
      ),
    );

    expect(find.byKey(AppKeys.addRung), findsNothing);
  });

  testWidgets('a lone rung cannot be swiped away, since a goal needs one', (tester) async {
    await pump(tester, ladder([GoalStage(id: 's0', target: 100)]));

    expect(find.byKey(AppKeys.ladderRung('s0')), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('rungs can be swiped away once there is more than one', (tester) async {
    await pump(
      tester,
      ladder([
        GoalStage(id: 's0', target: 100),
        GoalStage(id: 's1', target: 140),
      ]),
    );

    expect(find.byType(Dismissible), findsNWidgets(2));
  });
}
