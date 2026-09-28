import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/exercise_chart.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The full detail surface for one goal: its chart, and its ladder.
///
/// Pumped directly the way `goals_card_test.dart` pumps `GoalsCard` — the same
/// reason applies, this lived where nothing outside the profile screen's part
/// library could construct it.
void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late Goals goals;
  late Exercises exercises;
  late Stats stats;
  late Preferences preferences;

  const userId = 'user-1';
  final press = Exercise(name: 'Bench Press (Barbell)', category: .barbell, target: .chest);

  Goal workoutsGoal() {
    return Goal(
      id: 'goal-1',
      metric: .workouts,
      cadence: .week,
      stages: [GoalStage(id: 's0', target: 4)],
    );
  }

  Goal benchLadder({bool firstAchieved = true}) {
    return Goal(
      id: 'goal-2',
      metric: .topSetWeight,
      exerciseId: press.id,
      stages: [
        GoalStage(id: 's0', target: 100, achievedAt: firstAchieved ? DateTime.utc(2026, 1, 1) : null),
        GoalStage(id: 's1', target: 140),
      ],
    );
  }

  Goal benchMilestone() {
    return Goal(
      id: 'goal-3',
      metric: .topSetWeight,
      exerciseId: press.id,
      stages: [GoalStage(id: 's0', target: 100)],
    );
  }

  setUp(() async {
    local = _FakeLocal();
    remote = _FakeRemote();
    goals = Goals(service: local, remoteService: remote)..userId = userId;

    final service = MockExerciseService();
    final remoteExercise = MockRemoteExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [press]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remoteExercise.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(
      remoteService: remoteExercise,
      service: service,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    )..userId = userId;
    await exercises.init();

    stats = Stats(onError: null, service: MockLocalStatsService());

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pump(
    WidgetTester tester,
    Goal goal, {
    VoidCallback? onClose,
    Preferences? settings,
  }) {
    local.goals
      ..clear()
      ..add(goal);

    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Goals>.value(value: goals),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Stats>.value(value: stats),
          ChangeNotifierProvider<Preferences>.value(value: settings ?? preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 700,
              width: 400,
              child: GoalDetail(goal: goal, workouts: WorkoutAggregation.empty(), onClose: onClose),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('builds before preferences have loaded, rather than throwing', (tester) async {
    // same LateError this card once threw: units are `late` until Preferences
    // has initialized, and this sheet can be opened before that lands
    await pump(tester, workoutsGoal(), settings: Preferences());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('a whole-workout goal', () {
    testWidgets('states its title and has no chart to show', (tester) async {
      await pump(tester, workoutsGoal());
      await tester.pumpAndSettle();

      expect(find.text('Workouts'), findsOneWidget);
      // a whole-workout goal has no per-exercise chart: metric.chart is null
      expect(find.byType(ExerciseChart), findsNothing);
    });

    testWidgets('offers no rung to add — its cadence is the ladder', (tester) async {
      await pump(tester, workoutsGoal());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.addRung), findsNothing);
      expect(find.byKey(AppKeys.ladderRung('s0')), findsOneWidget);
    });
  });

  group('a per-exercise ladder', () {
    testWidgets('draws the chart with every rung on it', (tester) async {
      await pump(tester, benchLadder());
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseChart), findsOneWidget);
      expect(find.textContaining('Bench Press'), findsOneWidget);
    });

    testWidgets('lists a rung per stage', (tester) async {
      await pump(tester, benchLadder());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.ladderRung('s0')), findsOneWidget);
      expect(find.byKey(AppKeys.ladderRung('s1')), findsOneWidget);
    });
  });

  group('a single-stage milestone', () {
    testWidgets('lists exactly one rung, and still offers to add another', (tester) async {
      await pump(tester, benchMilestone());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.ladderRung('s0')), findsOneWidget);
      expect(find.byKey(AppKeys.ladderRung('s1')), findsNothing);
      expect(find.byKey(AppKeys.addRung), findsOneWidget);
    });
  });

  group('closing the sheet', () {
    testWidgets('calls back when the close button is tapped', (tester) async {
      var closed = false;
      await pump(tester, benchMilestone(), onClose: () => closed = true);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.closeGoalDetail));
      expect(closed, isTrue);
    });

    testWidgets('offers no close button when there is nowhere to close to', (tester) async {
      await pump(tester, benchMilestone());
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.closeGoalDetail), findsNothing);
    });
  });

  testWidgets('adding a rung here writes through to the goal service and the ladder redraws', (tester) async {
    await pump(tester, benchMilestone());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.addRung));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.pump();
    // scoped to the dialog: the ladder underneath carries its own
    // same-labelled "Add milestone" button
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(PrimaryButton, 'Add milestone')),
    );
    await tester.pumpAndSettle();

    // the write actually reached the fake service...
    final saved = local.goals.single;
    expect(saved.stages, hasLength(2));
    expect(saved.stages.last.target, 150);

    // ...and the sheet, watching Goals, now shows the new rung too
    expect(find.byKey(AppKeys.ladderRung('s0')), findsOneWidget);
    expect(find.byKey(AppKeys.ladderRung(saved.stages.last.id)), findsOneWidget);
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

  var _nextStageId = 0;

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    // a real database mints an id for a stage added without one, the way a new
    // rung arrives — the ladder addresses stages by id, so this keeps that
    // true here too
    final stages = goal.stages.map((stage) {
      return stage.id == null ? stage.copyWith(id: 'new-stage-${_nextStageId++}') : stage;
    }).toList();
    final saved = goal.copyWith(stages: stages);

    final index = goals.indexWhere((each) => each.id == goalId);
    if (index != -1) goals[index] = saved;
    return saved;
  }

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
