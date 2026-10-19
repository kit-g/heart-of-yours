// Workout sounds (#169): the one offer under the exercise whose rest ran out
// with the app on screen, its two answers, and the choices that unfold under
// the switch in Settings › Features. The offer is private to
// `workout_detail.dart`, so these drive the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

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
      'feature-workoutSounds': ?answer?.name,
    });
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    answered(null);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
  });

  Workout legDay() {
    return Workout.fromExercises([
      WorkoutExercise(starter: ExerciseSet(squat)),
      WorkoutExercise(starter: ExerciseSet(curl)),
    ], name: 'Leg day');
  }

  Future<void> pumpApp(WidgetTester tester, {HeartRouter? router}) async {
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: userId, email: '$userId@test'),
        signedIn: true,
      ),
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
  }

  /// Opens [workout] as the active one, on its sheet.
  Future<BuildContext> start(WidgetTester tester, Workout workout) async {
    await pumpApp(tester);
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

  /// [exercise]'s rest runs out with the app on screen — what `Alarms` tells
  /// the app (its own test holds that it does, for a rest run out and only
  /// then). Driven directly: the countdown measures the real clock, and
  /// letting real time pass here wakes the image cache's platform calls.
  Future<void> restRunsOut(WidgetTester tester, BuildContext context, WorkoutExercise exercise) async {
    WorkoutSounds.of(context).restRanOut(exercise.id);
    await tester.pumpTimes();
  }

  testWidgets('is offered under the exercise whose rest ran out, and a yes turns it on', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);
    expect(find.byKey(WorkoutDetailKeys.soundsOffer), findsNothing, reason: 'nothing has run out yet');

    await restRunsOut(tester, context, workout.first);
    expect(find.byKey(WorkoutDetailKeys.soundsOffer), findsOneWidget);
    expect(WorkoutSounds.of(context).offerUnder, workout.first.id);
    expect(Preferences.of(context).featureAnswer(.workoutSounds), FeatureAnswer.pending);

    await tester.ensureVisible(find.byKey(WorkoutDetailKeys.soundsAccept));
    await tester.tapByKey(WorkoutDetailKeys.soundsAccept);
    await tester.pumpTimes();
    expect(Preferences.of(context).isOn(.workoutSounds), isTrue);
    expect(find.byKey(WorkoutDetailKeys.soundsOffer), findsNothing);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
  });

  testWidgets('a no leaves the one notice in its place, and closing it leaves nothing', (tester) async {
    final workout = legDay();
    final context = await start(tester, workout);
    await restRunsOut(tester, context, workout.first);

    await tester.ensureVisible(find.byKey(WorkoutDetailKeys.soundsDecline));
    await tester.tapByKey(WorkoutDetailKeys.soundsDecline);
    await tester.pumpTimes();
    expect(Preferences.of(context).featureAnswer(.workoutSounds), FeatureAnswer.off);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(AppKeys.featureDeclinedNotice), matching: find.byType(IconButton)));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);

    await restRunsOut(tester, context, workout.last);
    expect(find.byKey(WorkoutDetailKeys.soundsOffer), findsNothing, reason: 'never asked again');
  });

  testWidgets('answered, a rest running out offers nothing: the sheet is as it was', (tester) async {
    answered(.off);
    final workout = legDay();
    final context = await start(tester, workout);
    await restRunsOut(tester, context, workout.first);

    expect(find.byKey(WorkoutDetailKeys.soundsOffer), findsNothing);
    expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
    expect(WorkoutSounds.of(context).offerUnder, isNull);
  });

  group('Settings › Features', () {
    Future<void> openFeatures(WidgetTester tester) async {
      final router = HeartRouter();
      await pumpApp(tester, router: router);
      router.config.go('/profile/settings/features?feature=workoutSounds');
      await tester.pumpTimes(25);
    }

    testWidgets('on, the sound, the volume and the tick unfold under the switch', (tester) async {
      answered(.on);
      await openFeatures(tester);
      final context = tester.element(find.byType(MaterialApp));

      await tester.ensureVisible(find.byKey(AppKeys.soundVolumePicker));
      expect(find.byKey(AppKeys.restSoundPicker), findsOneWidget);
      expect(find.byKey(AppKeys.setDoneSound), findsOneWidget);

      await tester.tap(find.descendant(of: find.byKey(AppKeys.restSoundPicker), matching: find.text('Bell')));
      await tester.pumpTimes();
      await tester.tap(find.descendant(of: find.byKey(AppKeys.soundVolumePicker), matching: find.text('Low')));
      await tester.pumpTimes();
      await tester.ensureVisible(find.byKey(AppKeys.setDoneSound));
      await tester.tapByKey(AppKeys.setDoneSound);
      await tester.pumpTimes();

      final sounds = WorkoutSounds.of(context);
      expect(sounds.restSound, RestSound.bell);
      expect(sounds.volume, SoundVolume.low);
      expect(sounds.setDoneSound, isTrue);
      expect(sounds.restNotificationSound, 'rest_bell');
    });

    testWidgets('off, none of it is there', (tester) async {
      answered(.off);
      await openFeatures(tester);

      expect(find.byKey(const ValueKey('feature-workoutSounds')), findsOneWidget);
      expect(find.byKey(AppKeys.restSoundPicker), findsNothing);
      expect(find.byKey(AppKeys.soundVolumePicker), findsNothing);
      expect(find.byKey(AppKeys.setDoneSound), findsNothing);
    });
  });
}
