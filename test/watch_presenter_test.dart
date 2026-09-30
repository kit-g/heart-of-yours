import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/watch.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

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
          Provider<Analytics>.value(value: Analytics(service: _NoAnalytics())),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          builder: (context, child) => WatchPresenter(link: link, child: child!),
          home: const SizedBox.shrink(),
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

  test('a workout state carries finished copy and instants, nothing to translate', () {
    final start = DateTime.utc(2026, 9, 27, 10);
    final state = WatchWorkout((
      workoutId: 'w1',
      startedAt: start,
      title: 'Push day',
      exercise: 'Bench Press (Barbell)',
      next: 'Next: set 2',
      rest: (start: start, end: start.add(const Duration(seconds: 90)), label: 'Rest', over: 'Rest complete!'),
      preset: .forge,
      channel: 'Workout in progress',
    ));

    final map = state.toMap();
    expect(map['state'], 'workout');
    expect(map['startedAt'], start.millisecondsSinceEpoch);
    expect(map['restEnd'], start.add(const Duration(seconds: 90)).millisecondsSinceEpoch);
    expect(map['restOver'], 'Rest complete!');
    expect(map.containsKey('channel'), isFalse, reason: "Android's channel name means nothing on a watch");
    expect(map['accent'], isA<int>());
  });
}

class _Link implements WatchLink {
  final sent = <WatchState>[];
  final _events = StreamController<WatchEvent>.broadcast();
  bool openedUnseen = false;

  void emit(WatchEvent event) => _events.add(event);

  void dispose() => _events.close();

  @override
  Stream<WatchEvent> get events => _events.stream;

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
