import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// The plate calculator (#132), through the real active-workout sheet: its one
/// offer over the keyboard, the way in once it is on, and the sheet itself.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

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
    harness = const TestAppHarness();

    // Metric and no per-exercise override, so entered numbers round-trip into
    // the model unconverted — the test cares about parsing, not unit math.
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'weightUnit': 'metric',
      'distanceUnit': 'metric',
    });

    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);
    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.isHistoryBackfilled(any)).thenAnswer((_) async => true);
    when(db.mirrorSummary(any)).thenAnswer((_) async => const AccountSummary(collections: {}));
    when(api.getAccountSummary()).thenAnswer((_) async => const AccountSummary(collections: {}));
    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));
    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer((_) async => ProgressGalleryResponse.fromJson({}));
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});
    when(db.markSetAsIncomplete(any)).thenAnswer((_) async {});
    when(db.removeSet(any)).thenAnswer((_) async {});
  });

  /// Pumps the real app, starts [workout] as the active workout (as
  /// `test/a11y_test.dart`'s `pumpTo(_Screen.exerciseNoteEditor)` does) and
  /// lands on the workout tab. Returns the top-level context, valid for the
  /// rest of the test since it sits above the router.
  Future<BuildContext> startWorkoutOn(WidgetTester tester, Workout workout) async {
    final firebase = MockFirebaseAuth(
      mockUser: MockUser(uid: 'u1', email: 'u1@test'),
      signedIn: true,
    );
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();

    final context = tester.element(find.byType(MaterialApp));
    await Workouts.of(context).startWorkout(source: WorkoutSource.template, template: workout);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    if (find.byType(WorkoutDetail).evaluate().isEmpty) {
      await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
      await tester.pumpTimes();
    }
    return context;
  }

  Finder weightOf(Exercise exercise) => find.byKey(WorkoutDetailKeys.weightFor(exercise.id, 1));

  Future<void> typeWeight(WidgetTester tester, Exercise exercise, String weight) async {
    await tester.enterTextAndWait(weightOf(exercise), weight);
    await tester.pumpTimes();
  }

  Future<void> openCalculator(WidgetTester tester) async {
    await tester.tapByKey(WorkoutDetailKeys.platesButton);
    await tester.pumpTimes();
  }

  Workout bench(Exercise exercise) => Workout(name: 'Muffin day')..add(exercise);

  final barbell = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  group('the offer', () {
    testWidgets('a barbell weight being typed brings the one offer over the keyboard', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      await typeWeight(tester, barbell, '100');

      expect(find.byKey(WorkoutDetailKeys.platesOffer), findsOneWidget);
      expect(Preferences.of(context).featureAnswer(.plateCalculator), FeatureAnswer.pending);
    });

    testWidgets('a no earns the one notice, and the strip is gone after it', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      await typeWeight(tester, barbell, '100');
      await tester.tapByKey(WorkoutDetailKeys.platesDecline);
      await tester.pumpTimes();

      expect(find.byKey(WorkoutDetailKeys.platesOffer), findsNothing);
      expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
      expect(find.byKey(WorkoutDetailKeys.platesButton), findsNothing);

      Preferences.of(context).acknowledgeDeclineNotice(.plateCalculator);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
      expect(find.byKey(WorkoutDetailKeys.platesOffer), findsNothing);
    });

    testWidgets('a dumbbell weight is never offered the calculator', (tester) async {
      final dumbbell = Exercise(name: 'Curl', category: .dumbbell, target: .arms);
      await startWorkoutOn(tester, bench(dumbbell));
      await typeWeight(tester, dumbbell, '12');

      expect(find.byKey(WorkoutDetailKeys.platesOffer), findsNothing);
    });

    testWidgets('off, the sheet is as it was before the calculator: no strip at all', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      Preferences.of(context).setFeature(.plateCalculator, on: false);
      await tester.pumpTimes();
      await typeWeight(tester, barbell, '100');

      expect(find.byKey(WorkoutDetailKeys.platesOffer), findsNothing);
      expect(find.byKey(WorkoutDetailKeys.platesButton), findsNothing);
      expect(find.byKey(AppKeys.featureDeclinedNotice), findsNothing);
    });
  });

  group('the calculator', () {
    testWidgets('a yes shows the way in at once, following the field', (tester) async {
      await startWorkoutOn(tester, bench(barbell));
      await typeWeight(tester, barbell, '100');
      await tester.tapByKey(WorkoutDetailKeys.platesAccept);
      await tester.pumpTimes();

      expect(find.text('Plates for 100 kg'), findsOneWidget);
      await typeWeight(tester, barbell, '140');
      expect(find.text('Plates for 140 kg'), findsOneWidget);
    });

    testWidgets('the plates on each side, for an Olympic bar', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      Preferences.of(context).setFeature(.plateCalculator, on: true);
      await typeWeight(tester, barbell, '100');
      await openCalculator(tester);

      expect(find.byKey(WorkoutDetailKeys.plateCalculator), findsOneWidget);
      expect(find.text('Each side: 25 + 15 kg'), findsOneWidget);
    });

    testWidgets('a weight the plates cannot make offers the nearest either side, and puts one in the set', (
      tester,
    ) async {
      final workout = bench(barbell);
      final context = await startWorkoutOn(tester, workout);
      Preferences.of(context).setFeature(.plateCalculator, on: true);
      await typeWeight(tester, barbell, '101');
      await openCalculator(tester);

      expect(find.text("Your plates can't make 101 kg. Closest:"), findsOneWidget);
      expect(find.text('Use 100 kg'), findsOneWidget);
      expect(find.text('Use 102.5 kg'), findsOneWidget);

      await tester.tap(find.text('Use 102.5 kg'));
      await tester.pumpTimes();
      expect(workout.first.first.weight, 102.5);
      expect(find.text('Each side: 25 + 15 + 1.25 kg'), findsOneWidget);
    });

    testWidgets('unticking a plate and changing the bar show at once, and stay', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      final preferences = Preferences.of(context)..setFeature(.plateCalculator, on: true);
      await typeWeight(tester, barbell, '100');
      await openCalculator(tester);

      await tester.tapByKey(WorkoutDetailKeys.plateChip('15.0'));
      await tester.pumpTimes();
      expect(find.text('Each side: 2 × 20 kg'), findsOneWidget);
      expect(preferences.platesIn(.metric), isNot(contains(15.0)));

      await tester.tapByKey(WorkoutDetailKeys.plateBar);
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.barOption('womens'));
      await tester.pumpTimes();
      expect(find.text('Each side: 2 × 20 + 2.5 kg'), findsOneWidget);
      expect(preferences.barWeightFor(barbell), const NamedBar(Bar.womens));
    });

    testWidgets('a bar of the user\'s own, typed in', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      Preferences.of(context).setFeature(.plateCalculator, on: true);
      await typeWeight(tester, barbell, '100');
      await openCalculator(tester);

      await tester.tapByKey(WorkoutDetailKeys.plateBar);
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.barOption('custom'));
      await tester.pumpTimes();
      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.customBarField), '10');
      await tester.tapByKey(WorkoutDetailKeys.customBarSave);
      await tester.pumpTimes();

      expect(Preferences.of(context).barWeightFor(barbell), const CustomBar(10, .metric));
      expect(find.text('Each side: 25 + 20 kg'), findsOneWidget);
    });

    testWidgets('in pounds, with pound plates and a 45 lb bar', (tester) async {
      final context = await startWorkoutOn(tester, bench(barbell));
      Preferences.of(context)
        ..setWeightUnit(.imperial)
        ..setFeature(.plateCalculator, on: true);
      await tester.pumpTimes();
      await typeWeight(tester, barbell, '225');
      await openCalculator(tester);

      expect(find.text('Each side: 2 × 45 lbs'), findsOneWidget);
    });

    testWidgets('on a tablet the sheet stops at a dialog\'s width', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final context = await startWorkoutOn(tester, bench(barbell));
      Preferences.of(context).setFeature(.plateCalculator, on: true);
      await typeWeight(tester, barbell, '100');
      await openCalculator(tester);

      expect(tester.getSize(find.byKey(WorkoutDetailKeys.plateCalculator)).width, lessThanOrEqualTo(dialogWidth));
    });
  });
}
