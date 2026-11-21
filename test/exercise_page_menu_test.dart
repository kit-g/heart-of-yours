// An exercise page's ⋯ (#710): a popup hanging off the button, like the
// Exercises tab's and a workout's, not a sheet at the bottom of the screen.
// The menu closes itself on a pick, so archiving and unarchiving leave the
// user where the sheet's flows did: off the page, and past an archive emptied.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart' hide Page;

import 'support/exercise_detail_test_helpers.dart';

void main() {
  final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms, isMine: true);
  final row = Exercise(name: 'My Row', category: .dumbbell, target: .back, isMine: true);

  late ExerciseDetailState state;

  setUp(() async {
    state = await buildExerciseDetailState();
  });

  /// [exercise]'s page pushed over [under] — the pages it was reached through —
  /// each a bare page named for itself.
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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('on ${platform.name}, the options hang off their button', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = platform;
        await state.exercises.makeExercise(curl);
        await open(tester, curl);
        final l = copy(tester);
        final button = tester.getRect(find.byTooltip(l.exerciseOptions));

        await openMenu(tester);

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(l.edit), findsOneWidget);
        expect(find.text(l.archive), findsOneWidget);
        final edit = tester.getRect(
          find.ancestor(of: find.text(l.edit), matching: find.byWidgetPredicate((w) => w is PopupMenuItem)),
        );
        expect(edit.top, greaterThanOrEqualTo(button.bottom - 1));
        expect(edit.right, closeTo(button.right, 8));
        expect(edit.right, lessThanOrEqualTo(390));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

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

  testWidgets('unarchive with more left in the archive: back on the archive', (tester) async {
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

  testWidgets('unarchive the last one: past the emptied archive, to the library', (tester) async {
    await state.exercises.makeExercise(curl.copyWith(isArchived: true));
    await open(tester, curl, under: ['Library', 'Archive']);
    final l = copy(tester);

    await openMenu(tester);
    await tester.tap(find.text(l.unarchive));
    await tester.pumpAndSettle();

    expect(state.exercises.archived, isEmpty);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
  });
}
