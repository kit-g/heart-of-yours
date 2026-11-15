// The grouping of exercise lists (#620) is chosen from the Exercises tab's
// options, on a phone and in a tablet's two panes alike, and every picker
// follows it. Drives the real app, as new_exercise_from_picker_test.dart does.
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

  Future<void> regroup(WidgetTester tester, {required String from, required String to}) async {
    await tester.tap(find.byTooltip('Exercise options').first);
    await tester.pumpTimes();
    // the entry names the grouping in force before it is opened
    await tester.tap(find.text('Group by: $from'));
    await tester.pumpTimes();
    expect(
      tester
          .widget<CheckedPopupMenuItem<PickerGrouping>>(
            find.widgetWithText(CheckedPopupMenuItem<PickerGrouping>, from),
          )
          .checked,
      isTrue,
    );
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<PickerGrouping>, to));
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
  }
}
