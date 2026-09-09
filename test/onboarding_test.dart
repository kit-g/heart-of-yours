// The first-launch carousel across the windows it has to fit: a small phone,
// a large one, and an iPad in both orientations. What is pinned is the "measure
// and cap" contract from CLAUDE.md — the illustration stops growing with the
// window and the copy never runs wider than a comfortable line — plus the
// absence of any layout exception, which is how an overflow reports itself.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/onboarding/onboarding.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Logical sizes; the device pixel ratio is pinned to 1 so these are the
/// constraints the page actually measures.
const _windows = <String, Size>{
  'a small phone': Size(375, 667),
  'a large phone': Size(430, 932),
  'an iPad, portrait': Size(834, 1194),
  'an iPad, landscape': Size(1194, 834),
};

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
    // a device that has never launched the app
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(signedIn: false),
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byType(OnboardingPage), findsOneWidget);
  }

  for (final MapEntry(key: name, value: size) in _windows.entries) {
    testWidgets('on $name the illustration and the copy are capped', (tester) async {
      await pumpAt(tester, size);

      // the illustration measures its page and stops at the cap
      final illustration = tester.getSize(find.byKey(AppKeys.onboardingIllustration));
      expect(illustration.width, lessThanOrEqualTo(200));
      expect(illustration.width, greaterThanOrEqualTo(96));
      expect(illustration.width, illustration.height);

      // the copy never runs wider than a readable line, whatever the window
      final title = L.of(tester.element(find.byType(OnboardingPage))).onboardingWelcomeTitle;
      final copy = tester.getSize(find.text(title));
      expect(copy.width, lessThanOrEqualTo(readableWidth));

      // and the action is not a full-width bar on a tablet either
      final next = tester.getSize(find.byKey(AppKeys.onboardingNext));
      expect(next.width, lessThanOrEqualTo(readableWidth));
      // a full tap target, unlike the 32pt dialog-footer button it is built on
      expect(next.height, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('every screen lays out on a small phone, on the way to the last', (tester) async {
    await pumpAt(tester, _windows['a small phone']!);

    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);
    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);

    expect(find.byKey(AppKeys.onboardingContinue), findsOneWidget);
    expect(find.byKey(AppKeys.onboardingSignIn), findsOneWidget);
    // an overflow anywhere along the way would have failed the test by itself
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dots and the action hold their place across all three screens', (tester) async {
    await pumpAt(tester, _windows['an iPad, landscape']!);

    // Built only where it is used, the last screen's second button pushed the
    // whole footer up as the reader arrived on it.
    final dots = tester.getRect(find.byKey(AppKeys.onboardingScreenCount));
    final action = tester.getRect(find.byKey(AppKeys.onboardingNext));

    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);
    expect(tester.getRect(find.byKey(AppKeys.onboardingScreenCount)), dots);

    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);
    expect(tester.getRect(find.byKey(AppKeys.onboardingScreenCount)), dots);
    // same slot, same size — only the label and the destination changed
    expect(tester.getRect(find.byKey(AppKeys.onboardingContinue)), action);
  });

  testWidgets('Skip is hidden on the last screen, without moving anything', (tester) async {
    await pumpAt(tester, _windows['a small phone']!);

    final skip = tester.getRect(find.byKey(AppKeys.onboardingSkip));
    expect(find.byKey(AppKeys.onboardingSkip).hitTestable(), findsOneWidget);

    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);
    await tester.tapByKey(AppKeys.onboardingNext);
    await tester.pumpTimes(4);

    // Continue is the same door; the corner keeps its space so the carousel
    // does not grow into it on the way in
    expect(find.byKey(AppKeys.onboardingSkip).hitTestable(), findsNothing);
    expect(tester.getRect(find.byKey(AppKeys.onboardingSkip)), skip);
  });
}
