import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
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
    when(remote.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(remoteService: remote, service: service);
    await exercises.init();

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pump(WidgetTester tester, Future<List<GoalAchievement>> Function() achievements) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: WorkoutDone(
            workout: null,
            onQuit: () {},
            workoutsThisWeekCallback: () async => 0,
            achievementsCallback: achievements,
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
