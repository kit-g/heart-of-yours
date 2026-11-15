// Live goal notes (#625): under the live-records switch, the tick that
// reaches a goal's rung says so in the record note — one note when the set is
// a record too — with a burst of confetti, and the still note alone when less
// motion is asked for. The sheet's pieces are private to
// `workout_detail.dart`, so this drives the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/confetti.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  const userId = 'u1';
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  RecordSet past(double weight, int reps) {
    return RecordSet(
      weight: weight,
      reps: reps,
      duration: null,
      distance: null,
      workoutId: 'w1',
      at: '2026-09-01T10:00:00Z',
    );
  }

  /// A top-set ladder on the bench: 104, then 110 to finish.
  final ladder = Goal(
    id: 'goal-1',
    metric: .topSetWeight,
    exerciseId: bench.id,
    stages: [
      GoalStage(id: 'rung-1', target: 104),
      GoalStage(id: 'rung-2', target: 110),
    ],
  );

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  void goals(List<Goal> live) {
    when(
      db.getTargetUserGoals(
        requesterId: anyNamed('requesterId'),
        targetUserId: anyNamed('targetUserId'),
        archived: anyNamed('archived'),
      ),
    ).thenAnswer((invocation) async => invocation.namedArguments[#archived] == true ? const [] : live);
    when(
      api.getTargetUserGoals(
        requesterId: anyNamed('requesterId'),
        targetUserId: anyNamed('targetUserId'),
        archived: anyNamed('archived'),
      ),
    ).thenAnswer((invocation) async => invocation.namedArguments[#archived] == true ? const [] : live);
  }

  setUp(() {
    tz.initializeTimeZones();
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,
    );
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'weightUnit': 'metric'});
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});
    when(db.markSetAsIncomplete(any)).thenAnswer((_) async {});
    when(
      db.setRestTimer(
        exerciseName: anyNamed('exerciseName'),
        userId: anyNamed('userId'),
        seconds: anyNamed('seconds'),
      ),
    ).thenAnswer((_) async {});
    // a best of 100 × 3, so the 105 below is a record as well as a rung
    when(
      db.getRecordWithout(any, any, any),
    ).thenAnswer((_) async => [past(100, 3), past(90, 8)].toPersonalRecords(bench.category));
    when(
      db.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => [(100, DateTime.utc(2026, 9))]);
    when(db.storeGoals(any, any, archived: anyNamed('archived'))).thenAnswer((_) async {});
    when(db.unsyncedGoals(any)).thenAnswer((_) async => const []);
    // in the catalogue from launch, as a goal's exercise is
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    goals([ladder]);
  });

  /// A light set, one that reaches the first rung, and one past the last.
  Workout pressing() {
    return Workout.fromExercises([
      WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))
        ..add(ExerciseSet(bench, weight: 105, reps: 5))
        ..add(ExerciseSet(bench, weight: 112.5, reps: 3)),
    ], name: 'Push');
  }

  Future<BuildContext> start(WidgetTester tester, {bool on = true}) async {
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: userId, email: '$userId@test'),
        signedIn: true,
      ),
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    Preferences.of(context).setFeature(.liveRecords, on: on);
    await Goals.of(context).init();
    await Workouts.of(context).startWorkout(source: .template, template: pressing());
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return context;
  }

  final note = find.byKey(WorkoutDetailKeys.liveRecordNote);
  final burst = find.byKey(WorkoutDetailKeys.liveGoalBurst);
  final reached = find.text('Goal reached');

  testWidgets('a set that is a record and a rung says both in one note, with a small burst', (tester) async {
    await start(tester);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 1));
    await tester.pumpTimes();
    expect(note, findsNothing, reason: '60 × 5 reaches nothing');

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
    await tester.pump();
    await tester.pump();
    expect(note, findsOneWidget);
    expect(find.text('New records'), findsOneWidget);
    expect(reached, findsOneWidget);
    expect(find.textContaining('104'), findsOneWidget);
    expect(burst, findsOneWidget);
    expect(tester.widget<Confetti>(find.byType(Confetti)).particleCount, lessThan(20), reason: 'a rung on the way');

    // one announcement, the record and the rung both
    final announced = tester.widget<Semantics>(note).properties;
    expect(announced.label, allOf(contains('New records'), contains('Goal reached'), contains('104')));
    expect(announced.liveRegion, isTrue);
    await tester.pumpTimes(40);
  });

  testWidgets('an untick that un-crosses the rung takes the note back', (tester) async {
    await start(tester);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
    await tester.pumpTimes();
    expect(reached, findsOneWidget);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
    await tester.pumpTimes();
    expect(note, findsNothing);
    expect(burst, findsNothing);
    // one read when the goal met the workout, never one per tick
    verify(db.getExerciseMetics(userId, .topSetWeight, bench.id, limit: anyNamed('limit'))).called(1);
  });

  testWidgets("two rungs on one tick are one burst, the goal's full one", (tester) async {
    await start(tester);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 3));
    await tester.pump();
    await tester.pump();
    expect(find.byType(Confetti), findsOneWidget);
    expect(tester.widget<Confetti>(find.byType(Confetti)).particleCount, greaterThan(20));
    expect(find.textContaining('104'), findsOneWidget);
    expect(find.textContaining('110'), findsOneWidget);
    expect(find.text('Goals reached'), findsOneWidget);

    // brief: gone before the note is
    await tester.pumpTimes(32);
    expect(burst, findsNothing);
    await tester.pumpTimes(8);
  });

  for (final (name, features) in [
    ('Reduce Motion', const FakeAccessibilityFeatures(reduceMotion: true)),
    ('Remove animations', const FakeAccessibilityFeatures(disableAnimations: true)),
  ]) {
    testWidgets('with $name, the still note and no burst (#595)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await start(tester);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 3));
      await tester.pump();
      await tester.pump();

      expect(note, findsOneWidget);
      expect(find.text('Goals reached'), findsOneWidget);
      expect(burst, findsNothing);
      expect(find.byType(Confetti), findsNothing);
      await tester.pumpTimes(40);
    });
  }

  testWidgets('off: as if never built, and no goal read', (tester) async {
    await start(tester, on: false);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 3));
    await tester.pumpTimes();

    expect(note, findsNothing);
    expect(burst, findsNothing);
    verifyNever(db.getExerciseMetics(any, any, any, limit: anyNamed('limit')));
  });

  testWidgets('with no goals, a record is noted as before and nothing about goals is read', (tester) async {
    goals(const []);
    await start(tester);

    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
    await tester.pumpTimes();

    expect(find.text('New records'), findsOneWidget);
    expect(reached, findsNothing);
    expect(burst, findsNothing);
    verifyNever(db.getExerciseMetics(any, any, any, limit: anyNamed('limit')));
    await tester.pumpTimes(40);
  });

  testWidgets('a rung already crossed when the goals are first read is not news', (tester) async {
    // what a workout restored after a restart looks like: ticked sets already
    // there when the reads land, so nothing old is replayed
    final context = await start(tester, on: false);
    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
    await tester.pumpTimes();

    Preferences.of(context).setFeature(.liveRecords, on: true);
    await tester.pumpTimes();

    expect(note, findsNothing);
    expect(burst, findsNothing);
    verify(db.getExerciseMetics(userId, .topSetWeight, bench.id, limit: anyNamed('limit'))).called(1);

    // the next rung is news
    await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 3));
    await tester.pump();
    await tester.pump();
    expect(reached, findsOneWidget);
    expect(find.textContaining('110'), findsOneWidget);
    expect(find.textContaining('104'), findsNothing);
    await tester.pumpTimes(40);
  });
}
