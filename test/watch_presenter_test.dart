import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/watch.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';

/// The watch app (#182): what the phone tells it, and — the opt-in — when it
/// says nothing at all. Opening Heart on the watch is the yes; until then the
/// phone is silent, and an explicit answer from Settings outranks the watch.
void main() {
  late MockWorkoutService local;
  late Workouts workouts;
  late Alarms alarms;
  late AppTheme theme;
  late Preferences preferences;
  late Exercises exercises;
  late Timers timers;
  late PreviousExercises previous;
  late _Link link;

  final bench = Exercise.fromJson({
    'id': 'id-bench',
    'name': 'Bench Press (Barbell)',
    'category': 'Barbell',
    'target': 'Chest',
    'archived': false,
  });

  Workout push() {
    final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))..add(ExerciseSet(bench));
    return Workout.fromExercises([block], name: 'Push day');
  }

  setUpAll(() {
    // a tick from the watch schedules the rest notification, as a tick on the
    // phone does; no plugin registrant runs under `flutter test`
    tz.initializeTimeZones();
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    local = MockWorkoutService();
    workouts = Workouts(service: local, remoteService: MockRemoteWorkoutService())..userId = 'u1';
    alarms = Alarms();
    theme = AppTheme()..preset = .forge;
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    final timersService = MockTimersService();
    when(
      timersService.setRestTimer(
        exerciseName: anyNamed('exerciseName'),
        userId: anyNamed('userId'),
        seconds: anyNamed('seconds'),
      ),
    ).thenAnswer((_) async {});
    timers = Timers(service: timersService)..userId = 'u1';
    previous = PreviousExercises(service: MockPreviousExerciseService());
    link = _Link();
  });

  tearDown(() => link.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Alarms>.value(value: alarms),
          ChangeNotifierProvider<AppTheme>.value(value: theme),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Timers>.value(value: timers),
          ChangeNotifierProvider<PreviousExercises>.value(value: previous),
          Provider<Analytics>.value(value: Analytics(service: _NoAnalytics())),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => WatchPresenter(link: link, child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('never opened: the phone says nothing, even mid-workout', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());

    await pump(tester);
    await workouts.init();
    await tester.pump();

    expect(preferences.featureAnswer(.watchApp), FeatureAnswer.unasked);
    expect(link.sent, isEmpty, reason: 'a watch app installed automatically has not been asked for');
  });

  testWidgets('opening the watch app is the yes, and the workout follows', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
    await pump(tester);
    await workouts.init();
    await tester.pump();

    link.emit(.opened);
    await tester.pump();

    expect(preferences.isOn(.watchApp), isTrue);
    final sent = link.sent.single;
    expect(sent, isA<WatchWorkout>());
    final workout = (sent as WatchWorkout).workout;
    expect(workout.title, 'Push day');
    expect(workout.exercise, 'Bench Press (Barbell)');
    expect(workout.next, 'Next: set 1 · 60 kg x 5');
  });

  testWidgets('opened while the phone app was not running still counts', (tester) async {
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => null);
    link.openedUnseen = true;

    await pump(tester);
    await workouts.init();
    await tester.pump();

    expect(preferences.isOn(.watchApp), isTrue);
    expect(link.sent.last, const WatchMessage.idle('Start a workout on your iPhone'));
  });

  testWidgets('switched off in Settings, opening the watch does not switch it back on', (tester) async {
    preferences.setFeature(.watchApp, on: false);
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
    await pump(tester);
    await workouts.init();
    await tester.pump();

    link.emit(.opened);
    await tester.pump();

    expect(preferences.featureAnswer(.watchApp), FeatureAnswer.off);
    expect(link.sent.last, const WatchMessage.off('Turned off in Heart on your iPhone'));
  });

  testWidgets('the switch works both ways mid-workout', (tester) async {
    preferences.setFeature(.watchApp, on: true);
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => push());
    await pump(tester);
    await workouts.init();
    await tester.pump();
    expect(link.sent.last, isA<WatchWorkout>());

    preferences.setFeature(.watchApp, on: false);
    await tester.pump();
    expect(link.sent.last, isA<WatchMessage>());

    preferences.setFeature(.watchApp, on: true);
    await tester.pump();
    expect(link.sent.last, isA<WatchWorkout>());
    expect(link.sent, hasLength(3));
  });

  testWidgets('only changes cross the channel, and a reopened watch is sent the state again', (tester) async {
    preferences.setFeature(.watchApp, on: true);
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await pump(tester);
    await workouts.init();
    await tester.pump();
    expect(link.sent, hasLength(1));

    // a notify that changes nothing the watch shows
    workouts.pointedAtExercise = null;
    await tester.pump();
    expect(link.sent, hasLength(1));

    final block = workout.first;
    await workouts.markSetAsComplete(block, block.first);
    await tester.pump();
    expect(link.sent, hasLength(2));
    expect((link.sent.last as WatchWorkout).workout.next, 'Next: set 2');

    // reinstalled on the watch: it has nothing, whatever this side last sent
    link.emit(.opened);
    await tester.pump();
    expect(link.sent, hasLength(3));
    expect(link.sent[2], link.sent[1]);
  });

  testWidgets('no workout is only said once that is known', (tester) async {
    preferences.setFeature(.watchApp, on: true);
    final loaded = Completer<Workout?>();
    when(local.getActiveWorkout('u1')).thenAnswer((_) => loaded.future);

    await pump(tester);
    final init = workouts.init();
    await tester.pump();
    expect(link.sent, isEmpty, reason: 'still loading is not "no workout"');

    loaded.complete(null);
    await init;
    await tester.pump();
    expect(link.sent.single, isA<WatchMessage>());
  });

  group('from the wrist (#183)', () {
    late Workout workout;

    /// [prepare] shapes the workout before the phone first reads it.
    Future<void> running(WidgetTester tester, {void Function(Workout)? prepare}) async {
      preferences.setFeature(.watchApp, on: true);
      workout = push();
      prepare?.call(workout);
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
      await pump(tester);
      await workouts.init();
      await tester.pump();
    }

    WatchSet upNext() => (link.sent.last as WatchWorkout).set!;

    testWidgets('the watch is sent the set up next, in the unit it is shown in', (tester) async {
      preferences.setWeightUnit(.imperial);
      await running(tester);

      final set = upNext();
      expect(set.setId, workout.first.first.id);
      expect(set.exerciseId, workout.first.id);
      expect(set.weight, closeTo(132.3, 0.1), reason: '60 kg, as the phone would show it in pounds');
      expect(set.reps, 5);
      expect(set.unit, 'lbs');
      expect(set.step, 5);
      final sent = link.sent.last as WatchWorkout;
      expect(sent.controls?.done, 'Done');
      expect(sent.controls?.bpm, 'bpm', reason: 'the words for what the watch measures travel; readings never do');
      expect(sent.activity, 'strength');
    });

    testWidgets('a tick from the watch goes through Workouts, with the values it showed', (tester) async {
      await timers.setRestTimer('id-bench', 90);
      await running(tester);
      final first = workout.first.first;

      link.command(WatchComplete(workout.id, setId: first.id, weight: 62.5, reps: 6));
      await tester.pump();

      expect(first.isCompleted, isTrue);
      expect(first.weight, 62.5);
      expect(first.reps, 6);
      verify(local.storeMeasurements(first)).called(1);
      expect(alarms.activeExerciseId, workout.first.id, reason: "the exercise's rest starts, as on the phone");
      expect(upNext().setId, workout.first.elementAt(1).id, reason: 'the watch moves on once the phone has it');
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('pounds from the watch are stored as kilograms', (tester) async {
      preferences.setWeightUnit(.imperial);
      await running(tester);
      final first = workout.first.first;

      link.command(WatchComplete(workout.id, setId: first.id, weight: 135, reps: 5));
      await tester.pump();

      expect(first.weight, closeTo(61.2, 0.1));
    });

    testWidgets('pause and resume from the wrist go through Workouts, placed when they happened (#134)', (
      tester,
    ) async {
      preferences.setFeature(.pauseWorkout, on: true);
      await timers.setRestTimer('id-bench', 90);
      await running(tester, prepare: (workout) => workout.start = workout.start.subtract(const Duration(minutes: 10)));
      expect((link.sent.last as WatchWorkout).pausable, isTrue);
      final first = workout.first.first;
      // ticked a minute ago: a pause placed earlier than the last tick would
      // be moved up to it
      final ticked = DateTime.now().subtract(const Duration(minutes: 1));
      link.command(WatchComplete(workout.id, setId: first.id, weight: 60, reps: 5, at: ticked));
      await tester.pump();
      expect(alarms.activeExerciseId, isNotNull);

      final paused = DateTime.now().subtract(const Duration(seconds: 30));
      link.command(WatchPauseWorkout(workout.id, at: paused));
      await tester.pump();

      expect(workouts.pausedAt, paused.toUtc(), reason: 'when the wrist said, not when the phone heard');
      expect(alarms.activeExerciseId, isNull, reason: 'a pause skips the rest, as on the phone');
      expect((link.sent.last as WatchWorkout).workout.pausedAt, paused.toUtc());

      final resumed = DateTime.now();
      link.command(WatchResumeWorkout(workout.id, at: resumed));
      await tester.pump();

      expect(workouts.isPaused, isFalse);
      final sent = link.sent.last as WatchWorkout;
      expect(sent.workout.pausedAt, isNull);
      expect(sent.pauses.single, (start: paused.toUtc(), end: resumed.toUtc()));
      expect(sent.workout.clockStart, workout.start.add(resumed.difference(paused)));
    });

    testWidgets('off, the watch is offered no pause, and one it sends anyway does nothing (#134)', (tester) async {
      await running(tester);
      expect((link.sent.last as WatchWorkout).pausable, isFalse);

      link.command(WatchPauseWorkout(workout.id));
      await tester.pump();

      expect(workouts.isPaused, isFalse);
    });

    testWidgets('a tick from the wrist while paused resumes the workout at the tick (#134)', (tester) async {
      preferences.setFeature(.pauseWorkout, on: true);
      await running(tester, prepare: (workout) => workout.start = workout.start.subtract(const Duration(minutes: 10)));
      final paused = DateTime.now().subtract(const Duration(minutes: 2));
      await workouts.pause(at: paused);
      final ticked = DateTime.now().subtract(const Duration(minutes: 1));

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: ticked));
      await tester.pump();

      expect(workouts.isPaused, isFalse);
      expect(workouts.activeWorkout!.pauses.single.end, ticked.toUtc());
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('a second tick for the same set changes nothing, and is answered', (tester) async {
      await running(tester);
      final first = workout.first.first;

      link.command(WatchComplete(workout.id, setId: first.id, weight: 60, reps: 5));
      await tester.pump();
      final before = link.sent.length;

      link.command(WatchComplete(workout.id, setId: first.id, weight: 99, reps: 9));
      await tester.pump();

      expect(first.weight, 60, reason: 'a ticked set is not rewritten by a late or repeated tap');
      expect(link.sent.length, before + 1, reason: 'the watch hears back even when nothing changed');
    });

    testWidgets('the watch is sent the whole workout, for going back to a set', (tester) async {
      preferences.setWeightUnit(.imperial);
      await running(tester);

      final sent = link.sent.last as WatchWorkout;
      expect(sent.set?.position, 'Set 1 of 2');
      expect(sent.exercises, hasLength(1));
      final (:id, :name, :unit, :weighted, :counted, :sets, step: _, rest: _) = sent.exercises.single;
      expect(id, workout.first.id);
      expect(name, 'Bench Press (Barbell)');
      expect(unit, 'lbs');
      expect((weighted, counted), (true, true));
      expect(sets.map((set) => set.id), workout.first.map((set) => set.id));
      expect(sets.first.weight, closeTo(132.3, 0.1), reason: 'in the unit the phone shows it in, as the set up next');
      expect(sets.map((set) => set.done), [false, false]);
    });

    testWidgets('every set carries what the watch shows once it is up next, for moving on without the phone', (
      tester,
    ) async {
      await timers.setRestTimer('id-bench', 90);
      await running(tester);

      final sent = link.sent.last as WatchWorkout;
      final exercise = sent.exercises.single;
      expect(
        exercise.rest,
        90,
        reason: 'the rest a tick starts, which the watch starts itself while the phone is away',
      );
      final [first, second] = exercise.sets;
      expect((first.position, second.position), ('Set 1 of 2', 'Set 2 of 2'));
      expect(first.next, sent.workout.next, reason: 'the same line the lock screen shows for it');
      expect(sent.controls?.restLabel, isNotEmpty);
      expect(sent.controls?.idle, 'Start a workout on your iPhone');
    });

    testWidgets('a warm-up reads as one on the watch, and only plain sets are numbered', (tester) async {
      await running(tester, prepare: (workout) => workout.first.first.setType = .warmup);

      final sent = link.sent.last as WatchWorkout;
      expect(sent.set?.position, 'Warm up', reason: 'the set up next is the warm-up');
      final [first, second] = sent.exercises.single.sets;
      expect((first.mark, first.type, first.position), ('W', 'Warm up', 'Warm up'));
      expect((second.mark, second.type, second.position), ('1', null, 'Set 1 of 1'));
    });

    testWidgets('a tick that arrives late starts only what is left of its rest', (tester) async {
      await timers.setRestTimer('id-bench', 90);
      await running(tester);
      final ticked = DateTime.now().subtract(const Duration(seconds: 60));

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: ticked));
      await tester.pump();

      expect(workout.first.first.isCompleted, isTrue);
      final left = alarms.activeExerciseEnd!.difference(DateTime.now()).inSeconds;
      expect(left, inInclusiveRange(28, 31), reason: 'ticked a minute ago on the watch: 30 seconds of a 90 remain');
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('a late batch from the watch is counted for the user once it is all in', (tester) async {
      await running(tester);
      final away = DateTime.now().subtract(const Duration(minutes: 3));
      final [first, second] = workout.first.toList();

      link.command(WatchComplete(workout.id, setId: first.id, weight: 60, reps: 5, at: away));
      link.command(WatchComplete(workout.id, setId: second.id, weight: 60, reps: 5, at: away));
      await tester.pump();
      expect(find.text('2 sets from your watch'), findsNothing, reason: 'not while the batch may still be arriving');

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('2 sets from your watch'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('watch content the system has not handed over yet is announced, and cleared when it lands', (
      tester,
    ) async {
      link.pendingContent = true;
      await running(tester);
      await tester.pump();
      expect(find.text('Catching up with your watch…'), findsOneWidget);

      final away = DateTime.now().subtract(const Duration(minutes: 3));
      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: away));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Catching up with your watch…'), findsNothing);
      expect(find.text('1 set from your watch'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the watch saying it is back with a queue is announced at once', (tester) async {
      await running(tester);

      link.emit(.catchingUp);
      await tester.pump();
      await tester.pump();

      expect(find.text('Catching up with your watch…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Catching up with your watch…'), findsNothing, reason: 'and gives up if nothing comes');
    });

    testWidgets('a batch nobody announced says it is catching up while it lands', (tester) async {
      await running(tester);
      final away = DateTime.now().subtract(const Duration(minutes: 3));

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: away));
      await tester.pump();
      await tester.pump();

      expect(find.text('Catching up with your watch…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('1 set from your watch'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a tick made on the watch just now says nothing on the phone', (tester) async {
      await running(tester);

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: DateTime.now()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.textContaining('from your watch'), findsNothing);
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('a tick that arrives after its rest would have ended starts none', (tester) async {
      await timers.setRestTimer('id-bench', 90);
      await running(tester);
      final ticked = DateTime.now().subtract(const Duration(minutes: 5));

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5, at: ticked));
      await tester.pump();

      expect(workout.first.first.isCompleted, isTrue);
      expect(alarms.activeExerciseEnd, isNull);
    });

    testWidgets('a set gone back to takes new values and keeps its tick', (tester) async {
      preferences.setWeightUnit(.imperial);
      await running(tester);
      final first = workout.first.first;
      link.command(WatchComplete(workout.id, setId: first.id, weight: 135, reps: 5));
      await tester.pump();
      alarms.stopActiveExerciseTimer();

      link.command(WatchEditSet(workout.id, setId: first.id, weight: 145, reps: 4));
      await tester.pump();

      expect(first.isCompleted, isTrue);
      expect(first.weight, closeTo(65.8, 0.1), reason: 'pounds from the watch are stored as kilograms');
      expect(first.reps, 4);
      final row = (link.sent.last as WatchWorkout).exercises.single.sets.first;
      expect(row.weight, closeTo(145, 0.1));
      expect((row.reps, row.done), (4, true));
    });

    testWidgets('a set ticked by mistake is unticked', (tester) async {
      await running(tester);
      final first = workout.first.first;
      link.command(WatchComplete(workout.id, setId: first.id, weight: 60, reps: 5));
      await tester.pump();
      alarms.stopActiveExerciseTimer();

      link.command(WatchUntickSet(workout.id, setId: first.id));
      await tester.pump();

      expect(first.isCompleted, isFalse);
      verify(local.markSetAsIncomplete(first)).called(1);
      expect((link.sent.last as WatchWorkout).exercises.single.sets.first.done, isFalse);
    });

    testWidgets('a command about another workout is ignored', (tester) async {
      await running(tester);

      link.command(WatchComplete('some-other-workout', setId: workout.first.first.id, reps: 5));
      await tester.pump();

      expect(workout.first.first.isCompleted, isFalse);
    });

    testWidgets('rest is skipped and adjusted from the watch', (tester) async {
      await timers.setRestTimer('id-bench', 90);
      await running(tester);
      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5));
      await tester.pump();
      final end = alarms.activeExerciseEnd!;

      link.command(WatchAdjustRest(workout.id, seconds: 10));
      await tester.pump();
      expect(alarms.activeExerciseEnd, end.add(const Duration(seconds: 10)));

      link.command(WatchSkipRest(workout.id));
      await tester.pump();
      expect(alarms.activeExerciseEnd, isNull);
      expect((link.sent.last as WatchWorkout).workout.rest, isNull);
    });

    testWidgets('a tick sent while the phone app was not running lands once the workout loads', (tester) async {
      preferences.setFeature(.watchApp, on: true);
      workout = push();
      final loaded = Completer<Workout?>();
      when(local.getActiveWorkout('u1')).thenAnswer((_) => loaded.future);
      link.queued = [WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5)];

      await pump(tester);
      final init = workouts.init();
      await tester.pump();
      expect(workout.first.first.isCompleted, isFalse, reason: 'nothing to apply it to yet');

      loaded.complete(workout);
      await init;
      await tester.pump();
      expect(workout.first.first.isCompleted, isTrue);
    });

    testWidgets('Finish from the wrist is ignored while a set is still open', (tester) async {
      await running(tester);
      final before = link.sent.length;

      link.command(WatchFinishWorkout(workout.id));
      await tester.pump();

      expect(workouts.activeWorkout, isNotNull, reason: 'what is left unticked is the phone to ask about');
      expect(link.sent.length, before + 1, reason: 'the watch is answered with the state that stands');
    });

    testWidgets('switched off, commands are ignored', (tester) async {
      await running(tester);
      preferences.setFeature(.watchApp, on: false);
      await tester.pump();

      link.command(WatchComplete(workout.id, setId: workout.first.first.id, weight: 60, reps: 5));
      await tester.pump();

      expect(workout.first.first.isCompleted, isFalse);
    });
  });

  test('commands are read from what the watch sends, and anything else is dropped', () {
    expect(
      WatchCommand.fromMap({'action': 'complete', 'workoutId': 'w', 'setId': 's', 'weight': 60, 'reps': 5}),
      isA<WatchComplete>().having((c) => c.weight, 'weight', 60.0).having((c) => c.reps, 'reps', 5),
    );
    expect(WatchCommand.fromMap({'action': 'adjustRest', 'workoutId': 'w', 'seconds': -10}), isA<WatchAdjustRest>());
    expect(WatchCommand.fromMap({'action': 'skipRest', 'workoutId': 'w'}), isA<WatchSkipRest>());
    expect(WatchCommand.fromMap({'action': 'finish', 'workoutId': 'w'}), isA<WatchFinishWorkout>());
    expect(
      WatchCommand.fromMap({'action': 'edit', 'workoutId': 'w', 'setId': 's', 'weight': 62.5, 'reps': 4}),
      isA<WatchEditSet>().having((c) => c.weight, 'weight', 62.5).having((c) => c.reps, 'reps', 4),
    );
    expect(WatchCommand.fromMap({'action': 'untick', 'workoutId': 'w', 'setId': 's'}), isA<WatchUntickSet>());
    expect(WatchCommand.fromMap({'action': 'untick', 'workoutId': 'w'}), isNull);
    final at = DateTime(2026, 9, 30, 10, 15);
    expect(
      WatchCommand.fromMap({'action': 'finish', 'workoutId': 'w', 'at': at.millisecondsSinceEpoch})?.at,
      at,
      reason: 'when it happened on the watch, which is not when it arrives from a queue',
    );
    expect(WatchCommand.fromMap({'action': 'teleport', 'workoutId': 'w'}), isNull);
    expect(WatchCommand.fromMap({'action': 'complete'}), isNull);
  });

  test('a workout state carries finished copy and instants, nothing to translate', () {
    final start = DateTime.utc(2026, 9, 27, 10);
    final state = WatchWorkout(
      (
        workoutId: 'w1',
        startedAt: start,
        clockStart: start.add(const Duration(minutes: 3)),
        pausedAt: start.add(const Duration(minutes: 20)),
        pausedLabel: 'Paused',
        title: 'Push day',
        exercise: 'Bench Press (Barbell)',
        next: 'Next: set 2',
        rest: (start: start, end: start.add(const Duration(seconds: 90)), label: 'Rest', over: 'Rest complete!'),
        preset: .forge,
        stopwatch: null,
        channel: 'Workout in progress',
      ),
      activity: 'strength',
      pausable: true,
      pauses: [(start: start, end: start.add(const Duration(minutes: 3)))],
    );

    final map = state.toMap();
    expect(map['activity'], 'strength', reason: 'what the watch measures the session as (#184)');
    expect(map['state'], 'workout');
    expect(map['startedAt'], start.millisecondsSinceEpoch, reason: 'the session begins at the true start');
    expect(map['clockStart'], start.add(const Duration(minutes: 3)).millisecondsSinceEpoch);
    expect(map['pausedAt'], start.add(const Duration(minutes: 20)).millisecondsSinceEpoch);
    expect(map['pausable'], isTrue);
    expect(map['pauses'], [
      {'start': start.millisecondsSinceEpoch, 'end': start.add(const Duration(minutes: 3)).millisecondsSinceEpoch},
    ]);
    expect(map['restEnd'], start.add(const Duration(seconds: 90)).millisecondsSinceEpoch);
    expect(map['restOver'], 'Rest complete!');
    expect(map.containsKey('channel'), isFalse, reason: "Android's channel name means nothing on a watch");
    expect(map['accent'], isA<int>());
  });
}

class _Link implements WatchLink {
  final sent = <WatchState>[];
  final _events = StreamController<WatchEvent>.broadcast();
  final _commands = StreamController<WatchCommand>.broadcast();
  bool openedUnseen = false;
  bool pendingContent = false;
  List<WatchCommand> queued = [];

  @override
  Future<bool> contentPending() async => pendingContent;

  void emit(WatchEvent event) => _events.add(event);

  void command(WatchCommand command) => _commands.add(command);

  void dispose() {
    _events.close();
    _commands.close();
  }

  @override
  Stream<WatchEvent> get events => _events.stream;

  @override
  Stream<WatchCommand> get commands => _commands.stream;

  @override
  Future<bool> finish(String workoutId, {required DateTime end}) async => false;

  @override
  Future<bool> measures(String workoutId) async => false;

  @override
  Future<List<WatchCommand>> takeCommands() async {
    final taken = queued;
    queued = [];
    return taken;
  }

  @override
  Future<bool> isInstalled() async => true;

  @override
  Future<void> send(WatchState state) async => sent.add(state);

  @override
  Future<bool> takeOpened() async {
    final opened = openedUnseen;
    openedUnseen = false;
    return opened;
  }
}

class _NoAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
