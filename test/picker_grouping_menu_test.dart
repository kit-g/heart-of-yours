// The grouping of exercise lists (#620) is chosen from the Exercises tab's
// options, on a phone and in a tablet's two panes alike, and every picker
// follows it. The choices are in that one menu, which hangs off its button
// (#710). Drives the real app, as new_exercise_from_picker_test.dart does.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat]));
  });

  Future<void> openLibrary(WidgetTester tester) async {
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.exercisesStack);
    await tester.pumpTimes();
    // the startup chain never resolves under a widget test's clock
    await Exercises.of(tester.element(find.byType(MaterialApp))).init();
    await tester.pumpTimes();
  }

  Preferences preferences(WidgetTester tester) => Preferences.of(tester.element(find.byType(MaterialApp)));

  // the menu's value type is the page's own, so matched by kind
  Finder grouping(String label) {
    return find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem));
  }

  // the menu's own, not the picker's filter chips under it
  Finder inMenu(String label) {
    return find.descendant(of: find.byWidgetPredicate((w) => w is PopupMenuEntry), matching: find.text(label));
  }

  bool checked(WidgetTester tester, String label) => tester.widget<CheckedPopupMenuItem>(grouping(label)).checked;

  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Exercise options').first);
    await tester.pumpTimes();
  }

  Future<void> regroup(WidgetTester tester, {required String from, required String to}) async {
    await openOptions(tester);
    // the choices are in the options menu itself, the one in force checked
    expect(checked(tester, from), isTrue);
    expect(checked(tester, to), isFalse);
    await tester.tap(grouping(to));
    await tester.pumpTimes();
  }

  for (final (device, size) in [('a phone', const Size(390, 844)), ('a tablet\'s two panes', const Size(1194, 834))]) {
    testWidgets('on $device, the options menu groups the library, and says how it is grouped', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openLibrary(tester);
      expect(find.text(bench.name), findsOneWidget);

      await regroup(tester, from: 'None', to: 'Target');

      expect(preferences(tester).pickerGrouping, PickerGrouping.target);
      // folded headings, in place of the list
      expect(find.text('Chest'), findsWidgets);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text(bench.name), findsNothing);

      await regroup(tester, from: 'Target', to: 'None');
      expect(preferences(tester).pickerGrouping, PickerGrouping.none);
      expect(find.text(bench.name), findsOneWidget);
    });

    testWidgets('on $device, the options open under their button, as one menu', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openLibrary(tester);
      final button = tester.getRect(find.byTooltip('Exercise options').first);

      await openOptions(tester);

      expect(find.byType(BottomSheet), findsNothing);
      const entries = ['New exercise', 'Group exercises', 'None', 'Category', 'Target', 'Movement'];
      for (final entry in entries) {
        expect(inMenu(entry), findsOneWidget, reason: entry);
      }
      // nothing archived, so no way into an empty archive
      expect(inMenu('Show archived'), findsNothing);
      final tops = entries.map((each) => tester.getRect(inMenu(each)).top).toList();
      expect(tops, [...tops]..sort(), reason: 'in the order given');
      // hanging from the button's right edge, short of the popup's own 8pt
      // margin from the screen's edge
      final menu = tester.getRect(grouping('None'));
      expect(menu.top, greaterThanOrEqualTo(button.bottom - 1));
      expect(menu.right, closeTo(button.right, 8));
      expect(menu.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the checked grouping keeps what the menu showed, over a newer one synced in meanwhile', (tester) async {
    phone(tester);
    await openLibrary(tester);

    await openOptions(tester);
    expect(checked(tester, 'None'), isTrue);
    // another device's choice lands while the menu is up
    preferences(tester).setPickerGrouping(.movement);
    await tester.tap(grouping('None'));
    await tester.pumpTimes();

    expect(preferences(tester).pickerGrouping, PickerGrouping.movement);
  });

  testWidgets('New exercise opens the dialog from the menu', (tester) async {
    // wide enough for the dialog's header in the test font
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openLibrary(tester);

    await openOptions(tester);
    await tester.tap(inMenu('New exercise'));
    await tester.pumpTimes();

    expect(find.text('Create new exercise'), findsOneWidget);
    expect(inMenu('Group exercises'), findsNothing, reason: 'the menu closed itself');
  });

  testWidgets('with something archived, Show archived comes last and opens the archive', (tester) async {
    phone(tester);
    final shelved = Exercise(
      name: 'Old Curl',
      category: .dumbbell,
      target: .arms,
      isMine: true,
    ).copyWith(isArchived: true);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, squat, shelved]));
    await openLibrary(tester);

    await openOptions(tester);
    final archived = tester.getRect(inMenu('Show archived'));
    expect(archived.top, greaterThan(tester.getRect(inMenu('Movement')).top));
    await tester.tap(inMenu('Show archived'));
    await tester.pumpTimes();

    expect(find.text('Archived exercises'), findsOneWidget);
    expect(find.text(shelved.name), findsOneWidget);
  });
}
