import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Drives `_ExerciseSetItem` (the row for a single set of an exercise) through
/// the real active-workout screen — it is a private widget, only reachable
/// through `WorkoutDetail`. Covers the category-dependent field layout
/// (`_buttons`), the parsing/validation switch in `_onDone`, and swipe-to-
/// remove.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
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

  /// The set's own row, keyed by its id in `set_item.dart` — not exposed as a
  /// constant, but a `ValueKey` compares by value, so building the same string
  /// here finds it.
  Key rowKeyFor(ExerciseSet set) => ValueKey<String>('_ExerciseSetItem.${set.id}');

  Finder fieldsIn(Key rowKey) => find.descendant(of: find.byKey(rowKey), matching: find.byType(TextField));

  group('barbell / weight+reps category', () {
    testWidgets('entering weight and reps then tapping done completes the set', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      expect(find.byKey(rowKeyFor(set)), findsOneWidget);

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(exercise.id, 1)), '60');
      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)), '10');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(set.weight, 60.0);
      expect(set.reps, 10);
      verify(db.markSetAsComplete(set)).called(1);
    });

    testWidgets('tapping done with reps missing leaves the set incomplete', (tester) async {
      final exercise = Exercise(name: 'Squat', category: Category.barbell, target: Target.legs);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(exercise.id, 1)), '100');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isFalse);
      expect(set.reps, isNull);
      verifyNever(db.markSetAsComplete(any));
    });
  });

  group('weighted bodyweight category', () {
    testWidgets('completes with reps only — weight is allowed to stay null', (tester) async {
      final exercise = Exercise(name: 'Weighted Dip', category: Category.weightedBodyWeight, target: Target.arms);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)), '8');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(set.reps, 8);
      expect(set.weight, isNull);
    });
  });

  group('reps-only category', () {
    testWidgets('single unkeyed field still completes the set', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      final fields = fieldsIn(rowKeyFor(set));
      expect(fields, findsOneWidget);
      await tester.enterTextAndWait(fields.first, '12');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(set.reps, 12);
    });
  });

  group('duration category', () {
    testWidgets('digits typed right-to-left parse as mm:ss seconds', (tester) async {
      final exercise = Exercise(name: 'Plank', category: Category.duration, target: Target.core);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      final fields = fieldsIn(rowKeyFor(set));
      expect(fields, findsOneWidget);
      // "130" -> TimeFormatter renders "1:30" -> parses to 90 seconds.
      await tester.enterTextAndWait(fields.first, '130');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(set.duration, 90);
    });
  });

  group('cardio category', () {
    testWidgets('entering distance and duration completes the set', (tester) async {
      final exercise = Exercise(name: 'Running', category: Category.cardio, target: Target.cardio);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      final fields = fieldsIn(rowKeyFor(set));
      expect(fields, findsNWidgets(2));

      // distance first, then duration ("130" -> 90 seconds)
      await tester.enterTextAndWait(fields.at(0), '5');
      await tester.enterTextAndWait(fields.at(1), '130');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isTrue);
      expect(set.distance, 5.0);
      expect(set.duration, 90);
    });
  });

  group('completed set toggling', () {
    testWidgets('tapping done on a completed set marks it incomplete again', (tester) async {
      final exercise = Exercise(name: 'Pull Up', category: Category.repsOnly, target: Target.back);
      final workout = Workout(name: 'W')..add(exercise);
      final set = workout.first.first;

      await startWorkoutOn(tester, workout);

      final fields = fieldsIn(rowKeyFor(set));
      await tester.enterTextAndWait(fields.first, '12');
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();
      expect(set.isCompleted, isTrue);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();

      expect(set.isCompleted, isFalse);
      verify(db.markSetAsIncomplete(set)).called(1);
    });
  });

  group('swipe to remove', () {
    testWidgets('swiping a set away removes it from its exercise', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = Workout(name: 'W')..add(exercise);
      final workoutExercise = workout.first;
      final set = workoutExercise.first;

      await startWorkoutOn(tester, workout);

      final rowFinder = find.byKey(rowKeyFor(set));
      expect(rowFinder, findsOneWidget);

      await tester.fling(rowFinder, const Offset(-600, 0), 1200);
      await tester.pumpTimes(10);

      expect(workoutExercise.contains(set), isFalse);
      verify(db.removeSet(set)).called(1);
      expect(find.byKey(rowKeyFor(set)), findsNothing);
    });
  });
}
