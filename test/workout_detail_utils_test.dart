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

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Both the cancel and finish flows call `cancelAllNotifications()` on their
/// way out — see `test/ongoing_notification_test.dart`: no plugin registrant
/// runs under `flutter test`, so the platform instance and its method channel
/// need a stand-in or the call throws `LateInitializationError`.
const _notificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

WorkoutExercise _exercise(String name, Category category) {
  return WorkoutExercise(
    starter: ExerciseSet(Exercise(name: name, category: category, target: Target.other)),
  );
}

void main() {
  group('dropIndex', () {
    late WorkoutExercise a, b, c, outsider;

    setUp(() {
      a = _exercise('A', Category.repsOnly);
      b = _exercise('B', Category.repsOnly);
      c = _exercise('C', Category.repsOnly);
      outsider = _exercise('Outsider', Category.repsOnly);
    });

    test('no dragged item -> null', () {
      expect(dropIndex([a, b, c], null, b), isNull);
    });

    test('no hovered target -> append at the end', () {
      expect(dropIndex([a, b, c], a, null), 3);
    });

    test('dragged item not in the list -> null', () {
      expect(dropIndex([a, b], outsider, a), isNull);
    });

    test('hovered item not in the list -> null', () {
      expect(dropIndex([a, b], a, outsider), isNull);
    });

    test('dragged over itself -> null (nothing to move)', () {
      expect(dropIndex([a, b, c], a, a), isNull);
    });

    test('dragging downward lands after the hovered item', () {
      // a (index 0) dragged onto c (index 2): from < to, so it lands at to+1.
      expect(dropIndex([a, b, c], a, c), 3);
    });

    test('dragging upward lands before the hovered item', () {
      // c (index 2) dragged onto a (index 0): from > to, so it lands at to.
      expect(dropIndex([a, b, c], c, a), 0);
    });

    test('dragging onto the immediate neighbour below still moves it', () {
      // a (0) dragged onto b (1): a plain insert-before would be a no-op —
      // dropIndex must return the slot *after* b instead.
      expect(dropIndex([a, b, c], a, b), 2);
    });
  });

  group('workout finish/cancel dialogs (through the live screen)', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockCdn cdn;
    late TestAppHarness harness;

    setUpAll(() {
      FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    });

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _notificationsChannel,
        (call) async => null,
      );
      db = MockLocalDatabase();
      api = MockApi();
      cdn = MockCdn();
      harness = const TestAppHarness();

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
      when(db.deleteWorkout(any)).thenAnswer((_) async {});
      when(api.deleteWorkout(any)).thenAnswer((_) async => true);
      when(db.finishWorkout(any, any)).thenAnswer((_) async {});
      when(db.storeWorkoutHistory(any, any)).thenAnswer((_) async {});
      when(api.saveWorkout(any)).thenAnswer((invocation) async => invocation.positionalArguments.single as Workout);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _notificationsChannel,
        null,
      );
    });

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

    Finder fieldsIn(ExerciseSet set) => find.descendant(
      of: find.byKey(ValueKey<String>('_ExerciseSetItem.${set.id}')),
      matching: find.byType(TextField),
    );

    testWidgets('cancel button: resuming leaves the workout active', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.tapByKey(WorkoutDetailKeys.cancelWorkout);
      await tester.pumpTimes();
      expect(find.text(l.cancelWorkoutTitle), findsOneWidget);

      await tester.tap(find.text(l.resumeWorkout));
      await tester.pumpTimes();

      expect(Workouts.of(context).hasActiveWorkout, isTrue);
      verifyNever(db.deleteWorkout(any));
    });

    testWidgets('cancel button: confirming cancels the active workout', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.tapByKey(WorkoutDetailKeys.cancelWorkout);
      await tester.pumpTimes();

      await tester.tap(find.text(l.cancelWorkout).last);
      await tester.pumpTimes();

      expect(Workouts.of(context).hasActiveWorkout, isFalse);
    });

    testWidgets('finish button on an untouched workout falls back to the cancel dialog', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);

      await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();

      expect(find.text(l.cancelWorkoutTitle), findsOneWidget);
    });

    testWidgets('finish button with some — not all — sets done shows the warning dialog', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final workoutExercise = workout.first;
      workoutExercise.add(ExerciseSet(exercise)); // a second, never-ticked set
      final firstSet = workoutExercise.first;

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.enterTextAndWait(fieldsIn(firstSet).first, '12');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();

      expect(find.text(l.finishWorkoutWarningTitle), findsOneWidget);

      await tester.tap(find.text(l.notReadyToFinish));
      await tester.pumpTimes();

      expect(Workouts.of(context).hasActiveWorkout, isTrue);
    });

    testWidgets('finishing a fully completed workout ends the session', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.enterTextAndWait(fieldsIn(set).first, '12');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();
      expect(find.text(l.finishWorkoutTitle), findsOneWidget);

      await tester.tap(find.text(l.readyToFinish));
      await tester.pumpTimes();

      expect(Workouts.of(context).hasActiveWorkout, isFalse);
      verify(db.finishWorkout(any, any)).called(1);
    });

    testWidgets('typed but unticked set: discarding drops it and finishes anyway', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      // typed, never ticked
      await tester.enterTextAndWait(fieldsIn(set).first, '12');
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();
      expect(find.text(l.untickedSetsTitle), findsOneWidget);

      await tester.tap(find.text(l.discardUntickedSets));
      await tester.pumpTimes();

      expect(Workouts.of(context).hasActiveWorkout, isFalse);
      expect(set.isCompleted, isFalse);
    });

    testWidgets('typed but unticked set: saving ticks it before finishing', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      final context = await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byKey(WorkoutDetailKeys.finishWorkout)));

      await tester.enterTextAndWait(fieldsIn(set).first, '12');
      await tester.pumpTimes();

      await tester.tapByKey(WorkoutDetailKeys.finishWorkout);
      await tester.pumpTimes();

      await tester.tap(find.text(l.saveUntickedSets));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(Workouts.of(context).hasActiveWorkout, isFalse);
    });
  });
}
