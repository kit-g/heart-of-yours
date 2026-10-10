import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';

/// The lock screen's rest buttons (#141): commands applied by the one applier
/// the watch uses, a queued one drained once the workout is known, a stale
/// one dropped — and after every one, the state as the app has it, sent.
void main() {
  late MockWorkoutService local;
  late Workouts workouts;
  late Alarms alarms;
  late AppTheme theme;
  late Preferences preferences;
  late Exercises exercises;
  late Timers timers;
  late _Surface surface;
  late DateTime clock;

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
    tz.initializeTimeZones();
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
    preferences.lockScreenWorkout = true;

    clock = DateTime.utc(2026, 1, 1, 10);
    local = MockWorkoutService();
    workouts = Workouts(service: local, remoteService: MockRemoteWorkoutService())..userId = 'u1';
    alarms = Alarms(now: () => clock);
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
    surface = _Surface();
  });

  tearDown(() {
    alarms.stopActiveExerciseTimer();
    surface.dispose();
  });

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
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => OngoingWorkoutPresenter(surface: surface, child: child!),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
  }

  /// A workout in progress, known to be so, resting on its first exercise.
  Future<Workout> restingWorkout(WidgetTester tester) async {
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await workouts.init();
    alarms.startActiveExerciseTimer(90, exerciseId: workout.first.id);
    await pump(tester);
    return workout;
  }

  testWidgets('skip from the lock screen stops the rest, and the surface hears the rest is gone', (tester) async {
    final workout = await restingWorkout(tester);
    expect(surface.last?.rest, isNotNull);
    final shows = surface.calls.length;

    surface.command(WatchSkipRest(workout.id));
    await tester.pump();

    expect(alarms.remainsInActiveExercise, isNull);
    expect(surface.calls.length, greaterThan(shows));
    expect(surface.last?.rest, isNull);
  });

  testWidgets('ten seconds on from the lock screen moves the rest\'s end, and the surface hears the new end', (
    tester,
  ) async {
    final workout = await restingWorkout(tester);
    final end = alarms.activeExerciseEnd!;

    surface.command(WatchAdjustRest(workout.id, seconds: 10));
    await tester.pump();

    expect(alarms.activeExerciseEnd, end.add(const Duration(seconds: 10)));
    expect(surface.last?.rest?.end, end.add(const Duration(seconds: 10)));
    alarms.stopActiveExerciseTimer();
  });

  testWidgets('a button pressed while the app was not running is applied once the workout is known', (
    tester,
  ) async {
    // the queue is read at start, before the mirror has been read
    final workout = push();
    surface.queued = [WatchSkipRest(workout.id)];
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await pump(tester);
    await tester.pump();
    expect(workouts.hasResolvedActiveWorkout, isFalse);

    // the rest a previous process left counting is restored alongside the
    // workout (Alarms.restore); until the workout is known, the skip waits
    alarms.startActiveExerciseTimer(90, exerciseId: workout.first.id);
    await tester.pump();
    expect(alarms.remainsInActiveExercise, isNotNull);
    await workouts.init();
    await tester.pump();

    expect(alarms.remainsInActiveExercise, isNull, reason: 'the queued skip lands once the workout is known');
  });

  testWidgets('a queued button waits for the rest a killed process left, and lands on it', (tester) async {
    // a cold start: the workout is read, then the rest comes back from the
    // store; a skip queued before both must not be dropped in between
    final workout = push();
    final store = _Store()
      ..saved = (exerciseId: workout.first.id, end: clock.add(const Duration(seconds: 60)), total: 90);
    alarms.dispose();
    alarms = Alarms(now: () => clock, store: store);
    surface.queued = [WatchSkipRest(workout.id)];
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await pump(tester);
    await tester.pump();

    await workouts.init();
    await tester.pump();
    expect(alarms.remainsInActiveExercise, isNull, reason: 'nothing to skip yet: the rest is still on its way');

    await alarms.restore(workout);
    await tester.pump();

    expect(alarms.remainsInActiveExercise, isNull, reason: 'the queued skip lands on the restored rest');
    expect(store.saved, isNull);
  });

  testWidgets('a queued button is not judged a stray before the preferences are read', (tester) async {
    // a cold start: the button arrives before the device's preferences, among
    // them the lock-screen switch, have been read — "off" would be a lie
    final workout = push();
    preferences.dispose();
    preferences = Preferences();
    surface.queued = [WatchSkipRest(workout.id)];
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    alarms.startActiveExerciseTimer(90, exerciseId: workout.first.id);
    await workouts.init();
    await pump(tester);
    await tester.pump();
    expect(alarms.remainsInActiveExercise, isNotNull, reason: 'waits for the preferences');

    await preferences.init();
    preferences.lockScreenWorkout = true;
    await tester.pump();

    expect(alarms.remainsInActiveExercise, isNull);
  });

  testWidgets('a button about another workout changes nothing, and the surface is put right', (tester) async {
    await restingWorkout(tester);
    final end = alarms.activeExerciseEnd;
    final shows = surface.calls.length;

    surface.command(const WatchAdjustRest('some-other-workout', seconds: 10));
    await tester.pump();

    expect(alarms.activeExerciseEnd, end);
    // sent again, unchanged: the surface showed a change that did not happen
    expect(surface.calls.length, greaterThan(shows));
    expect(surface.last?.rest?.end, end);
    alarms.stopActiveExerciseTimer();
  });

  testWidgets('with the lock screen switched off, its buttons are strays', (tester) async {
    final workout = await restingWorkout(tester);
    preferences.lockScreenWorkout = false;
    await tester.pump();

    surface.command(WatchSkipRest(workout.id));
    await tester.pump();

    expect(alarms.remainsInActiveExercise, isNotNull);
    alarms.stopActiveExerciseTimer();
  });

  testWidgets('the last set\'s rest alert names its exercise, not a "Next:" that is not coming', (tester) async {
    final workout = Workout.fromExercises([
      WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5)),
    ], name: 'Push day');
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await workouts.init();
    await pump(tester);

    expect(surface.last?.done?.restSubtitle, 'Bench Press (Barbell)');
  });

  testWidgets('the snapshot names the set up next for the Done button, with what follows it', (tester) async {
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    when(local.markSetAsComplete(any)).thenAnswer((_) async {});
    await workouts.init();
    await pump(tester);

    final done = surface.last?.done;
    expect(done?.setId, workout.first.first.id);
    expect(done?.exerciseId, workout.first.id);
    expect(done?.label, 'Done');
    // the set after it, and the exercise's rest — none set for the bench
    expect(done?.afterExercise, 'Bench Press (Barbell)');
    expect(done?.afterNext, 'Next: set 2');
    expect(done?.restSeconds, isNull);
    expect(done?.restTitle, 'Rest complete!');
    expect(done?.restSkip, 'Skip');
    // something comes after it, so its rest's alert says what
    expect(done?.restSubtitle, 'Next: Bench Press (Barbell)');

    // the second set has nothing filled in: it cannot be ticked as it
    // stands, so once the first is done there is no button
    workouts.markSetAsComplete(workout.first, workout.first.first);
    await tester.pump();
    expect(surface.last?.done, isNull);
  });

  testWidgets('Done from the lock screen ticks the set up next and starts its rest', (tester) async {
    // two sets filled in: the second can be ticked as it stands, so it gets
    // the button once the first is done
    final block = WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))
      ..add(ExerciseSet(bench, weight: 60, reps: 5));
    final workout = Workout.fromExercises([block], name: 'Push day');
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    when(local.markSetAsComplete(any)).thenAnswer((_) async {});
    await workouts.init();
    // the applier starts the exercise's rest, as a tick on the phone would
    timers.setRestTimer(bench.id, 90);
    await pump(tester);
    final set = workout.first.first;
    expect(set.isCompleted, isFalse);

    surface.command(WatchComplete(workout.id, setId: set.id));
    await tester.pump();

    expect(set.isCompleted, isTrue);
    expect(alarms.activeExerciseId, workout.first.id);
    expect(alarms.remainsInActiveExercise?.value, 90);
    // the surface hears the next set, and the rest it is counting down
    expect(surface.last?.done?.setId, workout.first.toList()[1].id);
    expect(surface.last?.rest, isNotNull);
    alarms.stopActiveExerciseTimer();
  });

  testWidgets('a tick for a set already done, or gone, changes nothing and the surface is put right', (
    tester,
  ) async {
    final workout = push();
    when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
    await workouts.init();
    await pump(tester);
    final set = workout.first.first;
    workouts.markSetAsComplete(workout.first, set);
    await tester.pump();
    final shows = surface.calls.length;

    surface.command(WatchComplete(workout.id, setId: set.id));
    surface.command(WatchComplete(workout.id, setId: 'gone'));
    await tester.pump();

    expect(workout.first.where((set) => set.isCompleted), hasLength(1), reason: 'never ticked twice');
    expect(alarms.remainsInActiveExercise, isNull);
    expect(surface.calls.length, greaterThan(shows));
  });

  group('start rest by voice (#98)', () {
    testWidgets('starts the exercise\'s own rest when no length is said', (tester) async {
      final workout = push();
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
      await workouts.init();
      await timers.setRestTimer(bench.id, 90);
      await pump(tester);

      surface.command(WatchStartRest(workout.id));
      await tester.pump();

      expect(alarms.activeExerciseId, workout.first.id);
      expect(alarms.remainsInActiveExercise?.value, 90);
      expect(surface.last?.rest?.end, alarms.activeExerciseEnd);
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('a length said wins over the setting, and replaces a rest already counting', (tester) async {
      final workout = push();
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
      await workouts.init();
      await timers.setRestTimer(bench.id, 90);
      alarms.startActiveExerciseTimer(30, exerciseId: workout.first.id);
      await pump(tester);

      surface.command(WatchStartRest(workout.id, seconds: 120));
      await tester.pump();

      expect(alarms.remainsInActiveExercise?.value, 120);
      alarms.stopActiveExerciseTimer();
    });

    testWidgets('an exercise with no rest timer, and nothing said, starts nothing', (tester) async {
      final workout = push();
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
      await workouts.init();
      await pump(tester);

      surface.command(WatchStartRest(workout.id));
      await tester.pump();

      expect(alarms.remainsInActiveExercise, isNull);
    });

    testWidgets('asked for a while ago, only what is left of the rest runs', (tester) async {
      final workout = push();
      when(local.getActiveWorkout('u1')).thenAnswer((_) async => workout);
      await workouts.init();
      await pump(tester);

      surface.command(
        WatchStartRest(workout.id, seconds: 90, at: DateTime.now().subtract(const Duration(seconds: 60))),
      );
      await tester.pump();
      expect(alarms.remainsInActiveExercise?.value, inInclusiveRange(29, 30));
      alarms.stopActiveExerciseTimer();

      surface.command(WatchStartRest(workout.id, seconds: 90, at: DateTime.now().subtract(const Duration(minutes: 5))));
      await tester.pump();
      expect(alarms.remainsInActiveExercise, isNull, reason: 'over before it arrived');
    });
  });

  test('the lock screen sends the labels of its buttons with the rest', () {
    // copy, from presentation: the native side only lays it out
    expect(
      (
        start: clock,
        end: clock,
        label: 'Rest',
        over: 'Rest complete!',
        minus: '-10s',
        plus: '+10s',
        skip: 'Skip',
      ),
      isA<OngoingRest>(),
    );
  });
}

class _Surface implements OngoingWorkoutSurface {
  final calls = <String>[];
  OngoingWorkout? last;
  List<WatchCommand> queued = [];
  final _commands = StreamController<WatchCommand>.broadcast();

  void command(WatchCommand command) => _commands.add(command);

  void dispose() => _commands.close();

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> show(OngoingWorkout workout) async {
    calls.add('show');
    last = workout;
  }

  @override
  Future<void> end() async {
    calls.add('end');
    last = null;
  }

  @override
  Stream<WatchCommand> get commands => _commands.stream;

  @override
  Future<List<WatchCommand>> takeCommands() async {
    final taken = queued;
    queued = [];
    return taken;
  }
}

/// The device's memory of a rest, in memory.
class _Store implements RestStore {
  SavedRest? saved;

  @override
  Future<SavedRest?> read() async => saved;

  @override
  Future<void> write(SavedRest rest) async => saved = rest;

  @override
  Future<void> clear() async => saved = null;
}
