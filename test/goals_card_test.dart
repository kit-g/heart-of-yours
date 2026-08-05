import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';

/// The goals card, pumped directly.
///
/// This is the coverage the feature shipped without: everything lived inside
/// the profile screen's part library and was private, so nothing could build
/// one. Both bugs that reached the simulator — a crash during route teardown
/// and a `LateError` from reading units before they loaded — are the kind that
/// die here rather than on a device.
void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late Goals goals;
  late Exercises exercises;
  late Preferences preferences;

  const userId = 'user-1';

  Goal workoutsGoal({String id = 'goal-1', num target = 4}) {
    return Goal(
      id: id,
      metric: .workouts,
      cadence: .week,
      stages: [GoalStage(id: '${id}s0', target: target)],
    );
  }

  Goal benchGoal({String id = 'goal-2', num target = 100}) {
    return Goal(
      id: id,
      metric: .topSetWeight,
      exerciseId: 'exercise-1',
      stages: [GoalStage(id: '${id}s0', target: target)],
    );
  }

  Future<void> seed(List<Goal> seeded) async {
    local.goals.addAll(seeded);
    remote.goals.addAll(seeded);
    await goals.init();
  }

  setUp(() async {
    local = _FakeLocal();
    remote = _FakeRemote();
    goals = Goals(service: local, remoteService: remote)..userId = userId;

    // never initialized, so nothing is stubbed: an Exercises with no userId
    // answers metric queries with null, which is what a goal with no history
    // looks like anyway
    exercises = Exercises(remoteService: MockRemoteExerciseService(), service: MockExerciseService());

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pump(WidgetTester tester, {Preferences? settings}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Goals>.value(value: goals),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: settings ?? preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: GoalsCard(workouts: WorkoutAggregation.empty()),
          ),
        ),
      ),
    );
  }

  testWidgets('says so when there is nothing to show', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsOneWidget);
  });

  testWidgets('renders a row per goal', (tester) async {
    await seed([workoutsGoal(), benchGoal()]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsNothing);
    expect(find.byType(GoalRow), findsNWidgets(2));
  });

  testWidgets('states a recurring target with its period', (tester) async {
    await seed([workoutsGoal(target: 4)]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Workouts'), findsOneWidget);
    // no current value: the weekly count needs an aggregation this test has
    // none of, and a wrong number would be worse than none
    expect(find.text('4 · per week'), findsOneWidget);
  });

  testWidgets('builds before preferences have loaded, rather than throwing', (tester) async {
    // `Preferences` reads from disk without being awaited at startup and its
    // unit fields are `late`; this card can paint first. Reading one here threw
    // a LateError on every launch that had a goal.
    await seed([benchGoal()]);

    await pump(tester, settings: Preferences());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GoalRow), findsOneWidget);
  });

  testWidgets('deleting a row removes the goal', (tester) async {
    await seed([workoutsGoal(id: 'goal-1')]);

    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.deleteGoal('goal-1')));
    await tester.pumpAndSettle();

    expect(goals, isEmpty);
    expect(find.text('No goals yet'), findsOneWidget);
  });
}

class _FakeLocal implements LocalGoalService {
  final goals = <Goal>[];

  @override
  Future<Iterable<Goal>> getGoals(String userId) async => List.of(goals);

  @override
  Future<Goal> createGoal(Goal goal, String userId) async => goal;

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async => goal;

  @override
  Future<void> deleteGoal(String goalId, String userId) async {
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) async {
    return goals.firstWhere((each) => each.id == goalId);
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId) async {
    this.goals
      ..clear()
      ..addAll(goals);
  }

  @override
  Future<Iterable<Goal>> unsyncedGoals(String userId) async => const [];

  @override
  Future<void> reconcileGoalId(String localId, Goal saved, String userId) async {}
}

class _FakeRemote implements GoalService {
  final goals = <Goal>[];

  @override
  Future<Iterable<Goal>> getGoals(String userId) async => List.of(goals);

  @override
  Future<Goal> createGoal(Goal goal, String userId) async => goal;

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async => goal;

  @override
  Future<void> deleteGoal(String goalId, String userId) async {
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(String goalId, String stageId, String userId, DateTime achievedAt) async {
    return goals.firstWhere((each) => each.id == goalId);
  }
}
