// A bodyweight move's last time (#488). The owner's "Home — Strength" ended in
// Single Leg Bridge, a weighted-bodyweight exercise done with nothing added:
// completing such a set asks for reps alone, so its weight is stored null, and
// the Previous column read that null as a legacy row and showed a dash — every
// time, however often it had been done. The other exercises, all loaded,
// filled. Neither its place in the template nor the template lookup mattered:
// the template-scoped read and the anywhere read hand back the same row.
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  // the app's own fonts: the test font's em-wide glyphs overflow the sheet
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

  final squat = Exercise(name: 'Goblet Squat', category: .dumbbell, target: .legs);
  final bridge = Exercise(name: 'Single Leg Bridge', category: .weightedBodyWeight, target: .legs);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  // what heart_db's previous-sets query hands back for the two: json_object
  // keeps the bridge's null weight as a key with a null value
  final lastTime = <ExerciseId, List<Map<String, dynamic>>>{
    squat.id: [
      {'set_id': 's1', 'weight': 16.0, 'reps': 10, 'duration': null, 'distance': null, 'set_type': 'normal'},
    ],
    bridge.id: [
      {'set_id': 'b1', 'weight': null, 'reps': 12, 'duration': null, 'distance': null, 'set_type': 'normal'},
      {'set_id': 'b2', 'weight': null, 'reps': 10, 'duration': null, 'distance': null, 'set_type': 'normal'},
    ],
  };

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'weightUnit': 'metric'});
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.getPreviousSets(any)).thenAnswer((_) async => lastTime);
    when(
      db.getPreviousSetsInTemplate(any, any, before: anyNamed('before')),
    ).thenAnswer((_) async => lastTime);
  });

  for (final inTemplate in [false, true]) {
    testWidgets('the last exercise, a bridge with no added load, fills from last time '
        '(last time in this template ${inTemplate ? 'on' : 'off'})', (tester) async {
      // tall enough that the sheet holds both exercises without a scroll
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'u1', email: 'u1@test'),
          signedIn: true,
        ),
        hasLocalNotifications: false,
        settle: false,
      );
      await tester.pumpTimes();
      final context = tester.element(find.byType(MaterialApp));
      Preferences.of(context).setFeature(.previousInTemplate, on: inTemplate);
      // startup's read sits past `_initApp`'s first await, which a widget test
      // never gets beyond
      await (PreviousExercises.of(context)..userId = 'u1').init();

      final template = Workout(name: 'Home — Strength')
        ..add(squat)
        ..add(bridge);
      template.last.add(ExerciseSet(bridge));
      await Workouts.of(context).startWorkout(source: .template, template: template);
      await tester.tapByKey(AppKeys.workoutStack);
      await tester.pumpTimes();

      expect(find.text('16 kg x 10'), findsOneWidget, reason: 'the loaded exercise, as ever');
      // read as a reps-only move's is: the count is the whole of it
      expect(find.text('12 Reps'), findsOneWidget, reason: "the bridge's first set");
      expect(find.text('10 Reps'), findsOneWidget, reason: 'and its second, matched by position');

      await tester.tap(find.text('12 Reps'));
      await tester.pumpTimes();
      final field = find.descendant(
        of: find.byKey(WorkoutDetailKeys.repsFor(bridge.id, 1)),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(field).controller.text, '12');
    });
  }
}
