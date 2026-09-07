// Window-size coverage for the export page — the mechanism of
// integration_test/responsive_frame_test.dart applied to a single surface
// (docs/handoff.md #4), the same way import_page_layout_test.dart covers its
// sibling. The page is prose and two buttons, so it measures its own
// LayoutBuilder constraints and caps the column at [readableWidth].
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
  });

  Future<void> pumpExportPageAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      // the dashboard animates indefinitely — settle would hang on it
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.exportData);
    await tester.pumpTimes();
  }

  Size exportColumnSize(WidgetTester tester) {
    return tester.getSize(
      find.descendant(
        of: find.byType(ExportDataPage),
        matching: find.byType(ListView),
      ),
    );
  }

  // No phone-size counterpart, for the reason import_page_layout_test.dart
  // gives: the settings screen on the way overflows its logo stripe under the
  // test environment's fallback font. The phone branch is the degenerate
  // min(paneWidth, readableWidth), verified by screenshot.
  testWidgets('an iPad window caps the export column at readableWidth', (tester) async {
    await pumpExportPageAt(tester, const Size(1194, 834));

    expect(exportColumnSize(tester).width, readableWidth);
  });
}
