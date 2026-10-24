// An exercise's ⋯ on the workout sheet (#488): the app's popup at one fixed
// width, so a neighbour with a long name wraps inside the menu instead of
// pushing it past the screen's right edge — on a phone and in an iPad's pane,
// in English and in Russian, the app's longest locale.
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
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

void main() {
  // real text metrics: the test font is an em per glyph and wraps everything
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

  final bridge = Exercise(name: 'Single Leg Bridge', category: .weightedBodyWeight, target: .legs);
  final pushdown = Exercise(name: 'Triceps Pushdown (Cable - Straight Bar)', category: .machine, target: .arms);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'weightUnit': 'metric'});
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.removeExercise(any)).thenAnswer((_) async {});
    when(
      db.setExerciseUnit(exerciseName: anyNamed('exerciseName'), userId: anyNamed('userId'), unit: anyNamed('unit')),
    ).thenAnswer((_) async {});
    when(api.saveUnitPreference(any, any)).thenAnswer((_) async {});
  });

  Future<(BuildContext, Workout)> start(WidgetTester tester, {required double width, Locale? locale}) async {
    rootBundle.clear();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (locale != null) {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    }
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
    final template = Workout(name: 'Home — Strength')
      ..add(bridge)
      ..add(pushdown);
    await Workouts.of(context).startWorkout(source: .template, template: template);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    return (context, Workouts.of(context).activeWorkout!);
  }

  Future<void> openMenu(WidgetTester tester, Exercise exercise) async {
    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(exercise.id));
    await tester.pumpTimes();
  }

  for (final width in [390.0, 1194.0]) {
    for (final locale in [const Locale('en'), const Locale('ru')]) {
      testWidgets('at ${width.round()}pt in ${locale.languageCode}, a long neighbour wraps inside the menu', (
        tester,
      ) async {
        await start(tester, width: width, locale: locale);
        final l = lookupL(locale);
        await openMenu(tester, bridge);

        final superset = find.byKey(WorkoutDetailKeys.groupWith(bridge.id, pushdown.id));
        expect(superset, findsOneWidget);
        expect(find.text(l.supersetWith(pushdown.name)), findsOneWidget);

        final row = tester.getRect(superset);
        expect(row.width, 280, reason: 'one width, whatever the rows say');
        expect(row.right, lessThanOrEqualTo(width), reason: 'the menu stays on screen');
        expect(row.left, greaterThanOrEqualTo(0));
        // its right edge hangs from the button's, short of the popup's own
        // 8pt margin from the screen's edge where the button sits closer
        final button = tester.getRect(find.byKey(WorkoutDetailKeys.exerciseOptionsFor(bridge.id)));
        expect(row.right, closeTo(button.right, 8));
        expect(tester.takeException(), isNull);

        // most used first, removing it last
        final rest = tester.getRect(find.text(l.restTimer).last);
        final remove = tester.getRect(find.byKey(WorkoutDetailKeys.removeExerciseFor(bridge.id)));
        expect(rest.top, lessThan(row.top));
        expect(remove.top, greaterThan(row.top));
        expect(remove.width, 280);
      });
    }
  }

  testWidgets('the unit row opens its two choices where the menu was, and keeps the pick', (tester) async {
    final (context, _) = await start(tester, width: 390);
    await openMenu(tester, pushdown);

    expect(find.text('Weight unit'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget, reason: 'the unit in force, at the end of its row');
    await tester.tap(find.text('Weight unit'));
    await tester.pumpTimes();
    expect(find.text('Imperial'), findsOneWidget);
    await tester.tap(find.text('Imperial'));
    await tester.pumpTimes();

    expect(Exercises.of(context).unitFor(pushdown.id), MeasurementUnit.imperial);
  });

  testWidgets('remove takes the exercise off the sheet', (tester) async {
    final (_, workout) = await start(tester, width: 390);
    await openMenu(tester, bridge);
    await tester.tapByKey(WorkoutDetailKeys.removeExerciseFor(bridge.id));
    await tester.pumpTimes();

    expect(workout.map((each) => each.exercise.id), [pushdown.id]);
    verify(db.removeExercise(any)).called(1);
  });
}
