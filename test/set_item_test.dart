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

  group('set stopwatch', () {
    Finder inRow(ExerciseSet set, Finder finder) => find.descendant(of: find.byKey(rowKeyFor(set)), matching: finder);
    Finder play(ExerciseSet set) => inRow(set, find.byIcon(Icons.play_arrow_rounded));
    Finder tick(ExerciseSet set) => inRow(set, find.byIcon(Icons.done));

    /// ▶ starts the stopwatch and shows it counting.
    Future<void> start(WidgetTester tester, ExerciseSet set) async {
      await tester.tap(play(set));
      await tester.pumpTimes();
    }

    Finder stop(ExerciseSet set) => inRow(set, find.byIcon(Icons.stop_rounded));

    Future<void> dialogButton(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(label)));
      await tester.pumpTimes();
    }

    testWidgets('▶ is the done button of every undone timed set, copied time or not; off, none is', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final [first, second, third] = workout.first.toList();
      second.setMeasurements(duration: 45);
      final context = await startWorkoutOn(tester, workout);
      final prefs = Preferences.of(context);
      await tester.pumpTimes();
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      prefs.setFeature(.setStopwatch, on: true);
      await tester.pumpTimes();
      expect(play(first), findsOneWidget);
      expect(play(second), findsOneWidget, reason: 'a held time is the target, not a reason to hide ▶');
      expect(play(third), findsOneWidget);

      prefs.setFeature(.setStopwatch, on: false);
      await tester.pumpTimes();
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('cancel writes nothing, and the set is as it was', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final set = workout.first.first..setMeasurements(duration: 45);
      final context = await startWorkoutOn(tester, workout);
      Preferences.of(context).setFeature(.setStopwatch, on: true);
      await tester.pumpTimes();

      await start(tester, set);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await dialogButton(tester, 'Cancel');

      expect(find.byType(Dialog), findsNothing);
      expect(Workouts.of(context).stopwatch.isRunning, isFalse);
      expect(set.duration, 45);
      expect(set.isCompleted, isFalse);
      expect(play(set), findsOneWidget);
    });

    testWidgets('pause holds the count, resume carries on, done writes and ticks with rest', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final set = workout.first.first;
      final context = await startWorkoutOn(tester, workout);
      Preferences.of(context).setFeature(.setStopwatch, on: true);
      when(
        db.setRestTimer(
          exerciseName: anyNamed('exerciseName'),
          userId: anyNamed('userId'),
          seconds: anyNamed('seconds'),
        ),
      ).thenAnswer((_) async {});
      await (Timers.of(context)..userId = 'u1').setRestTimer(exercise.id, 90);
      await tester.pumpTimes();
      final stopwatch = Workouts.of(context).stopwatch;

      await start(tester, set);
      await dialogButton(tester, 'Pause');
      expect(stopwatch.isPaused, isTrue);
      expect(find.text('Paused'), findsOneWidget);
      await dialogButton(tester, 'Resume');
      expect(stopwatch.isPaused, isFalse);
      await dialogButton(tester, 'Done');

      expect(set.duration, greaterThanOrEqualTo(1));
      expect(set.isCompleted, isTrue);
      expect(stopwatch.isRunning, isFalse);
      expect(Alarms.of(context).activeExerciseTotal, 90);
      Alarms.of(context).stopActiveExerciseTimer();
      await tester.pumpTimes();
    });

    testWidgets('▶ starts counting at once; ticked, ✓ unticks', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final set = workout.first.first..setMeasurements(duration: 45);
      final context = await startWorkoutOn(tester, workout);
      Preferences.of(context).setFeature(.setStopwatch, on: true);
      await tester.pumpTimes();

      await start(tester, set);
      expect(Workouts.of(context).stopwatch.isTiming(set), isTrue);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Pause')), findsOneWidget);
      await dialogButton(tester, 'Done');
      expect(set.isCompleted, isTrue);

      await tester.tap(tick(set));
      await tester.pumpTimes();
      expect(set.isCompleted, isFalse);
      expect(play(set), findsOneWidget);
    });

    testWidgets('closed, it runs on in the row: ■ in the done column brings it back', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final [first, second, _] = workout.first.toList();
      final context = await startWorkoutOn(tester, workout);
      Preferences.of(context).setFeature(.setStopwatch, on: true);
      await tester.pumpTimes();

      await start(tester, first);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpTimes();
      expect(find.byType(Dialog), findsNothing);
      expect(Workouts.of(context).stopwatch.isTiming(first), isTrue);
      expect(stop(first), findsOneWidget);
      expect(play(second), findsNothing, reason: 'one set is timed at a time');
      expect(tick(second), findsOneWidget, reason: 'the others keep a plain ✓');

      await tester.tap(stop(first));
      await tester.pumpTimes();
      expect(find.byType(Dialog), findsOneWidget);
      await dialogButton(tester, 'Cancel');
    });

    for (final (category, distance) in [(Category.duration, null), (Category.cardio, null), (Category.cardio, 5.0)]) {
      testWidgets('$category distance $distance: done after a cold start logs wall-clock seconds', (tester) async {
        final exercise = Exercise(name: 'Timed', category: category, target: .core);
        final workout = Workout(name: 'Timed')..add(exercise);
        final set = workout.first.first..setMeasurements(distance: distance);
        final started = DateTime.now().subtract(const Duration(seconds: 65));
        final context = await startWorkoutOn(tester, workout);
        Preferences.of(context).setFeature(.setStopwatch, on: true);
        final storage = await SharedPreferences.getInstance();
        await storage.setString(
          'setStopwatch.running',
          '{"workoutId":"${workout.id}","setId":"${set.id}","start":"${started.toIso8601String()}"}',
        );
        await Workouts.of(context).stopwatch.restore(workout);
        await tester.pumpTimes();

        await tester.tap(stop(set));
        await tester.pumpTimes();
        await dialogButton(tester, 'Done');
        expect(set.duration, greaterThanOrEqualTo(65));
        expect(set.isCompleted, category == .duration || distance != null);
        if (category == .cardio && distance == null) {
          final field = tester.widget<TextField>(fieldsIn(rowKeyFor(set)).first);
          expect(field.focusNode!.hasFocus, isTrue);
          verifyNever(db.markSetAsComplete(set));
        } else {
          verify(db.markSetAsComplete(set)).called(1);
        }
      });
    }

    for (final size in [const Size(390, 844), const Size(1194, 834)]) {
      testWidgets('at $size a running cardio set with a long time and an RPE keeps its row', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final exercise = Exercise(name: 'Carry', category: .cardio, target: .core);
        final workout = Workout(name: 'Timed')..add(exercise);
        final set = workout.first.first..rpe = 8;
        final context = await startWorkoutOn(tester, workout);
        final prefs = Preferences.of(context)..setFeature(.rpe, on: true);
        await tester.pumpTimes();
        final height = tester.getSize(find.byKey(rowKeyFor(set))).height;

        prefs.setFeature(.setStopwatch, on: true);
        await tester.pumpTimes();
        final storage = await SharedPreferences.getInstance();
        final started = DateTime.now().subtract(const Duration(hours: 1, minutes: 2, seconds: 3));
        await storage.setString(
          'setStopwatch.running',
          '{"workoutId":"${workout.id}","setId":"${set.id}","start":"${started.toIso8601String()}"}',
        );
        await Workouts.of(context).stopwatch.restore(workout);
        await tester.pumpTimes();

        expect(stop(set), findsOneWidget);
        expect(find.text('@8'), findsOneWidget);
        // the Templates page behind the sheet overflows in the test font at
        // phone width; the row's own fit is the height check below
        tester.takeException();
        expect(tester.getSize(find.byKey(rowKeyFor(set))).height, height);
        Workouts.of(context).stopwatch.clear();
        await tester.pumpTimes();
      });
    }

    testWidgets('✓ refuses a zero time', (tester) async {
      final exercise = Exercise(name: 'Plank', category: .duration, target: .core);
      final workout = three(exercise);
      final set = workout.first.first;
      await startWorkoutOn(tester, workout);
      await tester.enterText(fieldsIn(rowKeyFor(set)).first, '0:00');
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.doneFor(exercise.id, 1));
      await tester.pumpTimes();
      expect(set.isCompleted, isFalse);
      verifyNever(db.markSetAsComplete(set));
    });
  });

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

    Future<void> openPopup(WidgetTester tester, Exercise exercise) async {
      await tester.tapByKey(WorkoutDetailKeys.setTypeFor(exercise.id, 1));
      await tester.pumpTimes();
    }

    testWidgets('off, the popup is the three types alone: the app as it was before RPE', (tester) async {
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      await startWorkoutOn(tester, three(exercise));

      await openPopup(tester, exercise);

      expect(find.byKey(WorkoutDetailKeys.setTypeOption(.warmup)), findsOneWidget);
      expect(find.byKey(WorkoutDetailKeys.rpeValue(8)), findsNothing);
    });

    testWidgets('on, a rating lands on the set, closes the popup, and its cell says so', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Bench Press', category: Category.barbell, target: Target.chest);
      final workout = three(exercise);
      final set = workout.first.first;
      await startWorkoutOn(tester, workout);

      await openPopup(tester, exercise);
      await tester.tapByKey(WorkoutDetailKeys.rpeValue(8.5));
      await tester.pumpTimes();

      expect(set.rpe, 8.5);
      expect(set.setType, SetType.normal, reason: 'a rating is not a type');
      verify(db.storeMeasurements(set)).called(1);
      expect(find.byKey(WorkoutDetailKeys.rpeValue(8.5)), findsNothing, reason: 'the popup closes on a rating');
      expect(find.text('@8.5'), findsOneWidget);
    });

    testWidgets('picking the rating a set already has clears it', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Squat', category: Category.barbell, target: Target.legs);
      final workout = three(exercise);
      final set = workout.first.first..rpe = 9;
      await startWorkoutOn(tester, workout);
      expect(find.text('@9'), findsOneWidget);

      await openPopup(tester, exercise);
      await tester.tapByKey(WorkoutDetailKeys.rpeValue(9));
      await tester.pumpTimes();

      expect(set.rpe, isNull);
      expect(find.text('@9'), findsNothing);
    });

    testWidgets('the × clears a rating, and is there only while there is one', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Row', category: Category.barbell, target: Target.back);
      final workout = three(exercise);
      final [rated, plain, ..._] = workout.first.toList();
      rated.rpe = 8;
      await startWorkoutOn(tester, workout);

      await tester.tapByKey(WorkoutDetailKeys.setTypeFor(exercise.id, 2));
      await tester.pumpTimes();
      expect(find.byKey(WorkoutDetailKeys.clearRpe), findsNothing, reason: 'an unrated set has nothing to clear');
      await tester.tapAt(Offset.zero);
      await tester.pumpTimes();

      await openPopup(tester, exercise);
      await tester.tapByKey(WorkoutDetailKeys.clearRpe);
      await tester.pumpTimes();

      expect(rated.rpe, isNull);
      expect(plain.rpe, isNull);
      expect(find.text('@8'), findsNothing);
    });

    testWidgets('the help button unfolds the scale in place, and rates nothing', (tester) async {
      rpeOn();
      final exercise = Exercise(name: 'Deadlift', category: Category.barbell, target: Target.back);
      final workout = three(exercise);
      await startWorkoutOn(tester, workout);
      final l = L.of(tester.element(find.byType(WorkoutDetail)));

      await openPopup(tester, exercise);
      expect(find.text(l.rpeScale10), findsNothing);
      await tester.tap(find.byTooltip(l.aboutRpe));
      await tester.pumpTimes();

      expect(find.text(l.rpeScale10), findsOneWidget);
      expect(find.byKey(WorkoutDetailKeys.rpeValue(8)), findsOneWidget, reason: 'the popup stays open');
      expect(workout.first.first.rpe, isNull);
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
