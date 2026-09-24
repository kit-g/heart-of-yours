// The What's new page from its Settings row, over the real bundled notes:
// newest first, and capped at [readableWidth] on a tablet, where the column
// would otherwise be the pane's width (docs/handoff.md #4 — the mechanism
// export_page_layout_test.dart uses).
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Finder column() {
    return find.descendant(of: find.byType(WhatsNewPage), matching: find.byType(ListView));
  }

  Future<void> pumpWhatsNewAt(WidgetTester tester, Size size) async {
    // rootBundle caches each load's future, and one cached under an earlier
    // test's fake clock never delivers to a later test
    rootBundle.clear();
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
    // the row sits at the end of a long list
    await tester.scrollUntilVisible(
      find.byKey(AppKeys.whatsNew),
      200,
      scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
    );
    // built is not on screen: the list's cache extent builds the row first
    await tester.ensureVisible(find.byKey(AppKeys.whatsNew));
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.whatsNew);
    await tester.pumpTimes();
    // the notes come from the real asset bundle, which is real I/O that fake
    // time never advances — let the clock run until the list is there
    for (final _ in Iterable.generate(50)) {
      if (column().evaluate().isNotEmpty) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  // No phone-size counterpart, for the reason export_page_layout_test.dart
  // gives: the settings screen on the way overflows its logo stripe under the
  // test environment's fallback font.
  testWidgets('an iPad window caps the notes column at readableWidth', (tester) async {
    await pumpWhatsNewAt(tester, const Size(1194, 834));

    expect(tester.getSize(column()).width, readableWidth);
  });

  testWidgets('the settings row opens the bundled notes, newest release first', (tester) async {
    await pumpWhatsNewAt(tester, const Size(1194, 834));

    final texts = tester.widgetList<Text>(find.descendant(of: column(), matching: find.byType(Text)));
    expect(texts.first.data, '1.8.0');
    expect(find.text('Exercise notes'), findsOneWidget);
  });
}
