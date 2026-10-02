// The one quiet dot (#216): on the profile's Settings button and on the What's
// new row while What's new holds notes this device has not shown, and gone
// from both once What's new is opened.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  // the newest bundled version, read off disk: naming one would fail at the
  // next release
  final newest = ((jsonDecode(File('assets/whats_new/en.json').readAsStringSync()) as List).first as Map)['version'];

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
  });

  final gear = find.byTooltip("Settings, new in What's new");
  final dot = find.byType(Badge);

  /// Lets the clock run until [finder] matches: the notes are read from the
  /// real asset bundle, real I/O that fake time never advances.
  Future<void> until(WidgetTester tester, Finder finder) async {
    for (final _ in Iterable.generate(50)) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, {required Map<String, Object> stored}) async {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...stored});
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
      version: newest as String,
    );
    await tester.pumpTimes();
  }

  testWidgets('unread notes put a dot on Settings and its What\'s new row; opening it clears both', (tester) async {
    // read up to nothing: every note of the running version is new
    await pump(tester, stored: {'whatsNewRead': <String>[]});
    await until(tester, gear);
    expect(gear, findsOneWidget);

    await tester.tap(gear);
    await tester.pumpTimes();
    final row = find.byKey(AppKeys.whatsNew);
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpTimes();
    expect(find.descendant(of: row, matching: dot), findsOneWidget);
    expect(find.bySemanticsLabel("What's new, unread notes"), findsOneWidget);

    await tester.tap(row);
    await tester.pumpTimes();
    await until(tester, find.byType(WhatsNewPage));
    await tester.pumpTimes();

    expect(dot, findsNothing, reason: 'opened is read');
    final preferences = Preferences.of(tester.element(find.byType(WhatsNewPage)));
    expect(preferences.whatsNewRead, isNotEmpty);
  });

  testWidgets('a fresh install shows no dot', (tester) async {
    await pump(tester, stored: const {});
    await until(tester, find.byTooltip('Settings'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpTimes();

    expect(gear, findsNothing);
    expect(dot, findsNothing);
  });
}
