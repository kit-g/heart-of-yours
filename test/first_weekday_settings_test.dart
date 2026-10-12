// The first day of the week (#339) in Settings, through the real app: the row
// starts on the locale's day, offers the days weeks actually start on, and a
// tap is the preference every weekly count reads.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    stubStartup(db, api);
  });

  Future<Preferences> pumpToSettings(WidgetTester tester) async {
    // see erase_data_test.dart: a phone-plausible window under the test font
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    expect(find.byType(SettingsPage), findsOneWidget);
    return Preferences.of(tester.element(find.byType(SettingsPage)));
  }

  testWidgets("the row starts on the locale's day, and a tap changes the week", (tester) async {
    final semantics = tester.ensureSemantics();
    final preferences = await pumpToSettings(tester);
    final l = L.of(tester.element(find.byType(SettingsPage)));
    final row = find.ancestor(of: find.text(l.firstWeekday), matching: find.byType(Row)).first;
    await tester.ensureVisible(row);

    // the test window's locale is en_US, where weeks start on Sunday
    expect(preferences.firstWeekday, DateTime.sunday);
    for (final day in ['Saturday', 'Sunday', 'Monday']) {
      expect(
        find.descendant(of: row, matching: find.bySemanticsLabel(day)),
        findsOneWidget,
        reason: day,
      );
    }

    await tester.tap(find.descendant(of: row, matching: find.text('Mon')));
    await tester.pumpTimes();
    expect(preferences.firstWeekday, DateTime.monday);
    semantics.dispose();
  });
}
