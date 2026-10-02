import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The session's muscle map on the done screen (#223): under OK, behind a
/// button, and only when there is something to draw and the user kept it.
void main() {
  late Exercises exercises;
  late Preferences preferences;

  final bench = Exercise(
    name: 'Bench Press (Barbell)',
    category: .barbell,
    target: .chest,
    tags: MuscleTagging.fromJson(jsonDecode('{"primary": {"groups": ["chest"]}}')),
  );
  final custom = Exercise(name: 'Muffin Carry', category: .dumbbell, target: .core, isMine: true);

  setUp(() async {
    final service = MockExerciseService();
    final remote = MockRemoteExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, custom]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(
      remoteService: remote,
      service: service,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    await exercises.init();

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Workout session(Exercise exercise) {
    final workout = Workout(name: 'Monday');
    workout.add(exercise).first.isCompleted = true;
    return workout;
  }

  Future<void> pump(WidgetTester tester, Workout workout) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: WorkoutDone(
            workout: workout,
            onQuit: () {},
            workoutsThisWeekCallback: () async => 0,
            achievementsCallback: () async => const [],
            recordsCallback: () async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final button = find.byKey(AppKeys.musclesWorkedButton, skipOffstage: false);
  final map = find.byKey(AppKeys.workoutMuscleMap, skipOffstage: false);

  testWidgets('waits behind a button, and opens in place', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, session(bench));

    expect(button, findsOneWidget);
    expect(map, findsNothing, reason: 'never opened for the user');

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(map, findsOneWidget);
    expect(button, findsNothing);
  });

  testWidgets('is not built while the muscle map is off', (tester) async {
    await pump(tester, session(bench));
    expect(button, findsNothing);
  });

  testWidgets('is not built when the user left it out', (tester) async {
    preferences
      ..setFeature(Feature.muscleMap, on: true)
      ..setOption(.muscleMapWorkout, on: false);
    await pump(tester, session(bench));
    expect(button, findsNothing);
  });

  testWidgets('is not offered when nothing in the session could be placed', (tester) async {
    preferences.setFeature(Feature.muscleMap, on: true);
    await pump(tester, session(custom));
    expect(button, findsNothing);
  });
}
