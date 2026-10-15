// Replacing an exercise on the sheet (#354): the menu offers it until a set is
// ticked, the picker suggests the same movement pattern first and greys what
// cannot take the sets, and in a program's workout the replace asks whether
// it reaches the program. The pieces are private to `workout_detail.dart`, so
// these drive the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  const userId = 'u1';
  Movement pattern(String group) => Movement.fromJson({
    'groups': [group],
  });
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs, movement: pattern('squat_bilateral'));
  final front = Exercise(name: 'Front Squat', category: .barbell, target: .legs, movement: pattern('squat_bilateral'));
  final bench = Exercise(
    name: 'Bench Press',
    category: .barbell,
    target: .chest,
    movement: pattern('horizontal_press'),
  );
  final ride = Exercise(name: 'Ride', category: .cardio, target: .cardio);
  final session = Template.fromJson({
    'id': 's1',
    'name': 'Squat day',
    'order': 0,
    'programId': 'p1',
    'exercises': [
      {
        'id': 'te1',
        'exercise': squat.toMap(),
        'sets': [
          {'id': 'ts1', 'completed': false},
        ],
      },
    ],
  });
  final program = Program(
    id: 'p1',
    name: 'Waves',
    perWeek: 3,
    sessions: ['s1'],
    rules: {squat.id: const AddWeight(step: 2.5)},
    createdAt: DateTime.utc(2026, 10, 1),
  );

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
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'weightUnit': 'metric',
      'distanceUnit': 'metric',
      'feature-programs': FeatureAnswer.on.name,
    });
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat, front, bench, ride]));
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.startExercise(any, any)).thenAnswer((_) async {});
    when(db.removeExercise(any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});

    when(db.getPrograms(userId)).thenAnswer((_) async => [program]);
    when(api.getPrograms()).thenAnswer((_) async => [program]);
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramMarks(userId, any)).thenAnswer((_) async => []);
    when(db.storePrograms(any, any)).thenAnswer((_) async {});
    when(db.storeProgram(any, any)).thenAnswer((_) async {});
    when(db.storeProgramActions(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBases(any, any)).thenAnswer((_) async {});
    when(api.getProgramActions(any)).thenAnswer((_) async => []);
    when(api.getProgramBases(any)).thenAnswer((_) async => []);
    when(api.editProgram(any)).thenAnswer((invocation) async => invocation.positionalArguments.single as Program);
  });

  /// Signs in, reads the program and its session, and opens [workout] as the
  /// active one.
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
    await Exercises.of(context).init();
    await Programs.of(context).init();
    await Workouts.of(context).startWorkout(source: .program, template: workout);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    if (find.byType(WorkoutDetail).evaluate().isEmpty) {
      await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
      await tester.pumpTimes();
    }
    return context;
  }

  Workout squats({String? programId}) {
    return Workout.fromExercises(
      [WorkoutExercise(starter: ExerciseSet(squat))],
      name: 'Squats',
      programId: programId,
    );
  }

  Future<void> openReplace(WidgetTester tester) async {
    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
    await tester.tapByKey(WorkoutDetailKeys.replaceExerciseFor(squat.id));
    await tester.pumpTimes();
  }

  testWidgets('the menu offers a replace until a set is ticked', (tester) async {
    final workout = squats();
    final context = await start(tester, workout);

    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
    expect(find.byKey(WorkoutDetailKeys.replaceExerciseFor(squat.id)), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpTimes();

    final exercise = Workouts.of(context).activeWorkout!.first;
    Workouts.of(context).markSetAsComplete(exercise, exercise.first);
    await tester.pumpTimes();
    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
    expect(find.byKey(WorkoutDetailKeys.replaceExerciseFor(squat.id)), findsNothing);
  });

  testWidgets('the same pattern is suggested first, and what cannot take the sets is greyed', (tester) async {
    final context = await start(tester, squats());
    final l = L.of(tester.element(find.byType(WorkoutDetail)));
    await openReplace(tester);

    expect(find.text(l.pickerSuggested.toUpperCase()), findsOneWidget);
    // suggested, and again in the whole library below
    expect(find.text('Front Squat'), findsNWidgets(2));
    await tester.tap(find.text('Ride'));
    await tester.pumpTimes();
    expect(find.text(l.replaceIncompatible('Ride', 'Squat')), findsOneWidget);
    expect(find.text(l.pickerSuggested.toUpperCase()), findsOneWidget, reason: 'a greyed exercise is no answer');

    await tester.tap(find.text('Front Squat').first);
    await tester.pumpTimes();

    expect(Workouts.of(context).activeWorkout!.map((each) => each.exercise.id), [front.id]);
    expect(find.text(l.replaceScopeTitle('Waves')), findsNothing, reason: 'a workout of no program asks nothing');
  });

  testWidgets("in a program's workout the replace asks, and just today leaves the program alone", (tester) async {
    when(db.getTemplates(userId)).thenAnswer((_) async => [session]);
    final context = await start(tester, squats(programId: 'p1'));
    await Templates.of(context).init();
    final l = L.of(tester.element(find.byType(WorkoutDetail)));
    await openReplace(tester);
    await tester.tap(find.text('Front Squat').first);
    await tester.pumpTimes();

    expect(find.text(l.replaceScopeTitle('Waves')), findsOneWidget);
    await tester.tapByKey(WorkoutDetailKeys.replaceJustToday);
    await tester.pumpTimes();

    expect(Workouts.of(context).activeWorkout!.map((each) => each.exercise.id), [front.id]);
    expect(Programs.of(context).lookup('p1')!.rules.keys, [squat.id]);
  });

  testWidgets('in the program, the growth rule moves to the replacement', (tester) async {
    when(db.getTemplates(userId)).thenAnswer((_) async => [session]);
    final context = await start(tester, squats(programId: 'p1'));
    await Templates.of(context).init();
    await openReplace(tester);
    await tester.tap(find.text('Front Squat').first);
    await tester.pumpTimes();

    await tester.tapByKey(WorkoutDetailKeys.replaceInProgram);
    await tester.pumpTimes();

    expect(Programs.of(context).lookup('p1')!.rules.keys, [front.id]);
  });
}
