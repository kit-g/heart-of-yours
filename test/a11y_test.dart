// Accessibility guideline sweep. See docs/a11y.md for how to read and extend
// this matrix.
//
// Each entry pumps a real screen through the app harness and checks one of
// Flutter's built-in accessibility guidelines against it. Entries that pass
// are enabled; entries that don't yet are skipped with a reason so the debt
// stays enumerable instead of silently missing. Do not delete a failing
// entry — flip its `skip` to null once the underlying issue is fixed.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';
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
enum _Screen {
  onboarding,
  login,
  signUp,
  recovery,
  profile,
  muscleMapOffer,
  muscleMap,
  noAccountDialog,
  workout,
  exerciseNoteEditor,
  setTypeMenu,
  rpePicker,
  history,
  calendar,
  exercises,
  settings,
  anonymousSettings,
  accountManagement,
  newExerciseDialog,
  eraseDataDialog,
  importData,
  exportData,
  whatsNew,
  restTimers,
  features,
  upsyncRunning,
  upsyncFailed,
  upsyncDone,
  backfillRunning,
  backfillFailed,
  workoutDone,
}

/// The exercise the rest-timers screen resolves one of its timers to.
final _bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

final _squat = Exercise(name: 'Squat', category: .barbell, target: .legs);

/// The session the workout-done screen celebrates.
final _done = Workout(name: 'Records')
  ..add(_bench)
  ..add(_squat);

/// A finished workout the server has not confirmed — what the upsync replays.
Workout _unsynced() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final workout = Workout(name: 'Monday');
  workout.add(bench).add(ExerciseSet(bench, weight: 60, reps: 5)..isCompleted = true);
  workout.finish(DateTime.timestamp());
  return workout;
}

/// One guideline check. [textContrastLight] and [textContrastDark] both run
/// [textContrastGuideline]; which token set it sees is the preset and mode
/// the test switches to before asserting — contrast entries sweep every
/// [Preset], since each preset carries its own hand-tuned values.
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
  // The first-launch carousel (lib/presentation/routes/onboarding/page.dart),
  // on its last screen: Skip, the page dots and both ways out.
  (_Screen.onboarding, _Guideline.labeledTapTarget, null),
  (_Screen.onboarding, _Guideline.textContrastLight, null),
  (_Screen.onboarding, _Guideline.textContrastDark, null),
  (_Screen.onboarding, _Guideline.androidTapTarget, null),
  (_Screen.onboarding, _Guideline.iosTapTarget, null),

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

  // Sign-up (lib/presentation/routes/login/sign_up.dart), reached from
  // login's own "Sign up" link — plain text fields and buttons, no
  // platform-SDK widgets.
  (_Screen.signUp, _Guideline.labeledTapTarget, null),
  (_Screen.signUp, _Guideline.textContrastLight, null),
  (_Screen.signUp, _Guideline.textContrastDark, null),
  (
    _Screen.signUp,
    _Guideline.androidTapTarget,
    'the "Log in" link is sized to its text (117.5x42), below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.signUp,
    _Guideline.iosTapTarget,
    'the "Log in" link is sized to its text (117.5x42), below 44x44 — visual-density change, out of scope',
  ),

  // Password recovery (lib/presentation/routes/login/recovery.dart), reached
  // from login's "Forgot password?" link.
  (_Screen.recovery, _Guideline.labeledTapTarget, null),
  (_Screen.recovery, _Guideline.textContrastLight, null),
  (_Screen.recovery, _Guideline.textContrastDark, null),
  (_Screen.recovery, _Guideline.androidTapTarget, null),
  (_Screen.recovery, _Guideline.iosTapTarget, null),

  (_Screen.profile, _Guideline.labeledTapTarget, null),
  (_Screen.profile, _Guideline.textContrastLight, null),
  (_Screen.profile, _Guideline.textContrastDark, null),
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

  // The muscle map (#136) on the profile: the one-time offer, and the card
  // once it is on (lib/presentation/routes/profile/muscle_map.dart). Same
  // page, so the same bottom nav stands behind both tap-target skips.
  (_Screen.muscleMapOffer, _Guideline.labeledTapTarget, null),
  (_Screen.muscleMapOffer, _Guideline.textContrastLight, null),
  (_Screen.muscleMapOffer, _Guideline.textContrastDark, null),
  (
    _Screen.muscleMapOffer,
    _Guideline.androidTapTarget,
    'bottom nav bar items, and the offer\'s two buttons at the house 32pt (primaryButtonMinHeight, lib/presentation/widgets/buttons.dart), are below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.muscleMapOffer,
    _Guideline.iosTapTarget,
    'bottom nav bar items, and the offer\'s two buttons at the house 32pt (primaryButtonMinHeight, lib/presentation/widgets/buttons.dart), are below 44x44 — visual-density change, out of scope',
  ),
  (_Screen.muscleMap, _Guideline.labeledTapTarget, null),
  (_Screen.muscleMap, _Guideline.textContrastLight, null),
  (_Screen.muscleMap, _Guideline.textContrastDark, null),
  (
    _Screen.muscleMap,
    _Guideline.androidTapTarget,
    'bottom nav bar items, and the card\'s 7/30-day SettingSwitcher (lib/presentation/widgets/setting_picker.dart, 28pt as in Settings), are below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.muscleMap,
    _Guideline.iosTapTarget,
    'bottom nav bar items, and the card\'s 7/30-day SettingSwitcher (lib/presentation/widgets/setting_picker.dart, 28pt as in Settings), are below 44x44 — visual-density change, out of scope',
  ),

  // The no-account dialog over the profile of an anonymous session
  // (lib/presentation/routes/profile/page.dart, _showNoAccountDialog).
  (_Screen.noAccountDialog, _Guideline.labeledTapTarget, null),
  (_Screen.noAccountDialog, _Guideline.textContrastLight, null),
  (_Screen.noAccountDialog, _Guideline.textContrastDark, null),
  (
    _Screen.noAccountDialog,
    _Guideline.androidTapTarget,
    'the two PrimaryButton.wide actions are 32pt tall by design (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight) — visual-density change, out of scope',
  ),
  (
    _Screen.noAccountDialog,
    _Guideline.iosTapTarget,
    'the two PrimaryButton.wide actions are 32pt tall by design (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight) — visual-density change, out of scope',
  ),

  (_Screen.workout, _Guideline.labeledTapTarget, null),
  (_Screen.exerciseNoteEditor, _Guideline.labeledTapTarget, null),
  (_Screen.exerciseNoteEditor, _Guideline.textContrastLight, null),
  (_Screen.exerciseNoteEditor, _Guideline.textContrastDark, null),
  (
    _Screen.exerciseNoteEditor,
    _Guideline.androidTapTarget,
    'dialog actions use the shared 32pt button height (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight), below 48pt',
  ),
  (
    _Screen.exerciseNoteEditor,
    _Guideline.iosTapTarget,
    'dialog actions use the shared 32pt button height (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight), below 44pt',
  ),
  // The set type menu over a workout whose first set is a warm-up, with one
  // type's explanation open (lib/presentation/widgets/workout/set_type.dart).
  (
    _Screen.setTypeMenu,
    _Guideline.labeledTapTarget,
    'the workout options button (lib/presentation/widgets/workout/workout_detail.dart:907) and each set\'s ✓ (lib/presentation/widgets/workout/set_item.dart:298) are icon-only with no label; the menu itself passes',
  ),
  (
    _Screen.setTypeMenu,
    _Guideline.textContrastLight,
    'ember\'s "Add exercises" button under the exercise reads 2.6:1 (lib/presentation/widgets/workout/workout_detail.dart); every other preset passes',
  ),
  (_Screen.setTypeMenu, _Guideline.textContrastDark, null),
  // The RPE picker in the keyboard's place, its scale unfolded, the first set
  // rated (lib/presentation/widgets/workout/rpe.dart).
  (
    _Screen.rpePicker,
    _Guideline.labeledTapTarget,
    'the workout options button (lib/presentation/widgets/workout/workout_detail.dart:907) and each set\'s ✓ (lib/presentation/widgets/workout/set_item.dart:298) are icon-only with no label; the picker itself passes',
  ),
  (_Screen.rpePicker, _Guideline.textContrastLight, null),
  (_Screen.rpePicker, _Guideline.textContrastDark, null),
  (
    _Screen.rpePicker,
    _Guideline.androidTapTarget,
    'the workout behind the picker keeps its 32pt rows (lib/presentation/widgets/workout/set_item.dart) — visual-density change, out of scope; the picker\'s ratings are 48 tall',
  ),
  (
    _Screen.rpePicker,
    _Guideline.iosTapTarget,
    'the workout behind the picker keeps its 32pt rows (lib/presentation/widgets/workout/set_item.dart) — visual-density change, out of scope; the picker\'s ratings are 48 tall',
  ),
  (
    _Screen.setTypeMenu,
    _Guideline.androidTapTarget,
    'the set number and the set-row buttons share the 32pt row height (lib/presentation/widgets/workout/set_item.dart), and the menu\'s help buttons are compact (set_type.dart) — visual-density change, out of scope',
  ),
  (
    _Screen.setTypeMenu,
    _Guideline.iosTapTarget,
    'the set number and the set-row buttons share the 32pt row height (lib/presentation/widgets/workout/set_item.dart), and the menu\'s help buttons are compact (set_type.dart) — visual-density change, out of scope',
  ),
  (_Screen.workout, _Guideline.textContrastLight, null),
  (_Screen.workout, _Guideline.textContrastDark, null),
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

  (_Screen.calendar, _Guideline.labeledTapTarget, null),
  (_Screen.calendar, _Guideline.textContrastLight, null),
  (_Screen.calendar, _Guideline.textContrastDark, null),
  (_Screen.calendar, _Guideline.androidTapTarget, null),
  (_Screen.calendar, _Guideline.iosTapTarget, null),

  (_Screen.history, _Guideline.labeledTapTarget, null),
  (_Screen.history, _Guideline.textContrastLight, null),
  (_Screen.history, _Guideline.textContrastDark, null),
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
  (_Screen.exercises, _Guideline.textContrastDark, null),
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

  // the unit pickers now hold back until Preferences.isInitialized (the
  // goals/row.dart pattern), so the screen renders under this harness
  (_Screen.settings, _Guideline.labeledTapTarget, null),
  (_Screen.settings, _Guideline.textContrastLight, null),
  (_Screen.settings, _Guideline.textContrastDark, null),
  (
    _Screen.settings,
    _Guideline.androidTapTarget,
    'switch rows are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.settings,
    _Guideline.iosTapTarget,
    'switch rows are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),

  // The settings of an anonymous session: the same page, with the "Erase my
  // data" row (lib/presentation/routes/settings/page.dart) where the account
  // rows would be.
  (_Screen.anonymousSettings, _Guideline.labeledTapTarget, null),
  (_Screen.anonymousSettings, _Guideline.textContrastLight, null),
  (_Screen.anonymousSettings, _Guideline.textContrastDark, null),
  (
    _Screen.anonymousSettings,
    _Guideline.androidTapTarget,
    'switch rows are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.anonymousSettings,
    _Guideline.iosTapTarget,
    'switch rows are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),

  // Account management (lib/presentation/routes/settings/account.dart),
  // reached from Settings' "Account control" row for a signed-in,
  // non-anonymous user.
  (_Screen.accountManagement, _Guideline.labeledTapTarget, null),
  (_Screen.accountManagement, _Guideline.textContrastLight, null),
  (_Screen.accountManagement, _Guideline.textContrastDark, null),
  (
    _Screen.accountManagement,
    _Guideline.androidTapTarget,
    'the Name/email fields are inline text fields sized to their text (24pt tall), below 48x48 — visual-density change, out of scope',
  ),
  (
    _Screen.accountManagement,
    _Guideline.iosTapTarget,
    'the Name/email fields are inline text fields sized to their text (24pt tall), below 44x44 — visual-density change, out of scope',
  ),

  // The new-exercise dialog (lib/presentation/widgets/exercises/new_exercise_dialog.dart),
  // reached from the Exercises tab's options menu.
  (_Screen.newExerciseDialog, _Guideline.labeledTapTarget, null),
  (_Screen.newExerciseDialog, _Guideline.textContrastLight, null),
  (_Screen.newExerciseDialog, _Guideline.textContrastDark, null),
  (_Screen.newExerciseDialog, _Guideline.androidTapTarget, null),
  (_Screen.newExerciseDialog, _Guideline.iosTapTarget, null),

  // The erase-my-data confirmation over those settings
  // (lib/presentation/routes/settings/page.dart, _onEraseData).
  (_Screen.eraseDataDialog, _Guideline.labeledTapTarget, null),
  (_Screen.eraseDataDialog, _Guideline.textContrastLight, null),
  (_Screen.eraseDataDialog, _Guideline.textContrastDark, null),
  (
    _Screen.eraseDataDialog,
    _Guideline.androidTapTarget,
    'the two PrimaryButton.wide actions are 32pt tall by design (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight) — visual-density change, out of scope',
  ),
  (
    _Screen.eraseDataDialog,
    _Guideline.iosTapTarget,
    'the two PrimaryButton.wide actions are 32pt tall by design (lib/presentation/widgets/buttons.dart:98 primaryButtonMinHeight) — visual-density change, out of scope',
  ),

  (_Screen.importData, _Guideline.labeledTapTarget, null),
  (_Screen.importData, _Guideline.textContrastLight, null),
  (_Screen.importData, _Guideline.textContrastDark, null),
  (_Screen.importData, _Guideline.androidTapTarget, null),
  (_Screen.importData, _Guideline.iosTapTarget, null),

  // The export page (lib/presentation/routes/settings/export_data.dart):
  // prose and two 48pt buttons, like the import page beside it.
  (_Screen.exportData, _Guideline.labeledTapTarget, null),
  (_Screen.exportData, _Guideline.textContrastLight, null),
  (_Screen.exportData, _Guideline.textContrastDark, null),
  (_Screen.exportData, _Guideline.androidTapTarget, null),
  (_Screen.exportData, _Guideline.iosTapTarget, null),

  // What's new (lib/presentation/routes/settings/whats_new.dart): cards of
  // text over the real bundled notes, with nothing to tap but the back button.
  (_Screen.whatsNew, _Guideline.labeledTapTarget, null),
  (_Screen.whatsNew, _Guideline.textContrastLight, null),
  (_Screen.whatsNew, _Guideline.textContrastDark, null),
  (_Screen.whatsNew, _Guideline.androidTapTarget, null),
  (_Screen.whatsNew, _Guideline.iosTapTarget, null),

  // Rest timers (lib/presentation/routes/settings/rest_timers.dart): one row,
  // its thumbnail, duration and clear button.
  (_Screen.restTimers, _Guideline.labeledTapTarget, null),
  (_Screen.restTimers, _Guideline.textContrastLight, null),
  (_Screen.restTimers, _Guideline.textContrastDark, null),
  (_Screen.restTimers, _Guideline.androidTapTarget, null),
  (_Screen.restTimers, _Guideline.iosTapTarget, null),

  // Features (lib/presentation/routes/settings/features.dart, #226): the
  // opt-in switches, the muscle map on so its options unfold under it.
  (_Screen.features, _Guideline.labeledTapTarget, null),
  (_Screen.features, _Guideline.textContrastLight, null),
  (_Screen.features, _Guideline.textContrastDark, null),
  (
    _Screen.features,
    _Guideline.androidTapTarget,
    'a feature\'s option rows are dense, 40pt (lib/presentation/routes/settings/features.dart:121, #213) — the same density call as Settings\' switch rows',
  ),
  (
    _Screen.features,
    _Guideline.iosTapTarget,
    'a feature\'s option rows are dense, 40pt (lib/presentation/routes/settings/features.dart:121, #213) — the same density call as Settings\' switch rows',
  ),

  // The upsync row on the profile (lib/presentation/widgets/upsync_row.dart) in
  // each of its three states: the bar, the Retry button, the dismiss. The tap
  // target rows inherit the profile's bottom-nav reason; the row's own
  // controls are a 32pt PrimaryButton (see noAccountDialog) and a stock
  // IconButton.
  (_Screen.upsyncRunning, _Guideline.labeledTapTarget, null),
  (_Screen.upsyncRunning, _Guideline.textContrastLight, null),
  (_Screen.upsyncRunning, _Guideline.textContrastDark, null),
  (
    _Screen.upsyncRunning,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.upsyncRunning,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (_Screen.upsyncFailed, _Guideline.labeledTapTarget, null),
  (_Screen.upsyncFailed, _Guideline.textContrastLight, null),
  (_Screen.upsyncFailed, _Guideline.textContrastDark, null),
  (
    _Screen.upsyncFailed,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48, and the Retry PrimaryButton is 32pt tall by design (lib/presentation/widgets/buttons.dart:98) — visual-density change, out of scope',
  ),
  (
    _Screen.upsyncFailed,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44, and the Retry PrimaryButton is 32pt tall by design (lib/presentation/widgets/buttons.dart:98) — visual-density change, out of scope',
  ),
  // The backfill row (lib/presentation/widgets/upsync_row.dart, BackfillRow) in
  // its two states — it has no finished line to check. Same reasons as its push
  // counterpart above: the profile's bottom nav, and a 32pt Retry.
  (_Screen.backfillRunning, _Guideline.labeledTapTarget, null),
  (_Screen.backfillRunning, _Guideline.textContrastLight, null),
  (_Screen.backfillRunning, _Guideline.textContrastDark, null),
  (
    _Screen.backfillRunning,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.backfillRunning,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (_Screen.backfillFailed, _Guideline.labeledTapTarget, null),
  (_Screen.backfillFailed, _Guideline.textContrastLight, null),
  (_Screen.backfillFailed, _Guideline.textContrastDark, null),
  (
    _Screen.backfillFailed,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48, and the Retry PrimaryButton is 32pt tall by design (lib/presentation/widgets/buttons.dart:98) — visual-density change, out of scope',
  ),
  (
    _Screen.backfillFailed,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44, and the Retry PrimaryButton is 32pt tall by design (lib/presentation/widgets/buttons.dart:98) — visual-density change, out of scope',
  ),
  (_Screen.upsyncDone, _Guideline.labeledTapTarget, null),
  (_Screen.upsyncDone, _Guideline.textContrastLight, null),
  (_Screen.upsyncDone, _Guideline.textContrastDark, null),
  (
    _Screen.upsyncDone,
    _Guideline.androidTapTarget,
    'bottom nav bar items are below 48x48 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  (
    _Screen.upsyncDone,
    _Guideline.iosTapTarget,
    'bottom nav bar items are below 44x44 (tapTargetSize/VisualDensity) — visual-density change, out of scope',
  ),
  // The workout-done screen (lib/presentation/routes/done/done.dart) with a
  // record badge and the first-records summary both showing.
  (_Screen.workoutDone, _Guideline.labeledTapTarget, null),
  (_Screen.workoutDone, _Guideline.textContrastLight, null),
  (_Screen.workoutDone, _Guideline.textContrastDark, null),
  (_Screen.workoutDone, _Guideline.androidTapTarget, null),
  (_Screen.workoutDone, _Guideline.iosTapTarget, null),
];

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    SharedPreferences.setMockInitialValues(pastOnboarding());

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

    // The history backfill's two reads, answered as "this device is whole" —
    // every screen but the two that are about the row itself re-stubs them.
    when(db.isHistoryBackfilled(any)).thenAnswer((_) async => true);
    when(db.mirrorSummary(any)).thenAnswer((_) async => const AccountSummary(collections: {}));
    when(api.getAccountSummary()).thenAnswer((_) async => const AccountSummary(collections: {}));

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

    // the one screen a device sees only before its first launch is over
    if (screen == _Screen.onboarding) {
      SharedPreferences.setMockInitialValues({});
    }
    // a feature on, so the page shows what unfolds under a switch too
    if (screen == _Screen.features) {
      SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-muscleMap': 'on'});
    }
    if (screen == _Screen.rpePicker) {
      SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-rpe': 'on'});
    }

    // The upsync row shows on the profile of an account whose store is still
    // owed a replay; what the server answers picks the state. The run is
    // started below the way start-up would once the API has its token —
    // `_initApp` runs in `Zone.root`, which this fake-async zone never yields
    // to, so its own restore-and-run never gets that far in a widget test.
    switch (screen) {
      case _Screen.muscleMapOffer || _Screen.muscleMap:
        // history to map, and for the card, a device that has said yes
        when(
          db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
        ).thenAnswer((_) async => WorkoutAggregation.dummy());
        when(db.getMuscleSets(any, any, userId: anyNamed('userId'))).thenAnswer(
          (_) async => [
            (
              start: DateTime.now(),
              muscles: MuscleTagging.fromJson({
                'primary': {
                  'groups': ['chest'],
                },
                'secondary': {
                  'groups': ['arms', 'shoulders'],
                },
              }),
              sets: 12,
            ),
            (start: DateTime.now(), muscles: MuscleTagging.empty(), sets: 3),
          ],
        );
        if (screen == _Screen.muscleMap) {
          SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-muscleMap': 'on'});
        }
      case _Screen.upsyncRunning || _Screen.upsyncFailed || _Screen.upsyncDone:
        when(db.isUpsyncOwed(any)).thenAnswer((_) async => true);
        when(db.getWorkoutHistory(any)).thenAnswer((_) async => [_unsynced()]);
        when(api.replayWorkout(any)).thenAnswer(
          (invocation) => switch (screen) {
            // never answers, so the bar stays up
            _Screen.upsyncRunning => Completer<({Workout row, bool created})>().future,
            _Screen.upsyncFailed => Future.error(const SocketException('offline')),
            _ => Future.value((row: invocation.positionalArguments.single as Workout, created: true)),
          },
        );
      case _Screen.backfillRunning || _Screen.backfillFailed:
        // an unmarked device that the account has more history than: enough to
        // put the row up, with the page either never answering or refusing
        when(db.isHistoryBackfilled(any)).thenAnswer((_) async => false);
        when(db.mirrorSummary(any)).thenAnswer(
          (_) async => const AccountSummary(
            collections: {ExportableCollection.workouts: CollectionSummary(count: 20)},
          ),
        );
        when(api.getAccountSummary()).thenAnswer(
          (_) async => const AccountSummary(
            collections: {ExportableCollection.workouts: CollectionSummary(count: 568)},
          ),
        );
        when(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since'))).thenAnswer(
          (_) => switch (screen) {
            // never answers, so the bar stays up
            _Screen.backfillRunning => Completer<Iterable<Workout>>().future,
            _ => Future.error(const SocketException('offline')),
          },
        );
      case _Screen.restTimers:
        when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [_bench]));
        when(api.getExercises()).thenAnswer((_) async => [_bench]);
        when(db.getExerciseUnits(any)).thenAnswer((_) async => {});
        when(
          db.setRestTimer(
            exerciseName: anyNamed('exerciseName'),
            userId: anyNamed('userId'),
            seconds: anyNamed('seconds'),
          ),
        ).thenAnswer((_) async {});
      case _Screen.workoutDone:
        // one exercise beat an earlier session, one was a first
        when(db.getRecord(any, _bench)).thenAnswer(
          (_) async => {
            'heaviest': {
              'weight': 100.0,
              'reps': 3,
              'workoutId': _done.id,
              'at': '2026-09-30T10:00:00Z',
              'previous': {'weight': 95.0, 'reps': 3, 'workoutId': 'earlier', 'at': '2026-09-01T10:00:00Z'},
            },
          },
        );
        when(db.getRecord(any, _squat)).thenAnswer(
          (_) async => {
            'heaviest': {'weight': 80.0, 'reps': 5, 'workoutId': _done.id, 'at': '2026-09-30T10:00:00Z'},
          },
        );
      default:
        break;
    }

    // No user means an anonymous session, not a gate: the login page is only
    // reachable through the no-account dialog on that session's profile.
    final firebase = switch (screen) {
      _Screen.onboarding ||
      _Screen.login ||
      _Screen.signUp ||
      _Screen.recovery ||
      _Screen.noAccountDialog ||
      _Screen.anonymousSettings ||
      _Screen.newExerciseDialog ||
      _Screen.eraseDataDialog => MockFirebaseAuth(signedIn: false),
      _ => MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
    };

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
      case _Screen.profile:
        break;
      case _Screen.muscleMapOffer:
        await tester.ensureVisible(find.byKey(AppKeys.muscleMapOffer));
      case _Screen.muscleMap:
        await tester.ensureVisible(find.byKey(AppKeys.muscleMapCard));
      case _Screen.upsyncRunning || _Screen.upsyncFailed || _Screen.upsyncDone:
        unawaited(Upsync.of(tester.element(find.byType(MaterialApp))).run('u1'));
      case _Screen.backfillRunning || _Screen.backfillFailed:
        // started the way `_initTrainingData` would, for the same reason the
        // upsync run is started here rather than left to start-up
        unawaited(Backfill.of(tester.element(find.byType(MaterialApp))).run('u1'));
      case _Screen.onboarding:
        // the last screen carries every control the carousel has
        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);
        await tester.tapByKey(AppKeys.onboardingNext);
      case _Screen.noAccountDialog:
        await tester.tapByKey(AppKeys.noAccount);
      case _Screen.login:
        await tester.tapByKey(AppKeys.noAccount);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.noAccountLogIn);
      case _Screen.signUp:
        await tester.tapByKey(AppKeys.noAccount);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.noAccountLogIn);
        await tester.pumpTimes();
        await tester.tap(find.text('Sign up'));
      case _Screen.recovery:
        await tester.tapByKey(AppKeys.noAccount);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.noAccountLogIn);
        await tester.pumpTimes();
        await tester.tap(find.text('Forgot password?'));
      case _Screen.exerciseNoteEditor:
        final exercise = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
        final workout = Workout(name: 'Notes')..add(exercise);
        await Workouts.of(tester.element(find.byType(MaterialApp))).startWorkout(source: .template, template: workout);
        await tester.tapByKey(AppKeys.workoutStack);
        await tester.pumpTimes();
        if (find.byType(WorkoutDetail).evaluate().isEmpty) {
          await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
        }
        await tester.pumpTimes();
        await tester.tap(find.byKey(WorkoutDetailKeys.exerciseOptionsFor(exercise.id)));
        await tester.pumpTimes();
        await tester.tap(find.text('Add note'));
      case _Screen.setTypeMenu:
        final workout = Workout(name: 'Types')..add(_bench);
        workout.first
          ..add(ExerciseSet(_bench))
          ..first.setType = .warmup;
        await Workouts.of(tester.element(find.byType(MaterialApp))).startWorkout(source: .template, template: workout);
        await tester.tapByKey(AppKeys.workoutStack);
        await tester.pumpTimes();
        if (find.byType(WorkoutDetail).evaluate().isEmpty) {
          await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
        }
        await tester.pumpTimes();
        await tester.tapByKey(WorkoutDetailKeys.setTypeFor(_bench.id, 1));
        await tester.pumpTimes();
        await tester.tap(find.byTooltip('About Warm up'));
      case _Screen.rpePicker:
        final workout = Workout(name: 'Rated')..add(_bench);
        workout.first.first.rpe = 8;
        await Workouts.of(tester.element(find.byType(MaterialApp))).startWorkout(source: .template, template: workout);
        await tester.tapByKey(AppKeys.workoutStack);
        await tester.pumpTimes();
        if (find.byType(WorkoutDetail).evaluate().isEmpty) {
          await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
        }
        await tester.pumpTimes();
        await tester.tap(find.byKey(WorkoutDetailKeys.repsFor(_bench.id, 1)));
        await tester.pumpTimes();
        await tester.tapByKey(WorkoutDetailKeys.rpeKey);
        await tester.pumpTimes();
        await tester.tap(find.byTooltip('About RPE'));
      case _Screen.workout:
        await tester.tapByKey(AppKeys.workoutStack);
      case _Screen.workoutDone:
        final context = tester.element(find.byType(MaterialApp));
        await Workouts.of(context).startWorkout(source: .template, template: _done);
        await tester.pumpTimes();
        final id = Workouts.of(context).activeWorkout!.id;
        GoRouter.of(tester.element(find.byType(Navigator).first)).go('/done?workoutId=$id');
        await tester.pumpTimes();
        // the rows are only honest if the badges are what they checked
        expect(find.textContaining(RegExp(r'^was \d')), findsOneWidget);
        expect(find.text('first record'), findsOneWidget);
      case _Screen.calendar:
        final completed = Workout.fromJson(_unsynced().toMap());
        when(db.getWorkoutHistory(any)).thenAnswer((_) async => [completed]);
        when(api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')))
            .thenAnswer((_) async => [completed]);
        await tester.tapByKey(AppKeys.historyStack);
        await tester.pumpTimes();
        await tester.tap(find.tooltip('Calendar'));
      case _Screen.history:
        await tester.tapByKey(AppKeys.historyStack);
      case _Screen.exercises:
        await tester.tapByKey(AppKeys.exercisesStack);
      case _Screen.settings || _Screen.anonymousSettings:
        await tester.tap(find.byIcon(Icons.settings_rounded));
      case _Screen.features:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.ensureVisible(find.byKey(AppKeys.features));
        await tester.tapByKey(AppKeys.features);
      case _Screen.accountManagement:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.tap(find.text('Account control'));
      case _Screen.newExerciseDialog:
        await tester.tapByKey(AppKeys.exercisesStack);
        await tester.pumpTimes();
        await tester.tap(find.byTooltip('Exercise options'));
        await tester.pumpTimes();
        await tester.tap(find.text('New exercise'));
      case _Screen.eraseDataDialog:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.eraseData);
      case _Screen.importData:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.tap(find.byIcon(Icons.upload_file_rounded));
      case _Screen.exportData:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.exportData);
      case _Screen.whatsNew:
        // rootBundle caches each load's future, and one cached under an
        // earlier test's fake clock never delivers to a later test
        rootBundle.clear();
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.scrollUntilVisible(
          find.byKey(AppKeys.whatsNew),
          200,
          scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
        );
        await tester.ensureVisible(find.byKey(AppKeys.whatsNew));
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.whatsNew);
        await tester.pumpTimes();
        // the notes are real asset I/O, which fake time never advances
        final notes = find.descendant(of: find.byType(WhatsNewPage), matching: find.byType(Card));
        for (final _ in Iterable.generate(50)) {
          if (notes.evaluate().isNotEmpty) break;
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
        expect(notes, findsWidgets);
      case _Screen.restTimers:
        final context = tester.element(find.byType(MaterialApp));
        // started here for the reason the upsync run is: `_initApp` never gets
        // this far in a widget test, and the page waits on the catalog. The
        // local read alone initializes it; the sync behind it is not awaited.
        unawaited(Exercises.of(context).init());
        await tester.pumpTimes();
        final timers = Timers.of(context);
        await timers.setRestTimer(_bench.id, 90);
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.scrollUntilVisible(
          find.byKey(AppKeys.restTimers),
          200,
          scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
        );
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.restTimers);
        await tester.pumpTimes();
        expect(find.byType(ListTile), findsOneWidget);
    }
    await tester.pumpTimes();
  }

  for (final (screen, guideline, reason) in _matrix) {
    final description = switch (reason) {
      String r => '${screen.name} meets ${guideline.name} (skipped: $r)',
      null => '${screen.name} meets ${guideline.name}',
    };
    // Contrast is a property of a preset's tokens, so those guidelines sweep
    // every preset; tap targets and labels are geometry and run once.
    final presets = switch (guideline.rule == textContrastGuideline && reason == null) {
      true => Preset.values,
      false => const [Preset.forge],
    };
    for (final preset in presets) {
      final suffix = switch (presets.length > 1) {
        true => ' in ${preset.name}',
        false => '',
      };
      testWidgets(
        '$description$suffix',
        (tester) async {
          await pumpTo(tester, screen);

          final theme = AppTheme.of(tester.element(find.byType(MaterialApp)));
          theme.preset = preset;
          if (guideline.isDark) {
            theme.toDark();
          }
          await tester.pumpTimes();

          final handle = tester.ensureSemantics();
          await expectLater(tester, meetsGuideline(guideline.rule));
          handle.dispose();
        },
        skip: reason != null,
      );
    }
  }
}
