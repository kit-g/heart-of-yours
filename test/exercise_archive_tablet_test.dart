// The Exercises tab's archive on a tablet (#718): Show archived puts the
// archive where the library was, an exercise of it opens beside it, and taking
// one out of the archive lands back in a library that has it. Drives the real
// app, as exercises_tab_switch_test.dart does.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms, isMine: true).copyWith(isArchived: true);
  final row = Exercise(name: 'My Row', category: .dumbbell, target: .back, isMine: true).copyWith(isArchived: true);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, curl, row]));
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
    await tester.tapByKey(AppKeys.exercisesStack);
    await tester.pumpTimes();
    return router;
  }

  L l(WidgetTester tester) => L.of(tester.element(find.byType(ExercisesPage)));

  Future<void> showArchived(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l(tester).exerciseOptions));
    await tester.pumpTimes();
    await tester.tap(find.text(l(tester).showArchived));
    await tester.pumpTimes();
  }

  Future<void> unarchive(WidgetTester tester) async {
    final detail = find.byType(ExerciseDetailPage);
    final strings = L.of(tester.element(detail));
    await tester.tap(find.descendant(of: detail, matching: find.byTooltip(strings.exerciseOptions)).first);
    await tester.pumpTimes();
    await tester.tap(find.text(strings.unarchive));
    await tester.pumpTimes();
  }

  for (final (orientation, size) in [('landscape', const Size(1194, 834)), ('portrait', const Size(834, 1194))]) {
    group('on a tablet in $orientation', () {
      testWidgets('Show archived shows the archive, and an exercise of it opens beside it', (tester) async {
        final router = await launch(tester, size);
        await showArchived(tester);

        expect(find.byType(ExerciseArchive), findsOneWidget);
        expect(find.text(curl.name), findsOneWidget);
        expect(find.text(row.name), findsOneWidget);
        expect(find.text(bench.name), findsNothing, reason: 'the library is put away while the archive is up');

        await tester.tap(find.text(curl.name));
        await tester.pumpTimes();
        expect(find.byType(ExerciseDetailPage), findsOneWidget);
        expect(find.byType(ExerciseArchive), findsOneWidget, reason: 'the list stays the archive');
        expect(router.config.state.uri.path, '/exercises/archived/${curl.id}');

        // closing the pane leaves the archive; its Back, the library
        await tester.tapByKey(AppKeys.closeDetail);
        await tester.pumpTimes();
        expect(find.byType(ExerciseDetailPage), findsNothing);
        expect(find.byType(ExerciseArchive), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpTimes();
        expect(find.byType(ExerciseArchive), findsNothing);
        expect(find.text(bench.name), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('taking out one of several returns to the archive, the last to the library', (tester) async {
        await launch(tester, size);
        await showArchived(tester);

        await tester.tap(find.text(curl.name));
        await tester.pumpTimes();
        await unarchive(tester);
        expect(find.byType(ExerciseArchive), findsOneWidget);
        expect(find.byType(ExerciseDetailPage), findsNothing);
        expect(find.text(curl.name), findsNothing);

        await tester.tap(find.text(row.name));
        await tester.pumpTimes();
        await unarchive(tester);
        expect(find.byType(ExerciseArchive), findsNothing);
        // a library that has them again
        expect(find.text(row.name), findsWidgets);
        expect(find.text(curl.name), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('on a phone, an archived exercise still opens over the archive', (tester) async {
    await launch(tester, const Size(390, 844));
    await showArchived(tester);
    expect(find.byType(ExerciseArchive), findsOneWidget);

    await tester.tap(find.text(curl.name));
    await tester.pumpTimes();
    expect(find.byType(ExerciseDetailPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpTimes();
    expect(find.byType(ExerciseArchive), findsOneWidget);
  });
}
