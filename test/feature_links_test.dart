// Links to a feature's row on the Features page (#239): the button under a
// What's new note that names a feature, and a link from outside the app at
// `/profile/settings/features?feature=…`. Over the real bundled notes, where
// the muscle-map note carries `"feature": "muscleMap"`.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

class _Recorded implements AnalyticsService {
  final events = <(String, Map<String, Object>)>[];

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async => events.add((name, parameters));

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late _Recorded recorded;
  late HeartRouter router;

  // every note about the muscle map carries one; the newest is the one on top
  const button = ValueKey('whats-new-feature-muscleMap');
  const row = ValueKey('feature-muscleMap');

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    recorded = _Recorded();
    router = HeartRouter();
    stubStartup(db, api);
  });

  Iterable<Map<String, Object>> linked() {
    return recorded.events.where((event) => event.$1 == 'feature_linked').map((event) => event.$2);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    // rootBundle caches each load's future, and one cached under an earlier
    // test's fake clock never delivers to a later test
    rootBundle.clear();
    // a tablet window: the settings screen overflows its logo stripe at phone
    // size under the test font (whats_new_page_test.dart)
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      analytics: Analytics(service: recorded),
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
  }

  Future<void> openWhatsNew(WidgetTester tester) async {
    router.config.go('/profile/settings/whats-new');
    await tester.pumpTimes();
    // the notes are real asset I/O, which fake time never advances
    for (final _ in Iterable.generate(50)) {
      if (find.byKey(button).first.evaluate().isNotEmpty) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  Preferences preferences(WidgetTester tester) => Preferences.of(tester.element(find.byType(MaterialApp)));

  testWidgets('a note invites while the feature is off, says so while on, and only ever navigates', (tester) async {
    await pumpApp(tester);
    await openWhatsNew(tester);

    expect(find.descendant(of: find.byKey(button).first, matching: find.text('Turn on in Features')), findsOneWidget);

    await tester.ensureVisible(find.byKey(button).first);
    // laid out where the jump put it: below the window's fold when newer
    // notes sit above it
    await tester.pump();
    await tester.tap(find.byKey(button).first);
    // past the spotlight's fade
    await tester.pumpTimes(25);

    expect(find.byType(FeaturesPage), findsOneWidget);
    expect(find.byKey(row), findsOneWidget);
    expect(preferences(tester).isOn(Feature.muscleMap), isFalse, reason: 'opening Features is not a yes');
    expect(linked(), [
      {'feature': 'muscleMap', 'source': 'whats_new'},
    ]);

    // turned on there, then back — pushed, so back is the note that sent the
    // user here, and it now says the feature is on
    await tester.tap(find.byKey(row));
    await tester.pumpTimes();
    router.config.pop();
    await tester.pumpTimes();

    expect(find.byType(FeaturesPage), findsNothing);
    expect(find.descendant(of: find.byKey(button).first, matching: find.text('On · see in Features')), findsOneWidget);
  });

  testWidgets('a link opens Features at the row, counted as a link', (tester) async {
    await pumpApp(tester);
    router.config.go('/profile/settings/features?feature=muscleMap');
    await tester.pumpTimes(25);

    expect(find.byKey(row), findsOneWidget);
    expect(linked(), [
      {'feature': 'muscleMap', 'source': 'link'},
    ]);
  });

  testWidgets('a feature this build does not know opens the page at the top, uncounted', (tester) async {
    await pumpApp(tester);
    router.config.go('/profile/settings/features?feature=notBuiltYet');
    await tester.pumpTimes(25);

    expect(find.byType(FeaturesPage), findsOneWidget);
    expect(linked(), isEmpty);
  });
}
