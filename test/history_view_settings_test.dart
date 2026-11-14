// What History opens on (#609) in Settings, through the real app: the row
// starts on the list, and a tap is the same preference History's own switch
// changes.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  testWidgets('the row starts on the list, and a tap changes what History opens on', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
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
    final preferences = Preferences.of(tester.element(find.byType(SettingsPage)));
    final l = L.of(tester.element(find.byType(SettingsPage)));
    final row = find.byKey(AppKeys.historyViewSetting);
    await tester.ensureVisible(row);
    expect(find.descendant(of: row, matching: find.text(l.historyView)), findsOneWidget);
    expect(preferences.historyView, HistoryView.list);

    await tester.tap(find.descendant(of: row, matching: find.text(l.calendar)));
    await tester.pumpTimes();
    expect(preferences.historyView, HistoryView.calendar);

    await tester.tap(find.descendant(of: row, matching: find.text(l.historyAsList)));
    await tester.pumpTimes();
    expect(preferences.historyView, HistoryView.list);
  });
}
