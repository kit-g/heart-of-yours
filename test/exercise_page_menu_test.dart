// An exercise page's ⋯ (#710): a popup hanging off the button, like the
// Exercises tab's and a workout's, not a sheet at the bottom of the screen.
// The menu closes itself on a pick, so archiving and unarchiving leave the
// page on their own: off it, past an archive emptied, and a failure said.
import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActionSheet;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/exercise_detail_test_helpers.dart';
import 'support/harness.dart';

void main() {
  final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms, isMine: true);
  final row = Exercise(name: 'My Row', category: .dumbbell, target: .back, isMine: true);

  group('on the page', () {
    late ExerciseDetailState state;

    setUp(() async {
      state = await buildExerciseDetailState();
    });

    /// [exercise]'s page pushed over [under] — the pages it was reached
    /// through — each a bare page named for itself.
    Future<void> open(
      WidgetTester tester,
      Exercise exercise, {
      List<String> under = const ['Library'],
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<Exercises>.value(value: state.exercises),
            ChangeNotifierProvider<Workouts>.value(value: state.workouts),
            ChangeNotifierProvider<Preferences>.value(value: state.preferences),
            ChangeNotifierProvider<Charts>.value(value: state.charts),
            ChangeNotifierProvider<Goals>.value(value: state.goals),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(body: Text(under.first)),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final page in under.skip(1)) {
        navigator.push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(page))));
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseDetailPage(exercise: exercise, onTapWorkout: (_) async {}, initialTab: 'history'),
        ),
      );
      await tester.pumpAndSettle();
    }

    L copy(WidgetTester tester) => L.of(tester.element(find.byType(Navigator)));

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip(copy(tester).exerciseOptions));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the options hang off their button',
      (tester) async {
        await state.exercises.makeExercise(curl);
        await open(tester, curl);
        final l = copy(tester);
        final button = tester.getRect(find.byTooltip(l.exerciseOptions));

        await openMenu(tester);

        // neither of the sheets this used to be: Material's, or Cupertino's
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(CupertinoActionSheet), findsNothing);
        expect(find.text(l.edit), findsOneWidget);
        expect(find.text(l.archive), findsOneWidget);
        final edit = tester.getRect(
          find.ancestor(of: find.text(l.edit), matching: find.byWidgetPredicate((w) => w is PopupMenuItem)),
        );
        expect(edit.top, greaterThanOrEqualTo(button.bottom - 1));
        expect(edit.right, closeTo(button.right, 8));
        expect(edit.right, lessThanOrEqualTo(390));
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({.android, .iOS}),
    );

    testWidgets('Edit opens the dialog over the page, which stays', (tester) async {
      await state.exercises.makeExercise(curl);
      // wide enough for the dialog's header in the test font
      await open(tester, curl, size: const Size(1194, 834));
      final l = copy(tester);

      await openMenu(tester);
      await tester.tap(find.text(l.edit));
      await tester.pumpAndSettle();

      expect(find.text(curl.name), findsWidgets);
      expect(find.text(l.save), findsOneWidget);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets('archive, confirmed: put away, and back on the page beneath', (tester) async {
      await state.exercises.makeExercise(curl);
      await open(tester, curl);
      final l = copy(tester);

      await openMenu(tester);
      await tester.tap(find.text(l.archive));
      await tester.pumpAndSettle();
      expect(find.text(l.archiveConfirmTitle(curl.name)), findsOneWidget);

      await tester.tap(find.text(l.archive).last);
      await tester.pumpAndSettle();

      expect(state.exercises.lookup(curl.id)?.isArchived, isTrue);
      expect(find.text('Library'), findsOneWidget);
      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('archive, cancelled: the dialog goes and the page stays', (tester) async {
      await state.exercises.makeExercise(curl);
      await open(tester, curl);
      final l = copy(tester);

      await openMenu(tester);
      await tester.tap(find.text(l.archive));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();

      expect(state.exercises.lookup(curl.id)?.isArchived, isFalse);
      expect(find.text(l.archiveConfirmTitle(curl.name)), findsNothing);
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
    });

    testWidgets('unarchive with more left in the archive: back on the page beneath', (tester) async {
      await state.exercises.makeExercise(curl.copyWith(isArchived: true));
      await state.exercises.makeExercise(row.copyWith(isArchived: true));
      await open(tester, curl, under: ['Library', 'Archive']);
      final l = copy(tester);

      await openMenu(tester);
      expect(find.text(l.archive), findsNothing);
      await tester.tap(find.text(l.unarchive));
      await tester.pumpAndSettle();

      expect(state.exercises.lookup(curl.id)?.isArchived, isFalse);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.byType(ExerciseDetailPage), findsNothing);
    });

    testWidgets('unarchive the last one: no page that is not the archive is stepped past', (tester) async {
      await state.exercises.makeExercise(curl.copyWith(isArchived: true));
      // not the archive's route, as when the page was reached by a link
      await open(tester, curl, under: ['Library', 'Elsewhere']);
      final l = copy(tester);

      await openMenu(tester);
      await tester.tap(find.text(l.unarchive));
      await tester.pumpAndSettle();

      expect(state.exercises.archived, isEmpty);
      expect(find.text('Elsewhere'), findsOneWidget);
    });

    group('when the account refuses the change', () {
      setUp(() {
        final remote = MockRemoteExerciseService();
        when(remote.editExercise(any)).thenThrow(Exception('offline'));
        final exercises = Exercises(
          service: state.exerciseService,
          remoteService: remote,
          libraryService: MockExerciseLibraryService(),
          catalogService: MockLocalCatalogService(),
          preferenceService: MockRemoteExercisePreferenceService(),
          remote: RemoteAccess(),
        )..userId = 'u1';
        state = ExerciseDetailState(
          exercises: exercises,
          workouts: state.workouts,
          preferences: state.preferences,
          charts: state.charts,
          goals: state.goals,
          exerciseService: state.exerciseService,
          workoutService: state.workoutService,
          chartService: state.chartService,
        );
      });

      testWidgets('an archive that fails says so where the user went', (tester) async {
        await state.exercises.makeExercise(curl);
        await open(tester, curl);
        final l = copy(tester);

        await openMenu(tester);
        await tester.tap(find.text(l.archive));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.archive).last);
        await tester.pumpAndSettle();

        expect(find.text('Library'), findsOneWidget);
        expect(find.text(l.exerciseArchiveFailed(curl.name)), findsOneWidget);
        expect(state.exercises.lookup(curl.id)?.isArchived, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('an unarchive that fails says so where the user went', (tester) async {
        await state.exercises.makeExercise(curl.copyWith(isArchived: true));
        await state.exercises.makeExercise(row.copyWith(isArchived: true));
        await open(tester, curl, under: ['Library', 'Archive']);
        final l = copy(tester);

        await openMenu(tester);
        await tester.tap(find.text(l.unarchive));
        await tester.pumpAndSettle();

        expect(find.text('Archive'), findsOneWidget);
        expect(find.text(l.exerciseUnarchiveFailed(curl.name)), findsOneWidget);
        expect(state.exercises.lookup(curl.id)?.isArchived, isTrue);
        expect(tester.takeException(), isNull);
      });
    });
  });

  // through the app's own routes, which decide where a page lands: the tab's
  // archive opens an exercise with a `go` on a tablet, the archive over the
  // tabs pushes one, and a link can open one with nothing under it
  group('in the app', () {
    final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    final shelved = Exercise(name: 'Old Curl', category: .dumbbell, target: .arms, isMine: true).copyWith(
      isArchived: true,
    );
    final shelvedToo = Exercise(name: 'Old Row', category: .dumbbell, target: .back, isMine: true).copyWith(
      isArchived: true,
    );

    late MockLocalDatabase db;
    late MockApi api;

    setUp(() {
      db = MockLocalDatabase();
      api = MockApi();
      stubStartup(db, api);
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, shelved]));
    });

    Future<void> start(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: MockCdn(),
        firebaseAuth: MockFirebaseAuth(signedIn: false),
        settle: false,
      );
      await tester.pumpTimes();
      // the startup chain never resolves under a widget test's clock
      await Exercises.of(tester.element(find.byType(MaterialApp))).init();
      await tester.pumpTimes();
    }

    Exercises exercises(WidgetTester tester) => Exercises.of(tester.element(find.byType(MaterialApp)));

    GoRouter router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

    Future<void> openFromTheTab(WidgetTester tester, Exercise exercise) async {
      await tester.tapByKey(AppKeys.exercisesStack);
      await tester.pumpTimes();
      await tester.tap(find.byTooltip('Exercise options').first);
      await tester.pumpTimes();
      await tester.tap(find.text('Show archived'));
      await tester.pumpTimes();
      await tester.tap(find.text(exercise.name));
      await tester.pumpTimes();
    }

    Future<void> unarchive(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Exercise options').last);
      await tester.pumpTimes();
      await tester.tap(find.text('Unarchive'));
      await tester.pumpTimes();
    }

    testWidgets('on a phone, unarchiving the last one lands on the library', (tester) async {
      await start(tester);
      await openFromTheTab(tester, shelved);

      await unarchive(tester);

      expect(exercises(tester).archived, isEmpty);
      expect(find.text('Archived exercises'), findsNothing);
      expect(find.byType(ExerciseDetailPage), findsNothing);
      // the library, still there to use
      expect(find.text(bench.name), findsOneWidget);
      expect(find.byTooltip('Exercise options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a phone, unarchiving one of several lands back on the archive', (tester) async {
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, shelved, shelvedToo]));
      await start(tester);
      await openFromTheTab(tester, shelved);

      await unarchive(tester);

      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(find.text('Archived exercises'), findsOneWidget);
      expect(find.text(shelvedToo.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a tablet\'s two panes, unarchiving the last one keeps the library', (tester) async {
      await start(tester, size: const Size(1194, 834));
      await tester.tapByKey(AppKeys.exercisesStack);
      await tester.pumpTimes();
      // the tab's archive is not shown beside the library on a tablet (#718):
      // the page is reached as the archive's rows reach it, with a `go`
      router(tester).go('/exercises/${shelved.id}');
      await tester.pumpTimes();

      await unarchive(tester);

      expect(exercises(tester).archived, isEmpty);
      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(find.text(bench.name), findsOneWidget);
      expect(find.byTooltip('Exercise options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // the archive over any tab (#608), an exercise opened over it in turn
    for (final (outcome, archived) in [
      ('the last one steps back past the emptied archive too', [shelved]),
      ('one of several lands back on the archive', [shelved, shelvedToo]),
    ]) {
      testWidgets('over the tabs, unarchiving $outcome', (tester) async {
        when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, ...archived]));
        await start(tester);
        unawaited(router(tester).push('/archived-exercises'));
        await tester.pumpTimes();
        expect(find.text('Archived exercises'), findsOneWidget);
        await tester.tap(find.text(shelved.name));
        await tester.pumpTimes();

        await unarchive(tester);

        expect(find.byType(ExerciseDetailPage), findsNothing);
        expect(find.byType(ExerciseArchive), archived.length == 1 ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a page a link opened with nothing under it leaves for the library', (tester) async {
      await start(tester);
      router(tester).go('/exercise/${shelved.id}');
      await tester.pumpTimes();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);

      await unarchive(tester);

      expect(exercises(tester).archived, isEmpty);
      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(find.text(bench.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
