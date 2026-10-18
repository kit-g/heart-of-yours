import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

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
  late Stats stats;
  late MockLocalStatsService statsService;

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
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );

    statsService = MockLocalStatsService();
    stats = Stats(onError: null, service: statsService);

    // Programs is on by default and would read its own providers, which this
    // test of a widget without them does not build
    SharedPreferences.setMockInitialValues({'feature-programs': 'off'});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pump(WidgetTester tester, {Preferences? settings}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Goals>.value(value: goals),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          // a goal counting whole workouts asks Stats how many there are, so
          // every row resolves it whether or not this goal needs it
          ChangeNotifierProvider<Stats>.value(value: stats),
          ChangeNotifierProvider<Preferences>.value(value: settings ?? preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          // scrollable, as the profile screen always is: unbounded the card
          // grows with its list, and a long one overflows a bare test surface
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalsCard(workouts: WorkoutAggregation.empty()),
            ),
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
    // the count comes from a period-bounded query now rather than off the
    // aggregation, so it is answered even here — the stubbed service says none
    expect(find.text('0 / 4 · per week'), findsOneWidget);
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

  group('at capacity', () {
    List<Goal> many(int count) {
      return [for (var i = 0; i < count; i++) workoutsGoal(id: 'goal-$i')];
    }

    testWidgets('offers to add a goal while there is room', (tester) async {
      await seed(many(Goals.maxActive - 1));

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Add goal'), findsOneWidget);
      expect(find.byKey(AppKeys.goalsAtCapacity), findsNothing);
    });

    testWidgets('stops offering once the server would refuse another', (tester) async {
      // the cap is enforced in the INSERT, so the create would come back a 400
      await seed(many(Goals.maxActive));

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.text('Add goal'), findsNothing);
      expect(find.byKey(AppKeys.goalsAtCapacity), findsOneWidget);
    });

    testWidgets('says why the button is gone', (tester) async {
      await seed(many(Goals.maxActive));

      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.goalsAtCapacity));
      await tester.pumpAndSettle();

      expect(find.textContaining('Delete one'), findsOneWidget);
    });
  });

  testWidgets('reads Complete as soon as the last unmet rung goes', (tester) async {
    // deleting the rung above an achieved one leaves every rung met, so the
    // goal is complete — the card should say so without waiting for a relaunch
    final ladder = Goal(
      id: 'goal-1',
      metric: .topSetWeight,
      exerciseId: 'exercise-1',
      stages: [
        GoalStage(id: 's0', target: 100, achievedAt: DateTime.utc(2026, 6, 1)),
        GoalStage(id: 's1', target: 120),
      ],
    );
    await seed([ladder]);

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsNothing);

    await goals.update(ladder.copyWith(stages: [ladder.stages.first]));
    await tester.pumpAndSettle();

    expect(find.text('Complete'), findsOneWidget);
  });

  group('the achieved surface', () {
    Goal finished({String id = 'done-1'}) {
      return Goal(
        id: id,
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        archived: true,
        stages: [GoalStage(id: '${id}s', target: 100, achievedAt: DateTime.utc(2026, 8, 1))],
      );
    }

    testWidgets('offers nothing to flip to when nothing is achieved', (tester) async {
      await seed([workoutsGoal()]);

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.goalsViewAchieved), findsNothing);
    });

    testWidgets('offers the flip once a goal has been achieved', (tester) async {
      await seed([workoutsGoal(), finished()]);

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.goalsViewAchieved), findsOneWidget);
    });

    testWidgets('turns over to the achieved goals and back', (tester) async {
      await seed([workoutsGoal(id: 'live-1'), finished()]);

      await pump(tester);
      await tester.pumpAndSettle();

      // the live face: the goal being worked on, and the way to add another
      expect(find.byKey(AppKeys.goalRow('live-1')), findsOneWidget);
      expect(find.text('Add goal'), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.goalsViewAchieved));
      await tester.pumpAndSettle();

      // the back: only what is finished, and no invitation to add to it
      expect(find.byKey(AppKeys.goalRow('done-1')), findsOneWidget);
      expect(find.byKey(AppKeys.goalRow('live-1')), findsNothing);
      expect(find.text('Add goal'), findsNothing);
      expect(find.text('Achieved'), findsWidgets);

      await tester.tap(find.byKey(AppKeys.goalsViewActive));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.goalRow('live-1')), findsOneWidget);
      expect(find.byKey(AppKeys.goalRow('done-1')), findsNothing);
    });

    testWidgets('comes back to the live face when the last achieved goal goes', (tester) async {
      // otherwise the card is left showing an empty back with no way off it
      await seed([workoutsGoal(id: 'live-1'), finished()]);

      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.goalsViewAchieved));
      await tester.pumpAndSettle();

      await goals.remove(goals.archived.single);
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.goalRow('live-1')), findsOneWidget);
      expect(find.byKey(AppKeys.goalsViewAchieved), findsNothing);
    });
  });

  testWidgets('a swipe uncovers Delete, and only its tap deletes', (tester) async {
    await seed([workoutsGoal(id: 'goal-1')]);

    await pump(tester);
    await tester.pumpAndSettle();

    // even a full swipe only uncovers the button
    await tester.fling(find.byType(GoalRow), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(goals, hasLength(1));

    final delete = find.byKey(const ValueKey('GoalRow.goal-1.delete'));
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(goals, isEmpty);
    expect(find.text('No goals yet'), findsOneWidget);
  });

  testWidgets(
    "on a Pixel's width, a realistic swipe uncovers Delete",
    (tester) async {
      tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await seed([workoutsGoal(id: 'goal-1')]);
      await pump(tester);
      await tester.pumpAndSettle();

      // 40% of the row, over a third of a second, as a thumb does
      final row = find.byType(GoalRow);
      final width = tester.getSize(row).width;
      await tester.timedDrag(row, Offset(-width * .4, 0), const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final delete = find.byKey(const ValueKey('GoalRow.goal-1.delete'));
      // uncovered: the row has slid off it, so a tap there lands on the
      // button rather than on the row covering it
      expect(goals, hasLength(1));
      await tester.tap(delete, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(goals, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('an uncovered Delete closes on a tap of the row, and deletes nothing', (tester) async {
    await seed([workoutsGoal(id: 'goal-1')]);

    await pump(tester);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GoalRow), const Offset(-200, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(GoalRow), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(goals, hasLength(1));
    expect(tester.getTopLeft(find.byType(GoalRow)).dx, 0);
  });

  testWidgets('a screen reader deletes through the row action', (tester) async {
    await seed([workoutsGoal(id: 'goal-1')]);
    final semantics = tester.ensureSemantics();

    await pump(tester);
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(GoalRow));
    expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    semantics.dispose();
  });

  group('beside a running program (#353)', () {
    late Programs programs;

    Future<void> follow(Program program) async {
      final local = MockLocalProgramService();
      when(local.getPrograms(userId)).thenAnswer((_) async => [program]);
      when(local.getProgramActions(userId)).thenAnswer((_) async => []);
      when(local.getProgramBases(userId)).thenAnswer((_) async => []);
      when(local.getProgramsOwed(userId)).thenAnswer((_) async => []);
      when(local.getSkips(userId)).thenAnswer((_) async => []);
      when(local.getProgramMarks(userId, any)).thenAnswer((_) async => []);
      programs = Programs(
        service: local,
        remoteService: MockRemoteProgramService(),
        templates: MockTemplateService(),
        // the mirror is the whole story: no server to read over it
        remote: RemoteAccess(hasToken: () => false),
      )..userId = userId;
      await programs.init();
    }

    Future<void> pumpWith(WidgetTester tester, {bool on = true}) async {
      SharedPreferences.setMockInitialValues({'feature-programs': on ? 'on' : 'off'});
      final settings = Preferences();
      await settings.init();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<Goals>.value(value: goals),
            ChangeNotifierProvider<Exercises>.value(value: exercises),
            ChangeNotifierProvider<Stats>.value(value: stats),
            ChangeNotifierProvider<Preferences>.value(value: settings),
            ChangeNotifierProvider<Programs>.value(value: programs),
          ],
          child: MaterialApp(
            localizationsDelegates: localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: GoalsCard(workouts: WorkoutAggregation.empty())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final split = Program(id: 'p1', name: 'Split', perWeek: 3, sessions: const ['t1']);

    testWidgets('shows the goal it implies, labelled with it and never stored', (tester) async {
      await follow(split);

      await pumpWith(tester);

      expect(find.text('No goals yet'), findsNothing);
      expect(find.byKey(AppKeys.goalRow('program:p1:workouts')), findsOneWidget);
      expect(find.text('from Split'), findsOneWidget);
      expect(goals, isEmpty);
    });

    testWidgets("the program's cadence overrides the user's own, which is set aside, not edited", (tester) async {
      await seed([workoutsGoal(target: 2)]);
      await follow(split);

      await pumpWith(tester);

      // the program's 3 a week, and the user's 2 said under it
      expect(find.byKey(AppKeys.goalRow('program:p1:workouts')), findsOneWidget);
      expect(find.byKey(AppKeys.goalRow('goal-1')), findsNothing);
      expect(find.text('Your 2 a week is paused while you follow Split'), findsOneWidget);
      expect(goals.all.single.stages.single.target, 2);
    });

    testWidgets("the program's weekly goal counts the program's own sessions", (tester) async {
      // eight workouts this week, none of them the program's
      when(statsService.getWorkoutCountBetween(any, any, userId: anyNamed('userId'))).thenAnswer((_) async => 8);
      when(statsService.getWeeklyWorkoutCount(any, userId: anyNamed('userId'))).thenAnswer((_) async => 8);
      await follow(split);

      await pumpWith(tester);

      final row = find.byKey(AppKeys.goalRow('program:p1:workouts'));
      expect(find.descendant(of: row, matching: find.textContaining('0 / 3')), findsOneWidget);
    });

    testWidgets("with Programs off, the user's own weekly goal is back as it was", (tester) async {
      await seed([workoutsGoal(target: 2)]);
      await follow(split);

      await pumpWith(tester, on: false);

      expect(find.byKey(AppKeys.goalRow('goal-1')), findsOneWidget);
      expect(find.textContaining('is paused while you follow'), findsNothing);
    });

    testWidgets('with Programs off, goals are as they were', (tester) async {
      await follow(split);

      await pumpWith(tester, on: false);

      expect(find.text('No goals yet'), findsOneWidget);
      expect(find.text('from Split'), findsNothing);
    });
  });

  testWidgets('a half-hearted swipe puts the row back', (tester) async {
    await seed([workoutsGoal(id: 'goal-1')]);

    await pump(tester);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GoalRow), const Offset(-40, 0));
    await tester.pumpAndSettle();

    expect(goals, hasLength(1));
    expect(find.byType(GoalRow), findsOneWidget);
  });
}

class _FakeLocal implements LocalGoalService {
  final goals = <Goal>[];

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async => goal;

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async => goal;

  @override
  Future<void> deleteGoal(String goalId, String userId) async {
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    return goals.firstWhere((each) => each.id == goalId);
  }

  @override
  Future<void> storeGoals(Iterable<Goal> goals, String userId, {bool archived = false}) async {
    // one slice at a time, as the database does
    this.goals
      ..removeWhere((each) => each.archived == archived)
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
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async => goal;

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async => goal;

  @override
  Future<void> deleteGoal(String goalId, String userId) async {
    goals.removeWhere((each) => each.id == goalId);
  }

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    return goals.firstWhere((each) => each.id == goalId);
  }
}
