// Default rest (#174): the one offer under the exercise whose tick started
// nothing, its two answers, and the rest it then gives every exercise without
// a timer of its own. The offer is private to `workout_detail.dart`, so these
// drive the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/rest.dart';
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
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);
  final curl = Exercise(name: 'Curl', category: .dumbbell, target: .arms);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  void answered(FeatureAnswer? answer) {
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'weightUnit': 'metric',
      'distanceUnit': 'metric',
      'feature-programs': FeatureAnswer.off.name,
      'feature-defaultRest': ?answer?.name,
    });
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
    answered(null);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});
    when(
      db.setRestTimer(
        exerciseName: anyNamed('exerciseName'),
        userId: anyNamed('userId'),
        seconds: anyNamed('seconds'),
      ),
    ).thenAnswer((_) async {});
  });

  Workout legDay() {
    return Workout.fromExercises([
      WorkoutExercise(starter: ExerciseSet(squat))..add(ExerciseSet(squat)),
      WorkoutExercise(starter: ExerciseSet(curl)),
    ], name: 'Leg day');
  }

  /// Signs in — to an account, or [anonymous]ly — and opens [workout] as the
  /// active one.
  Future<BuildContext> start(WidgetTester tester, Workout workout, {bool anonymous = false}) async {
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: switch (anonymous) {
          true => MockUser(uid: userId, isAnonymous: true),
          false => MockUser(uid: userId, email: '$userId@test'),
        },
        signedIn: true,
      ),
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat, curl]));
    await Workouts.of(context).startWorkout(source: .template, template: workout);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    if (find.byType(WorkoutDetail).evaluate().isEmpty) {
      await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
      await tester.pumpTimes();
    }
    return context;
  }

  Future<void> tick(WidgetTester tester, BuildContext context, WorkoutExercise exercise) async {
    Workouts.of(context).markSetAsComplete(exercise, exercise.first);
    await tester.pumpTimes();
  }

  BuildContext sheet(WidgetTester tester) => tester.element(find.byType(WorkoutDetail));

  testWidgets('is offered only once a tick started no rest, under that exercise', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);

    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsNothing);

    await tick(tester, context, workout.first);
    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsOneWidget);
    expect(Preferences.of(context).featureAnswer(.defaultRest), FeatureAnswer.pending);
  });

  testWidgets('not under an exercise with a timer of its own', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);
    await Timers.of(context).setRestTimer(squat.id, 120);

    await tick(tester, context, workout.first);
    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsNothing);
  });

  testWidgets('yes: every exercise without a timer rests by its kind, and the offer goes', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);
    await tick(tester, context, workout.first);

    await tester.tapByKey(WorkoutDetailKeys.defaultRestAccept);
    await tester.pumpTimes();

    expect(Preferences.of(context).isOn(.defaultRest), isTrue);
    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsNothing);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
    expect(restFor(sheet(tester), workout.first), RestKind.compound.seconds);
    expect(restFor(sheet(tester), workout.last), RestKind.isolation.seconds);
  });

  testWidgets('no: the one notice in its place, and no rest', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);
    await tick(tester, context, workout.first);

    await tester.tapByKey(WorkoutDetailKeys.defaultRestDecline);
    await tester.pumpTimes();

    final preferences = Preferences.of(context);
    expect(preferences.featureAnswer(.defaultRest), FeatureAnswer.off);
    expect(preferences.shouldOffer(.defaultRest), isFalse);
    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsNothing);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
    expect(restFor(sheet(tester), workout.first), isNull);
  });

  testWidgets('off, the sheet is as it was: no offer and no rest', (tester) async {
    answered(.off);
    final workout = legDay();
    final context = await start(tester, workout);
    await tick(tester, context, workout.first);

    expect(find.byKey(WorkoutDetailKeys.defaultRestOffer), findsNothing);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
    expect(restFor(sheet(tester), workout.first), isNull);
  });

  testWidgets("a timer of the exercise's own wins over the default", (tester) async {
    answered(.on);
    final workout = legDay();
    final context = await start(tester, workout);
    await Timers.of(context).setRestTimer(squat.id, 45);
    await tester.pumpTimes();

    expect(restFor(sheet(tester), workout.first), 45);
    expect(restFor(sheet(tester), workout.last), RestKind.isolation.seconds);
  });

  testWidgets('a kind set to no rest gives none, and its length is the one picked', (tester) async {
    answered(.on);
    final workout = legDay();
    final context = await start(tester, workout);
    Preferences.of(context)
      ..setDefaultRest(.compound, 0)
      ..setDefaultRest(.isolation, 75);
    await tester.pumpTimes();

    expect(restFor(sheet(tester), workout.first), isNull);
    expect(restFor(sheet(tester), workout.last), 75);
  });

  testWidgets('an anonymous session has timers of its own and the default alike', (tester) async {
    // #146 found none: that was before an anonymous session had a uid (#96).
    // The timers are device-only either way, and so is the default.
    answered(.on);
    final workout = legDay();
    final context = await start(tester, workout, anonymous: true);
    expect(Auth.of(context).isAnonymous, isTrue);

    await Timers.of(context).setRestTimer(squat.id, 45);
    await tester.pumpTimes();

    expect(restFor(sheet(tester), workout.first), 45);
    expect(restFor(sheet(tester), workout.last), RestKind.isolation.seconds);
  });
}
