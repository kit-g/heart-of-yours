import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// Repeating a past workout from History while another is going (#228): it
/// asks first, and on yes the active workout is deleted before the repeat is
/// started — never left behind to come back once the repeat is finished.
void main() {
  late MockWorkoutService local;
  late Workouts workouts;
  late Preferences preferences;
  late Exercises exercises;

  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  // discarding clears the old workout's notifications: no plugin runs under
  // `flutter test`, so it needs a stand-in (see workout_detail_utils_test.dart)
  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
    local = MockWorkoutService();
    when(local.startWorkout(any, any)).thenAnswer((_) async {});
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    workouts = Workouts(service: local, remoteService: MockRemoteWorkoutService())..userId = 'u1';

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
  });

  /// A finished Push Day on its History card, its menu opened on Repeat.
  Future<Workout> pumpPastPushDay(WidgetTester tester) async {
    final past = Workout(name: 'Push Day')..add(bench);
    past.finish(DateTime.now());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: WorkoutItem(workout: past)),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    return past;
  }

  testWidgets('over an active workout, confirming deletes it first, then starts the repeat', (tester) async {
    await workouts.startWorkout(source: .blank, name: 'Leg Day');
    final legDay = workouts.activeWorkout!.id;

    await pumpPastPushDay(tester);
    expect(find.text('Cancel current workout?'), findsOneWidget);

    await tester.tap(find.text('Yes, cancel that one and start a new workout'));
    await tester.pumpAndSettle();

    verifyInOrder([
      local.deleteWorkout(legDay),
      local.startWorkout(argThat(isA<Workout>().having((workout) => workout.name, 'name', 'Push Day')), any),
    ]);
    expect(workouts.activeWorkout?.name, 'Push Day');
  });

  testWidgets('over an active workout, keeping it changes nothing', (tester) async {
    await workouts.startWorkout(source: .blank, name: 'Leg Day');
    final legDay = workouts.activeWorkout!.id;

    await pumpPastPushDay(tester);
    await tester.tap(find.text('No, keep current workout'));
    await tester.pumpAndSettle();

    verifyNever(local.deleteWorkout(any));
    expect(workouts.activeWorkout?.id, legDay);
  });

  testWidgets('with nothing active, it asks the plain question and deletes nothing', (tester) async {
    await pumpPastPushDay(tester);
    expect(find.text('Cancel current workout?'), findsNothing);
    expect(find.text('Start a new workout from this template?'), findsOneWidget);

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();

    verifyNever(local.deleteWorkout(any));
    expect(workouts.activeWorkout?.name, 'Push Day');
  });
}
