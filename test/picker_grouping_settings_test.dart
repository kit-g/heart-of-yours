// How exercise lists are grouped (#620) in Settings, through the real app: the
// row shows the grouping in force, its menu hangs off that value, and a pick
// is the same preference the Exercises tab's options change.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/exercises/movement_copy.dart' show PickerGroupingCopy;
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  // wide: the test font draws every glyph as a square, and Settings' other
  // rows do not fit a phone in it
  Future<(Preferences, L, Finder)> openSettings(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    final settings = tester.element(find.byType(SettingsPage));
    final row = find.byKey(AppKeys.settingsPickerGrouping);
    await tester.ensureVisible(row);
    await tester.pumpTimes();
    return (Preferences.of(settings), L.of(settings), row);
  }

  testWidgets('the row names the grouping, its menu opens under the value, and a pick changes it', (tester) async {
    final (preferences, l, row) = await openSettings(tester, size: const Size(1200, 2400));
    final value = find.descendant(of: row, matching: find.text(PickerGrouping.none.label(l)));
    expect(value, findsOneWidget);

    await tester.tap(row);
    await tester.pumpTimes();
    final item = find.widgetWithText(CheckedPopupMenuItem<PickerGrouping>, PickerGrouping.target.label(l));
    expect(item, findsOneWidget);
    // the menu's far edge is the value's, not the row's past its padding
    final menu = find.ancestor(of: item, matching: find.byType(Material)).first;
    final unfold = find.descendant(of: row, matching: find.byIcon(Icons.unfold_more_rounded));
    expect(tester.getRect(menu).right, moreOrLessEquals(tester.getRect(unfold).right, epsilon: 1));

    await tester.tap(item);
    await tester.pumpTimes();
    expect(preferences.pickerGrouping, PickerGrouping.target);
    expect(find.descendant(of: row, matching: find.text(PickerGrouping.target.label(l))), findsOneWidget);
  });

  testWidgets('picking what the menu showed checked keeps a grouping that arrived while it was open', (tester) async {
    final (preferences, l, row) = await openSettings(tester, size: const Size(1200, 2400));
    await tester.tap(row);
    await tester.pumpTimes();

    // another device's choice, adopted by sync while the menu is up
    preferences.setPickerGrouping(.movement);
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<PickerGrouping>, PickerGrouping.none.label(l)));
    await tester.pumpTimes();
    expect(preferences.pickerGrouping, PickerGrouping.movement);
  });
}
