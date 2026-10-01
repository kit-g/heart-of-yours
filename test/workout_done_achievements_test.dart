import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The rungs a finished session earned, on the workout summary.
///
/// The screen is pushed the moment finishing *starts*, so this block resolves
/// asynchronously over the top of the confetti — which makes both the empty
/// case and the waiting case things a user actually sees.
void main() {
  late Exercises exercises;
  late Preferences preferences;

  final bench = Exercise(name: 'Bench Press (Barbell)', category: .barbell, target: .chest);

  Goal goal(String id, num target) {
    return Goal(
      id: id,
      metric: .topSetWeight,
      exerciseId: bench.id,
      stages: [GoalStage(id: '${id}s', target: target, achievedAt: DateTime.utc(2026, 8, 9))],
    );
  }

  setUp(() async {
    final service = MockExerciseService();
    final remote = MockRemoteExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(
      remoteService: remote,
      service: service,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    await exercises.init();

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pump(
    WidgetTester tester,
    Future<List<GoalAchievement>> Function() achievements, {
    Future<List<AchievedRecord>> Function()? records,
  }) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: WorkoutDone(
            workout: null,
            onQuit: () {},
            workoutsThisWeekCallback: () async => 0,
            achievementsCallback: achievements,
            recordsCallback: records ?? () async => const [],
          ),
        ),
      ),
    );
  }

  testWidgets('states the rung the session earned', (tester) async {
    await pump(tester, () async {
      final g = goal('goal-1', 180);
      return [(goal: g, stage: g.stages.single)];
    });
    await tester.pumpAndSettle();

    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.textContaining('Bench Press (Barbell)'), findsOneWidget);
    expect(find.textContaining('180 kg'), findsOneWidget);
  });

  testWidgets('survives a rebuild, having only one answer to give', (tester) async {
    // The observation stamps what it finds, so it reports a rung exactly once.
    // This block watches Preferences and Exercises, so any notification rebuilds
    // it — asking again from `build` made the congratulation vanish as fast as
    // it appeared.
    var asked = 0;
    await pump(tester, () async {
      asked++;
      final g = goal('goal-1', 180);
      return switch (asked) {
        1 => [(goal: g, stage: g.stages.single)],
        // the second answer is what the real observation gives: nothing new
        _ => const <GoalAchievement>[],
      };
    });
    await tester.pumpAndSettle();
    expect(find.text('Goal reached'), findsOneWidget);

    exercises.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('Goal reached'), findsOneWidget);
    expect(asked, 1);
  });

  testWidgets('pluralises when a session clears more than one', (tester) async {
    await pump(tester, () async {
      final first = goal('goal-1', 180);
      final second = goal('goal-2', 200);
      return [
        (goal: first, stage: first.stages.single),
        (goal: second, stage: second.stages.single),
      ];
    });
    await tester.pumpAndSettle();

    expect(find.text('Goals reached'), findsOneWidget);
  });

  testWidgets('arrives over a beat rather than appearing outright', (tester) async {
    // it lands into a screen that has already settled, so appearing instantly
    // reads as a glitch rather than as the session's one piece of news
    final pending = Completer<List<GoalAchievement>>();
    await pump(tester, () => pending.future);
    await tester.pump();

    final g = goal('goal-1', 180);
    pending.complete([(goal: g, stage: g.stages.single)]);
    await tester.pump();
    // one frame in, it is on its way but not yet arrived
    await tester.pump(const Duration(milliseconds: 60));

    final faded = tester.widget<FadeTransition>(
      find.ancestor(of: find.text('Goal reached'), matching: find.byType(FadeTransition)).first,
    );
    expect(faded.opacity.value, greaterThan(0));
    expect(faded.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('Goal reached'), findsOneWidget);
  });

  testWidgets('says nothing at all when the session earned none', (tester) async {
    // most sessions. A heading reading "0 goals reached" would turn a
    // congratulation into a report card.
    await pump(tester, () async => const []);
    await tester.pumpAndSettle();

    expect(find.textContaining('reached'), findsNothing);
  });

  AchievedRecord beat(Exercise exercise, RecordKind kind, Map record, Map previous) {
    return (exercise: exercise, kind: kind, record: {...record, 'workoutId': 'w2', 'previous': previous});
  }

  AchievedRecord first(Exercise exercise, RecordKind kind, Map record) {
    return (exercise: exercise, kind: kind, record: {...record, 'workoutId': 'w1'});
  }

  final squat = Exercise(name: 'Squat (Barbell)', category: .barbell, target: .legs);

  Future<void> pumpRecords(WidgetTester tester, List<AchievedRecord> records) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: WorkoutDone(
            workout: null,
            onQuit: () {},
            workoutsThisWeekCallback: () async => 0,
            achievementsCallback: () async => const [],
            recordsCallback: () async => records,
          ),
        ),
      ),
    );
  }

  testWidgets('badges the record the session set, with what it beat', (tester) async {
    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('New record'), findsOneWidget);
    expect(find.text('Bench Press (Barbell)'), findsOneWidget);
    expect(find.text('Max weight'), findsOneWidget);
    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('was 95 kg'), findsOneWidget);
  });

  testWidgets('a badge is one element to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('New record: Bench Press (Barbell), Max weight 100 kg, was 95 kg'),
      findsOneWidget,
    );
    // its parts are not announced again one by one
    expect(find.bySemanticsLabel('was 95 kg'), findsNothing);
    handle.dispose();
  });

  testWidgets("groups an exercise's records under one name, a badge each", (tester) async {
    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
      beat(
        bench,
        .oneRepMax,
        {'value': 112.5, 'weight': 100.0, 'reps': 5},
        {'value': 106.9, 'weight': 95.0, 'reps': 5},
      ),
      beat(squat, .maxWeight, {'weight': 140.0, 'reps': 3}, {'weight': 130.0, 'reps': 3}),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('New records'), findsOneWidget);
    expect(find.text('Bench Press (Barbell)'), findsOneWidget);
    expect(find.text('Squat (Barbell)'), findsOneWidget);
    expect(find.text('Max weight'), findsNWidgets(2));
    expect(find.text('Estimated 1RM'), findsOneWidget);
    expect(find.text('was 130 kg'), findsOneWidget);
  });

  testWidgets('a first workout sums its records up in one badge, not a wall', (tester) async {
    // every exercise on a new account's first session is a record — nothing
    // to beat yet — and a badge each would bury the screen
    final exercisesDone = List.generate(
      6,
      (i) => Exercise(name: 'Exercise $i', category: .barbell, target: .chest),
    );
    await pumpRecords(tester, [
      for (final exercise in exercisesDone) ...[
        first(exercise, .maxWeight, {'weight': 60.0, 'reps': 8}),
        first(exercise, .oneRepMax, {'value': 74.0, 'weight': 60.0, 'reps': 8}),
      ],
    ]);
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('first records'), findsOneWidget);
    expect(find.text('Max weight'), findsNothing);
    expect(find.textContaining('Exercise '), findsNothing);
  });

  testWidgets('firsts beside real records: badges for the beaten, a count for the rest', (tester) async {
    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
      first(squat, .maxWeight, {'weight': 80.0, 'reps': 5}),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('was 95 kg'), findsOneWidget);
    expect(find.text('Squat (Barbell)'), findsNothing);
    expect(find.text('first record'), findsOneWidget);
  });

  testWidgets('badges arrive one after another', (tester) async {
    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
      beat(squat, .maxWeight, {'weight': 140.0, 'reps': 3}, {'weight': 130.0, 'reps': 3}),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    double opacity(String text) {
      return tester
          .widget<FadeTransition>(find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first)
          .opacity
          .value;
    }

    expect(opacity('was 95 kg'), greaterThan(opacity('was 130 kg')));

    await tester.pumpAndSettle();
    expect(opacity('was 95 kg'), 1);
    expect(opacity('was 130 kg'), 1);
  });

  testWidgets('with Reduce Motion, every badge is simply there', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpRecords(tester, [
      beat(bench, .maxWeight, {'weight': 100.0, 'reps': 5}, {'weight': 95.0, 'reps': 5}),
      beat(squat, .maxWeight, {'weight': 140.0, 'reps': 3}, {'weight': 130.0, 'reps': 3}),
    ]);
    // the future resolves, and that frame is the finished one
    await tester.pump();
    await tester.pump();

    for (final text in ['was 95 kg', 'was 130 kg']) {
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)),
      );
      expect(fades.map((each) => each.opacity.value), everyElement(1.0), reason: text);
    }
  });

  testWidgets('keeps to a readable width on a tablet window', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpRecords(tester, [
      for (final kind in [RecordKind.maxWeight, RecordKind.oneRepMax, RecordKind.bestVolume])
        beat(bench, kind, {'weight': 100.0, 'value': 112.5, 'reps': 5}, {'weight': 95.0, 'value': 106.9, 'reps': 5}),
    ]);
    await tester.pumpAndSettle();

    final wrap = tester.getSize(find.byType(Wrap));
    expect(wrap.width, lessThanOrEqualTo(480));
  });

  testWidgets('says nothing when no record fell', (tester) async {
    // most sessions — same rule as the goals block
    await pump(tester, () async => const []);
    await tester.pumpAndSettle();

    expect(find.textContaining('record'), findsNothing);
  });

  testWidgets('shows nothing while the observation is still running', (tester) async {
    // it waits on the workout being written, so this state is on screen every
    // time — a spinner in the middle of the confetti would be worse than blank
    final pending = Completer<List<GoalAchievement>>();
    await pump(tester, () => pending.future);
    await tester.pump();

    expect(find.textContaining('reached'), findsNothing);

    pending.complete(const []);
    await tester.pumpAndSettle();
  });
}
