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
    timers = Timers(service: MockTimersService())..userId = 'u1';
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
