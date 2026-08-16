// Accessibility guideline sweep. See docs/a11y.md for how to read and extend
// this matrix.
//
// Each entry pumps a real screen through the app harness and checks one of
// Flutter's built-in accessibility guidelines against it. Entries that pass
// are enabled; entries that don't yet are skipped with a reason so the debt
// stays enumerable instead of silently missing. Do not delete a failing
// entry — flip its `skip` to null once the underlying issue is fixed.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// LoginPage's Apple button probes availability via this channel, unawaited,
/// as a plugin side effect of the widget tree — not an app-code call this
/// suite drives directly. Unmocked, the eventual MissingPluginException
/// surfaces as an unhandled error attributed to whichever test happens to be
/// running when the platform channel gets around to rejecting it.
const _signInWithAppleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

/// A screen the matrix sweeps. Each maps to a path through the real app —
/// see [_pumpTo] — rather than a page pumped in isolation, so the check sees
/// the same chrome (app bar, nav) the guideline actually has to pass on.
enum _Screen { login, profile, workout, history, exercises, settings }

/// One guideline check. [textContrastLight] and [textContrastDark] both run
/// [textContrastGuideline] against the *same* const — the color scheme is
/// seed-derived at runtime (`app.dart:227`), so light and dark are only
/// distinguishable by which one the test switches to before asserting.
enum _Guideline { labeledTapTarget, textContrastLight, textContrastDark, androidTapTarget, iosTapTarget }

extension on _Guideline {
  AccessibilityGuideline get rule => switch (this) {
    _Guideline.labeledTapTarget => labeledTapTargetGuideline,
    _Guideline.textContrastLight || _Guideline.textContrastDark => textContrastGuideline,
    _Guideline.androidTapTarget => androidTapTargetGuideline,
    _Guideline.iosTapTarget => iOSTapTargetGuideline,
  };

  bool get isDark => this == _Guideline.textContrastDark;
}

/// The screen × guideline matrix. `skip` carries a reason (file:line and the
/// constraint that blocks a fix) rather than `true`/`false`, so `flutter
/// test`'s output says *why* a combination is still debt.
final _matrix = <(_Screen, _Guideline, String?)>[
  // Login: untouched by this ticket's remediation pass — every control
  // already carries a visible text label, so the guidelines it can pass,
  // pass without changes.
  (_Screen.login, _Guideline.labeledTapTarget, null),
  (_Screen.login, _Guideline.textContrastLight, null),
  (_Screen.login, _Guideline.textContrastDark, null),
  (
    _Screen.login,
    _Guideline.androidTapTarget,
    'Google/Apple sign-in buttons are sized by the platform SDK widgets, below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.login,
    _Guideline.iosTapTarget,
    'Google/Apple sign-in buttons are sized by the platform SDK widgets, below 44x44 — visual-density change, out of scope',
  ),

  (_Screen.profile, _Guideline.labeledTapTarget, null),
  (_Screen.profile, _Guideline.textContrastLight, null),
  (
    _Screen.profile,
    _Guideline.textContrastDark,
    'nav-bar outline labels and outlineVariant.withValues(alpha: .5) fills read under 4.5:1 in dark — theme contrast fix, out of scope',
  ),
  (
    _Screen.profile,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.profile,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),

  (_Screen.workout, _Guideline.labeledTapTarget, null),
  (_Screen.workout, _Guideline.textContrastLight, null),
  (
    _Screen.workout,
    _Guideline.textContrastDark,
    'nav-bar outline labels and outlineVariant.withValues(alpha: .5) fills read under 4.5:1 in dark — theme contrast fix, out of scope',
  ),
  (
    _Screen.workout,
    _Guideline.androidTapTarget,
    'bottom nav bar items and the set-row weight/reps buttons are below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.workout,
    _Guideline.iosTapTarget,
    'bottom nav bar items and the set-row weight/reps buttons are below 44x44 — visual-density change, out of scope',
  ),

  (_Screen.history, _Guideline.labeledTapTarget, null),
  (_Screen.history, _Guideline.textContrastLight, null),
  (
    _Screen.history,
    _Guideline.textContrastDark,
    'nav-bar outline labels and outlineVariant.withValues(alpha: .5) fills read under 4.5:1 in dark — theme contrast fix, out of scope',
  ),
  (
    _Screen.history,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.history,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),

  (_Screen.exercises, _Guideline.labeledTapTarget, null),
  (_Screen.exercises, _Guideline.textContrastLight, null),
  (
    _Screen.exercises,
    _Guideline.textContrastDark,
    'nav-bar outline labels and outlineVariant.withValues(alpha: .5) fills read under 4.5:1 in dark — theme contrast fix, out of scope',
  ),
  (
    _Screen.exercises,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.exercises,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),

  (
    _Screen.settings,
    _Guideline.labeledTapTarget,
    'settings/page.dart:106 reads Preferences.weightUnit with no isInitialized guard (unlike goals/row.dart) and '
        "crashes before the app's own startup sequence finishes initializing it under this harness's mocked "
        'Auth/Cdn — needs harness work to drive that sequence to completion, out of scope for this pass',
  ),
  (
    _Screen.settings,
    _Guideline.textContrastLight,
    'settings/page.dart:106 reads Preferences.weightUnit with no isInitialized guard (unlike goals/row.dart) and '
        "crashes before the app's own startup sequence finishes initializing it under this harness's mocked "
        'Auth/Cdn — needs harness work to drive that sequence to completion, out of scope for this pass',
  ),
  (
    _Screen.settings,
    _Guideline.textContrastDark,
    'disabled-token text and outlineVariant.withValues(alpha: .5) fills read under 4.5:1 in dark — theme contrast fix, out of scope',
  ),
  (
    _Screen.settings,
    _Guideline.androidTapTarget,
    'the custom-theme-color IconButton and switch rows are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.settings,
    _Guideline.iosTapTarget,
    'the custom-theme-color IconButton and switch rows are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
];

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _signInWithAppleChannel,
      (call) async => call.method == 'isAvailable' ? false : null,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _signInWithAppleChannel,
        null,
      ),
    );

    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    // Same baseline stubs as router_test.dart: enough for every bottom-nav
    // stack (and the dashboard's after-first-layout Stats.init) to render
    // without throwing on an unstubbed call.
    when(
      db.getWorkoutSummary(
        weeksBack: anyNamed('weeksBack'),
        userId: anyNamed('userId'),
      ),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);

    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);

    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));

    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer(
      (_) async => ProgressGalleryResponse.fromJson({}),
    );
  });

  /// Pumps the real [HeartApp] and drives it to [screen] — the same paths
  /// `router_test.dart` exercises rather than pumping a page in isolation, so
  /// what's checked is what a screen reader user actually reaches.
  Future<void> pumpTo(WidgetTester tester, _Screen screen) async {
    // The default 800x600 test surface renders 'Heart of yours' + the motto
    // wider than on a real device (no custom font loaded in the test
    // environment, so a fallback font's metrics apply) and overflows
    // LogoStripe. A larger, phone-plausible surface sidesteps that without
    // touching production layout.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final signedIn = screen != _Screen.login;
    final firebase = signedIn
        ? MockFirebaseAuth(
            mockUser: MockUser(uid: 'u1', email: 'u1@test'),
            signedIn: true,
          )
        : MockFirebaseAuth(signedIn: false);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      hasLocalNotifications: false,
      // the dashboard animates indefinitely — settle would hang on it
      settle: false,
    );
    await tester.pumpTimes();

    switch (screen) {
      case _Screen.login:
      case _Screen.profile:
        break;
      case _Screen.workout:
        await tester.tapByKey(AppKeys.workoutStack);
      case _Screen.history:
        await tester.tapByKey(AppKeys.historyStack);
      case _Screen.exercises:
        await tester.tapByKey(AppKeys.exercisesStack);
      case _Screen.settings:
        await tester.tap(find.byIcon(Icons.settings_rounded));
    }
    await tester.pumpTimes();
  }

  for (final (screen, guideline, reason) in _matrix) {
    final description = switch (reason) {
      String r => '${screen.name} meets ${guideline.name} (skipped: $r)',
      null => '${screen.name} meets ${guideline.name}',
    };
    testWidgets(
      description,
      (tester) async {
        await pumpTo(tester, screen);

        if (guideline.isDark) {
          AppTheme.of(tester.element(find.byType(MaterialApp))).toDark();
          await tester.pumpTimes();
        }

        final handle = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(guideline.rule));
        handle.dispose();
      },
      skip: reason != null,
    );
  }
}
