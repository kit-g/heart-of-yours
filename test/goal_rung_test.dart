import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';

/// Adding and editing a rung, through the ladder that opens it.
///
/// `rung.dart`'s dialog and `ladder.dart`'s `_addRung`/`_edit` are exercised
/// together here, the way a user actually reaches either — a rung is never
/// opened except from the ladder, and the round trip through `Goals.update` is
/// the thing worth proving works, not just that a dialog closes.
void main() {
  late _FakeLocal local;
  late _FakeRemote remote;
  late Goals goals;
  late Exercises exercises;
  late Preferences preferences;

  const userId = 'user-1';

  setUp(() async {
    local = _FakeLocal();
    remote = _FakeRemote();
    goals = Goals(service: local, remoteService: remote)..userId = userId;

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

  /// Scoped to the open dialog: the ladder underneath can carry a same-labelled
  /// button of its own (`AppKeys.addRung` also reads "Add milestone"), and an
  /// unscoped text lookup finds both.
  Finder dialogButton(String text) {
    return find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(PrimaryButton, text));
  }

  Future<void> pump(WidgetTester tester, Goal goal) {
    local.goals
      ..clear()
      ..add(goal);

    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Goals>.value(value: goals),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
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

  group('adding a rung to a milestone ladder', () {
    Goal milestone() {
      return Goal(
        id: 'goal-1',
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        stages: [GoalStage(id: 's0', target: 100)],
      );
    }

    testWidgets('offers a deadline to set, and disables submit until a target is typed', (tester) async {
      await pump(tester, milestone());

      await tester.tap(find.byKey(AppKeys.addRung));
      await tester.pumpAndSettle();

      expect(find.text('Target'), findsOneWidget);
      expect(find.byKey(AppKeys.rungDueDate), findsOneWidget);
      expect(find.text('Set a deadline'), findsOneWidget);

      final submit = dialogButton('Add milestone');
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '140');
      await tester.pump();
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNotNull);
    });

    testWidgets('appends the rung without a deadline when none is set', (tester) async {
      await pump(tester, milestone());

      await tester.tap(find.byKey(AppKeys.addRung));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '140');
      await tester.pump();
      await tester.tap(dialogButton('Add milestone'));
      await tester.pumpAndSettle();

      final saved = local.goals.single;
      expect(saved.stages, hasLength(2));
      expect(saved.stages.first.target, 100, reason: 'the original rung is untouched');
      expect(saved.stages.last.target, 140);
      expect(saved.stages.last.dueOn, isNull);
    });
  });

  group('editing an unmet rung on a milestone ladder', () {
    Goal withDeadline() {
      return Goal(
        id: 'goal-1',
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        stages: [GoalStage(id: 's0', target: 100, dueOn: DateTime(2026, 12, 25))],
      );
    }

    testWidgets('prefills the target and offers to clear the existing deadline', (tester) async {
      await pump(tester, withDeadline());

      await tester.tap(find.byKey(AppKeys.ladderRung('s0')));
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      // the exact button label, not the ladder row's own "Due Dec 25, 2026"
      expect(find.text('Dec 25, 2026'), findsOneWidget);
      expect(find.text('Clear deadline'), findsOneWidget);
      // this is an edit, not an add
      expect(dialogButton('Save'), findsOneWidget);
    });

    testWidgets('keeps the deadline when only the target changes', (tester) async {
      await pump(tester, withDeadline());

      await tester.tap(find.byKey(AppKeys.ladderRung('s0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '120');
      await tester.pump();
      await tester.tap(dialogButton('Save'));
      await tester.pumpAndSettle();

      final stage = local.goals.single.stages.single;
      expect(stage.id, 's0', reason: 'the id survives so an achievement would too');
      expect(stage.target, 120);
      expect(stage.dueOn, DateTime(2026, 12, 25));
    });

    testWidgets('clears the deadline on request', (tester) async {
      await pump(tester, withDeadline());

      await tester.tap(find.byKey(AppKeys.ladderRung('s0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear deadline'));
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(local.goals.single.stages.single.dueOn, isNull);
    });
  });

  group('a recurring goal has no deadline to edit', () {
    Goal recurring() {
      return Goal(
        id: 'goal-1',
        metric: .workouts,
        cadence: .week,
        stages: [GoalStage(id: 's0', target: 4)],
      );
    }

    testWidgets('offers no date control, only the target', (tester) async {
      await pump(tester, recurring());

      await tester.tap(find.byKey(AppKeys.ladderRung('s0')));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.rungDueDate), findsNothing);
      expect(find.text('Set a deadline'), findsNothing);
      expect(find.text('Clear deadline'), findsNothing);
    });

    testWidgets('still saves an edited target', (tester) async {
      await pump(tester, recurring());

      await tester.tap(find.byKey(AppKeys.ladderRung('s0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = local.goals.single;
      expect(saved.cadence, GoalCadence.week);
      expect(saved.stages.single.target, 5);
    });
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
