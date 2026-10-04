import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';

/// Composing a new goal, and editing an existing one's target.
///
/// `new_goal.dart` lived inside the profile screen's private part library
/// until now, so nothing outside it could ever build one — this pumps the two
/// dialogs it exposes directly and asserts against the fake service the way
/// `goals_card_test.dart` does for the card.
void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late Goals goals;
  late Exercises exercises;
  late Preferences preferences;

  const userId = 'user-1';
  final bench = Exercise(name: 'Bench Press (Barbell)', category: .barbell, target: .chest);

  setUp(() async {
    local = _FakeLocal();
    remote = _FakeRemote();
    goals = Goals(service: local, remoteService: remote)..userId = userId;

    // Uninitialized, like goals_card_test: nothing here needs a real exercise
    // list, since a target dialog is handed its exercise directly and the only
    // path that reads Exercises is cancelling out of the picker.
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  /// Mirrors `_GoalsCardState._addGoal`: the card's own reaction to a refused
  /// create, reproduced here so the cap's message can be asserted without
  /// pulling in `GoalsCard` itself.
  Future<void> addGoal(BuildContext context, TextEditingController controller, FocusNode focus) async {
    final state = Goals.of(context);
    final goal = await showNewGoalDialog(context, controller, focus);
    if (goal == null) return;

    try {
      await state.create(goal);
    } on GoalRejected catch (rejection) {
      if (!context.mounted) return;
      snack(context, rejection.isAtCapacity ? L.of(context).goalsAtCapacity : rejection.toString());
    }
  }

  Future<void> editGoal(BuildContext context, Goal goal, {required Exercise? exercise}) async {
    final edited = await showGoalTargetDialog(context, exercise: exercise, metric: goal.metric, goal: goal);
    if (edited == null) return;
    await Goals.of(context).update(edited);
  }

  Future<void> pump(
    WidgetTester tester, {
    Goal? editing,
    Exercise? exerciseForEdit,
  }) {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Goals>.value(value: goals),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          // the exercise picker's search field scrolls its results with this
          Provider<Scrolls>.value(value: Scrolls()),
          // and ranks them by what was done last; nothing has been, here
          ChangeNotifierProvider<PreviousExercises>(
            create: (_) => PreviousExercises(service: MockPreviousExerciseService()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      key: const Key('open-new'),
                      onPressed: () => addGoal(context, controller, focus),
                      child: const Text('open-new'),
                    ),
                    if (editing != null)
                      ElevatedButton(
                        key: const Key('open-edit'),
                        onPressed: () => editGoal(context, editing, exercise: exerciseForEdit),
                        child: const Text('open-edit'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  group('picking what to measure', () {
    testWidgets('offers workouts and per-exercise metrics', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('open-new')));
      await tester.pumpAndSettle();

      expect(find.text('New goal'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
    });

    testWidgets('cancelling the exercise picker leaves the first step behind', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('open-new')));
      await tester.pumpAndSettle();

      // not pumpAndSettle: an uninitialized Exercises spins a
      // CircularProgressIndicator inside the picker, which never settles
      await tester.tap(find.text('Exercises'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // the exercise picker opened as its own dialog, stacked on the first
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // picked == null, so nothing advances: the picker is gone and the first
      // step is still open behind where it was, with nothing created
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text('Workouts'), findsOneWidget);
      expect(local.goals, isEmpty);
    });
  });

  group('a workouts goal', () {
    Future<void> openWorkoutsTarget(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();
    }

    testWidgets('disables the submit button until a usable target is typed', (tester) async {
      await pump(tester);
      await openWorkoutsTarget(tester);

      Widget submit() => tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Add goal'));
      expect(submit(), isA<PrimaryButton>().having((b) => b.onPressed, 'onPressed', isNull));

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(submit(), isA<PrimaryButton>().having((b) => b.onPressed, 'onPressed', isNull));

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      expect(submit(), isA<PrimaryButton>().having((b) => b.onPressed, 'onPressed', isNotNull));
    });

    testWidgets('defaults to a weekly cadence and creates the goal on submit', (tester) async {
      await pump(tester);
      await openWorkoutsTarget(tester);

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add goal'));
      await tester.pumpAndSettle();

      expect(local.goals, hasLength(1));
      final saved = local.goals.single;
      expect(saved.metric, GoalMetric.workouts);
      expect(saved.cadence, GoalCadence.week);
      expect(saved.stages.single.target, 4);
      expect(saved.exerciseId, isNull);
      // the fake remote confirmed it too — not just written locally
      expect(remote.goals, hasLength(1));
    });

    testWidgets('switches to monthly when that segment is picked', (tester) async {
      await pump(tester);
      await openWorkoutsTarget(tester);

      await tester.tap(find.text('Monthly'));
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add goal'));
      await tester.pumpAndSettle();

      expect(local.goals.single.cadence, GoalCadence.month);
    });

    testWidgets('switches to a one-off milestone when that segment is picked', (tester) async {
      await pump(tester);
      await openWorkoutsTarget(tester);

      await tester.tap(find.text('Milestone'));
      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add goal'));
      await tester.pumpAndSettle();

      expect(local.goals.single.cadence, isNull);
    });
  });

  group('at capacity', () {
    testWidgets('discards the local goal and says why when the server refuses it', (tester) async {
      remote.rejectNextCreate = const GoalRejected('goal_limit');

      await pump(tester);
      await tester.tap(find.byKey(const Key('open-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Add goal'));
      await tester.pumpAndSettle();

      // the refused create is undone rather than left to look saved
      expect(local.goals, isEmpty);
      expect(find.textContaining('Delete one'), findsOneWidget);
    });
  });

  group('editing an existing goal\'s target', () {
    Goal ladder({required num currentTarget, required num nextTarget, bool firstAchieved = true}) {
      return Goal(
        id: 'goal-1',
        metric: .topSetWeight,
        exerciseId: bench.id,
        stages: [
          GoalStage(
            id: 's0',
            target: currentTarget,
            achievedAt: firstAchieved ? DateTime.utc(2026, 1, 1) : null,
          ),
          GoalStage(id: 's1', target: nextTarget),
        ],
      );
    }

    testWidgets('prefills the stage still being worked toward, in the user\'s own units', (tester) async {
      final goal = ladder(currentTarget: 100, nextTarget: 140);
      await pump(tester, editing: goal, exerciseForEdit: bench);

      await tester.tap(find.byKey(const Key('open-edit')));
      await tester.pumpAndSettle();

      // stage s0 is already achieved, so the current stage is s1 at 140
      expect(find.text('140'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('rewrites only the current stage, leaving the rest of the ladder alone', (tester) async {
      local.goals.add(ladder(currentTarget: 100, nextTarget: 140));

      final goal = ladder(currentTarget: 100, nextTarget: 140);
      await pump(tester, editing: goal, exerciseForEdit: bench);

      await tester.tap(find.byKey(const Key('open-edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '150');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = local.goals.single;
      expect(saved.stages, hasLength(2));
      // the achieved rung keeps its id, target and stamp
      expect(saved.stages.first.id, 's0');
      expect(saved.stages.first.target, 100);
      expect(saved.stages.first.achievedAt, isNotNull);
      // only the rung being worked toward changed
      expect(saved.stages.last.id, 's1');
      expect(saved.stages.last.target, 150);
    });

    testWidgets('prefills the last stage once every rung is already met', (tester) async {
      final goal = Goal(
        id: 'goal-2',
        metric: .topSetWeight,
        exerciseId: bench.id,
        stages: [GoalStage(id: 's0', target: 200, achievedAt: DateTime.utc(2026, 1, 1))],
      );
      await pump(tester, editing: goal, exerciseForEdit: bench);

      await tester.tap(find.byKey(const Key('open-edit')));
      await tester.pumpAndSettle();

      expect(find.text('200'), findsOneWidget);
    });
  });
}

class _FakeLocal implements LocalGoalService {
  final goals = <Goal>[];
  var _nextId = 0;

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    // a real local database mints an id on insert; `Goals.create` cannot
    // proceed past the write without one
    final created = goal.copyWith(id: goal.id ?? 'local-${_nextId++}');
    goals.add(created);
    return created;
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    final index = goals.indexWhere((each) => each.id == goalId);
    if (index != -1) goals[index] = goal;
    return goal;
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

  /// Set by the "at capacity" group to simulate the server's INSERT refusing
  /// the next create, the one refusal a locally-valid create can still hit.
  GoalRejected? rejectNextCreate;

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    return goals.where((each) => each.archived == archived).toList();
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    if (rejectNextCreate case final GoalRejected rejection) {
      rejectNextCreate = null;
      throw {'code': rejection.code};
    }
    goals.add(goal);
    return goal;
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    goals.removeWhere((each) => each.id == goalId);
    goals.add(goal);
    return goal;
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
}
