import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
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

  Workout three(Exercise exercise) {
    final workout = Workout(name: 'W')..add(exercise);
    workout.first
      ..add(ExerciseSet(exercise))
      ..add(ExerciseSet(exercise));
    return workout;
  }

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

  group('column headers (#225)', () {
    /// What a row's field shows: the fill reaches the model through
    /// `Workouts.editSet`, and the row has to follow it on screen.
    String shown(WidgetTester tester, Key key) {
      final field = find.descendant(of: find.byKey(key), matching: find.byType(TextField), matchRoot: true);
      return tester.widget<TextField>(field.first).controller!.text;
    }

    testWidgets('a value header fills its column from the top set, past the ticked ones', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = three(exercise);
      final [top, second, third] = workout.first.toList();
      await startWorkoutOn(tester, workout);

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(exercise.id, 1)), '60');
      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)), '8');
      third.isCompleted = true;

      await tester.tapByKey(WorkoutDetailKeys.fillFor(exercise.id, 'weight'));
      await tester.pumpTimes();

      expect(second.weight, 60.0);
      expect(third.weight, isNull, reason: 'a ticked set is not touched');
      expect(second.reps, isNull, reason: 'only the tapped column');
      expect(top.weight, 60.0);
      expect(shown(tester, WorkoutDetailKeys.weightFor(exercise.id, 2)), '60');
    });

    testWidgets('with nothing to fill from, a header does nothing', (tester) async {
      final exercise = Exercise(name: 'Squat', category: Category.barbell, target: Target.legs);
      final workout = three(exercise);
      await startWorkoutOn(tester, workout);

      await tester.tapByKey(WorkoutDetailKeys.fillFor(exercise.id, 'reps'));
      await tester.pumpTimes();

      expect(workout.first.every((set) => set.reps == null), isTrue);
      verifyNever(db.storeMeasurements(any));
    });

    testWidgets('the ✓ header ticks every set that can be, then unticks them all', (tester) async {
      final exercise = Exercise(name: 'Row', category: Category.barbell, target: Target.back);
      final workout = three(exercise);
      final [top, second, third] = workout.first.toList();
      for (final set in [top, second]) {
        set.setMeasurements(weight: 50, reps: 10);
      }
      await startWorkoutOn(tester, workout);

      await tester.tapByKey(WorkoutDetailKeys.tickAllFor(exercise.id));
      await tester.pumpTimes();
      expect(
        [top.isCompleted, second.isCompleted, third.isCompleted],
        [true, true, false],
        reason: 'a set with no values cannot be ticked',
      );

      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.weightFor(exercise.id, 3)), '50');
      await tester.enterTextAndWait(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 3)), '10');
      await tester.tapByKey(WorkoutDetailKeys.tickAllFor(exercise.id));
      await tester.pumpTimes();
      expect(third.isCompleted, isTrue);

      await tester.tapByKey(WorkoutDetailKeys.tickAllFor(exercise.id));
      await tester.pumpTimes();
      expect(workout.first.any((set) => set.isCompleted), isFalse, reason: 'all ticked, so all come off');
    });
  });

  group('set types (#151)', () {
    String? numberShownBy(String exerciseId, int index) {
      final face = find.descendant(
        of: find.byKey(WorkoutDetailKeys.setTypeFor(exerciseId, index)),
        matching: find.byType(Text),
      );
      return (face.evaluate().single.widget as Text).data;
    }

    testWidgets('the number opens the types; a warm-up wears its letter and gives up its number', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = three(exercise);
      final [warmup, ..._] = workout.first.toList();
      await startWorkoutOn(tester, workout);

      await tester.tapByKey(WorkoutDetailKeys.setTypeFor(exercise.id, 1));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.setTypeOption(.warmup));
      await tester.pumpTimes();

      expect(warmup.setType, SetType.warmup);
      verify(db.storeMeasurements(warmup)).called(1);
      expect(numberShownBy(exercise.id, 1), 'W');
      expect(numberShownBy(exercise.id, 2), '1', reason: 'the first working set is set one');
      expect(numberShownBy(exercise.id, 3), '2');
    });

    testWidgets('picking the type a set already is makes it plain again', (tester) async {
      final exercise = Exercise(name: 'Squat', category: Category.barbell, target: Target.legs);
      final workout = three(exercise);
      final [first, ..._] = workout.first.toList();
      first.setType = .drop;
      await startWorkoutOn(tester, workout);
      expect(numberShownBy(exercise.id, 1), 'D');

      await tester.tapByKey(WorkoutDetailKeys.setTypeFor(exercise.id, 1));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.setTypeOption(.drop));
      await tester.pumpTimes();

      expect(first.setType, SetType.normal);
      expect(numberShownBy(exercise.id, 1), '1');
    });

    testWidgets('the help button explains in place, and types nothing', (tester) async {
      final exercise = Exercise(name: 'Deadlift', category: Category.barbell, target: Target.back);
      final workout = three(exercise);
      await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byType(WorkoutDetail)));

      await tester.tapByKey(WorkoutDetailKeys.setTypeFor(exercise.id, 1));
      await tester.pumpTimes();
      expect(find.text(l.setTypeFailureExplained), findsNothing);

      await tester.tap(find.byTooltip(l.aboutSetType(l.setTypeFailure)));
      await tester.pumpTimes();

      expect(find.text(l.setTypeFailureExplained), findsOneWidget);
      expect(find.text(l.setTypeFailure), findsOneWidget, reason: 'the menu stays open beside it');
      expect(workout.first.first.setType, SetType.normal);
    });
  });

  group('RPE (#234)', () {
    void rpeOn() {
      SharedPreferences.setMockInitialValues({
        ...pastOnboarding(),
        'weightUnit': 'metric',
        'distanceUnit': 'metric',
        'feature-rpe': 'on',
      });
    }

    testWidgets('off, a focused field brings no bar: the app as it was before RPE', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      await startWorkoutOn(tester, three(exercise));

      await tester.tap(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)));
      await tester.pumpTimes();

      expect(find.byKey(WorkoutDetailKeys.rpeKey), findsNothing);
    });

    testWidgets('on, the key opens the picker, a rating lands on the set, and its cell says so', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = three(exercise);
      final set = workout.first.first;
      await startWorkoutOn(tester, workout);

      expect(find.byKey(WorkoutDetailKeys.rpeKey), findsNothing, reason: 'nothing until a field has focus');
      await tester.tap(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.rpeKey);
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.rpeValue(8.5));
      await tester.pumpTimes();

      expect(set.rpe, 8.5);
      verify(db.storeMeasurements(set)).called(1);
      expect(find.text('@8.5'), findsOneWidget);
      expect(find.text('RPE 8.5'), findsOneWidget, reason: 'back on the field, the key carries the rating');
    });

    testWidgets('picking the rating a set already has clears it', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Squat', category: Category.barbell, target: Target.legs);
      final workout = three(exercise);
      final set = workout.first.first..rpe = 9;
      await startWorkoutOn(tester, workout);
      expect(find.text('@9'), findsOneWidget);

      await tester.tap(find.byKey(WorkoutDetailKeys.repsFor(exercise.id, 1)));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.rpeKey);
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.rpeValue(9));
      await tester.pumpTimes();

      expect(set.rpe, isNull);
      expect(find.text('@9'), findsNothing);
    });

    testWidgets('off, a stored rating stays stored and unshown', (tester) async {
      final exercise = Exercise(name: 'Deadlift', category: Category.barbell, target: Target.back);
      final workout = three(exercise);
      final set = workout.first.first..rpe = 7;
      await startWorkoutOn(tester, workout);

      expect(find.text('@7'), findsNothing);
      expect(set.rpe, 7);
    });
  });
}
