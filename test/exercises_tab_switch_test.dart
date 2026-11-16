// The Exercises tab left out (#608): the bar and the rail reflow to three
// tabs, a screen on the tab moves off it, the tab comes back where it was, and
// a way into it opens the same page over the screen on view. Drives the real
// app, as tab_root_back_test.dart does.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    when(db.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
  });

  Future<HeartRouter> launch(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = HeartRouter();
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();
    // the startup chain never resolves under a widget test's clock
    await Exercises.of(tester.element(find.byType(MaterialApp))).init();
    await tester.pumpTimes();
    return router;
  }

  Preferences preferences(WidgetTester tester) => Preferences.of(tester.element(find.byType(MaterialApp)));

  Future<void> setTab(WidgetTester tester, {required bool on}) async {
    preferences(tester).setFeature(.exercisesTab, on: on);
    await tester.pumpTimes();
  }

  for (final (device, size) in [('a phone', const Size(390, 844)), ('a tablet', const Size(1194, 834))]) {
    testWidgets('on $device, off takes the tab out of the bar, and on brings it back', (tester) async {
      await launch(tester, size);
      expect(preferences(tester).isOn(.exercisesTab), isTrue, reason: 'on until turned off');
      expect(find.byKey(AppKeys.exercisesStack), findsOneWidget);

      await setTab(tester, on: false);
      expect(find.byKey(AppKeys.exercisesStack), findsNothing);
      // the three left still open their own screens
      await tester.tapByKey(AppKeys.historyStack);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.profileStack);
      await tester.pumpTimes();
      expect(find.byType(ProfilePage), findsOneWidget);

      await setTab(tester, on: true);
      expect(find.byKey(AppKeys.exercisesStack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on $device, off while on the tab moves to Profile, and on finds the tab as it was', (tester) async {
      await launch(tester, size);
      await tester.tapByKey(AppKeys.exercisesStack);
      await tester.pumpTimes();
      await tester.tap(find.text(bench.name).first);
      await tester.pumpTimes();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);

      await setTab(tester, on: false);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(tester.takeException(), isNull);

      await setTab(tester, on: true);
      await tester.tapByKey(AppKeys.exercisesStack);
      await tester.pumpTimes();
      // the branch was never taken down: the exercise is still open in it
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
    });
  }

  testWidgets('off, a link to an exercise opens it over the screen on view, and Back returns there', (tester) async {
    final router = await launch(tester, const Size(390, 844));
    await setTab(tester, on: false);
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();

    router.config.go('/exercises/${bench.id}');
    await tester.pumpTimes();
    expect(find.byType(ExerciseDetailPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpTimes();
    expect(find.byType(ExerciseDetailPage), findsNothing);
    expect(router.config.state.uri.path, startsWith('/history'));
  });

  testWidgets('off, the archive opens over the screen on view', (tester) async {
    final router = await launch(tester, const Size(390, 844));
    await setTab(tester, on: false);

    router.config.go('/exercises/archived');
    await tester.pumpTimes();
    expect(find.byType(ExerciseArchive), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('on, a link to an exercise still opens it in the tab', (tester) async {
    final router = await launch(tester, const Size(390, 844));

    router.config.go('/exercises/${bench.id}');
    await tester.pumpTimes();
    expect(find.byType(ExerciseDetailPage), findsOneWidget);
    expect(router.config.state.uri.path, '/exercises/${bench.id}');
  });
}
