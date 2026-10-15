// Supersets and circuits on the sheet (#159): core, so no switch. A group
// shows as a rail with a caption, the ⋯ menu joins and leaves one, and a
// round rests once, after its last member. The pieces are private to
// `workout_detail.dart`, so these drive the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/countdown.dart';
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
  final row = Exercise(name: 'Row', category: .barbell, target: .back);
  final curl = Exercise(name: 'Curl', category: .barbell, target: .arms);
  final press = Exercise(name: 'Press', category: .barbell, target: .chest);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

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
    when(db.setWorkoutExercisePlan(any)).thenAnswer((_) async {});
    when(
      db.setRestTimer(exerciseName: anyNamed('exerciseName'), userId: anyNamed('userId'), seconds: anyNamed('seconds')),
    ).thenAnswer((_) async {});
  });

  WorkoutExercise block(Exercise exercise, {int? superset}) {
    final block = WorkoutExercise(starter: ExerciseSet(exercise, weight: 40, reps: 10))..superset = superset;
    block.add(ExerciseSet(exercise, weight: 40, reps: 10));
    return block;
  }

  /// Signs in and opens [workout] as the active one.
  Future<BuildContext> start(WidgetTester tester, Workout workout) async {
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
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [row, curl, press]));
    await Workouts.of(context).startWorkout(source: .template, template: workout);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return context;
  }

  testWidgets('a pair reads as a superset, three as a circuit, beside a rail', (tester) async {
    final workout = Workout.fromExercises([
      block(row, superset: 1),
      block(curl, superset: 1),
      block(press),
    ], name: 'Pull');
    final context = await start(tester, workout);

    expect(find.text('Superset'), findsOneWidget);
    expect(find.byKey(WorkoutDetailKeys.groupRailFor(row.id)), findsOneWidget);
    expect(find.byKey(WorkoutDetailKeys.groupRailFor(curl.id)), findsOneWidget);
    expect(find.byKey(WorkoutDetailKeys.groupRailFor(press.id)), findsNothing);

    final [_, curls, presses] = workout.toList();
    await Workouts.of(context).group(presses, curls);
    await tester.pumpTimes();

    expect(find.text('Circuit'), findsOneWidget);
    expect(find.text('Superset'), findsNothing);
  });

  testWidgets('the ⋯ menu joins a neighbour, and leaves the group again', (tester) async {
    final workout = Workout.fromExercises([block(row), block(curl)], name: 'Pull');
    await start(tester, workout);

    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(row.id));
    await tester.pumpTimes();
    expect(find.text('Superset with Curl'), findsOneWidget);
    await tester.tapByKey(WorkoutDetailKeys.groupWith(row.id, curl.id));
    await tester.pumpTimes();

    expect([for (final each in workout) each.superset], [1, 1]);
    verify(db.setWorkoutExercisePlan(any)).called(2);
    expect(find.text('Superset'), findsOneWidget);

    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(curl.id));
    await tester.pumpTimes();
    expect(find.byKey(WorkoutDetailKeys.groupWith(curl.id, row.id)), findsNothing, reason: 'already together');
    await tester.tapByKey(WorkoutDetailKeys.leaveGroup(curl.id));
    await tester.pumpTimes();

    expect([for (final each in workout) each.superset], [null, null]);
    expect(find.text('Superset'), findsNothing);
  });

  testWidgets('a round rests once, after its last member', (tester) async {
    final workout = Workout.fromExercises([block(row, superset: 1), block(curl, superset: 1)], name: 'Pull');
    final context = await start(tester, workout);
    final timers = Timers.of(context);
    await timers.setRestTimer(row.id, 60);
    await timers.setRestTimer(curl.id, 90);
    await tester.pumpTimes();

    await tester.tapByKey(WorkoutDetailKeys.doneFor(row.id, 1));
    await tester.pumpTimes();
    expect(find.byType(Countdown), findsNothing, reason: 'the round goes on to the curl');

    await tester.tapByKey(WorkoutDetailKeys.doneFor(curl.id, 1));
    await tester.pumpTimes();
    expect(find.byType(Countdown), findsOneWidget);
    expect(Alarms.of(context).activeExerciseTotal, 90, reason: "the round's rest is its last member's");

    Alarms.of(context).stopActiveExerciseTimer();
    await tester.pumpTimes();
  });
}
