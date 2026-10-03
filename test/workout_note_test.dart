import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';
import 'support/harness.dart';

/// The note on a whole workout (#235): added from the workout's ⋯ menu, shown
/// under its title, cleared with its ×, and on the History card.
void main() {
  // the app's own fonts, as the screens are laid out for them: the test font
  // is wider and overflows the app bars at phone width
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  for (final size in [const Size(390, 844), const Size(1194, 834), const Size(834, 1194)]) {
    testWidgets('the active workout adds, shows and clears its note at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = MockLocalDatabase();
      final api = MockApi();
      stubStartup(db, api);
      final ex = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
      final workout = Workout(name: 'Push day')..add(ex);
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [ex]));
      when(db.getActiveWorkout(any)).thenAnswer((_) async => workout);
      when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
      when(db.setWorkoutNote(any, any)).thenAnswer((_) async {});
      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: MockCdn(),
        firebaseAuth: MockFirebaseAuth(mockUser: _AnonymousUser(), signedIn: true),
        settle: false,
      );
      final state = Workouts.of(tester.element(find.byType(MaterialApp)));
      await state.startWorkout(source: .template, template: workout);
      await tester.tapByKey(AppKeys.workoutStack);
      await tester.pumpTimes();
      final id = state.activeWorkout!.id;
      expect(find.byKey(WorkoutDetailKeys.workoutNote), findsNothing);

      await tester.tapByKey(WorkoutDetailKeys.options);
      await tester.pumpTimes();
      await tester.tap(find.text('Add note'));
      await tester.pumpTimes();
      expect(find.text('Workout note'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Slept badly, kept it light  ');
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();

      verify(db.setWorkoutNote(id, 'Slept badly, kept it light')).called(1);
      expect(state.activeWorkout!.note, 'Slept badly, kept it light');
      expect(find.text('Slept badly, kept it light'), findsOneWidget);

      await tester.tapByKey(WorkoutDetailKeys.options);
      await tester.pumpTimes();
      expect(find.text('Edit note'), findsOneWidget);
      await tester.tap(find.text('Edit note'));
      await tester.pumpTimes();
      await tester.tap(find.text('Cancel'));
      await tester.pumpTimes();
      verifyNever(db.setWorkoutNote(id, any));

      await tester.tap(find.tooltip('Remove note'));
      await tester.pumpTimes();
      verify(db.setWorkoutNote(id, null)).called(1);
      expect(state.activeWorkout!.note, isNull);
      expect(find.byKey(WorkoutDetailKeys.workoutNote), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a History card shows the note under the date, and none without one', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = Preferences();
    await preferences.init();
    final exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    final noted = Workout(name: 'Push Day')
      ..add(bench)
      ..note = 'New gym, the bars run heavy'
      ..finish(DateTime.now());
    final plain = Workout(name: 'Pull Day')
      ..add(bench)
      ..finish(DateTime.now());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                WorkoutItem(workout: noted, showsMenuButton: false),
                WorkoutItem(workout: plain, showsMenuButton: false),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('New gym, the bars run heavy'), findsOneWidget);
    expect(find.byType(WorkoutItem), findsNWidgets(2));
  });
}

// MockUser otherwise supplies a remote avatar, unrelated to this offline flow.
// The upstream mock is mutable despite Firebase User's immutable annotation.
// ignore: must_be_immutable
class _AnonymousUser extends MockUser {
  new() : super(uid: 'anon', isAnonymous: true);

  @override
  String? get photoURL => null;
}
