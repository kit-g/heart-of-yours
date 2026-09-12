import 'package:flutter/foundation.dart';

abstract final class AppKeys {
  const new _();

  static const profileStack = Key('AppFrame.profileStack');
  static const workoutStack = Key('AppFrame.workoutStack');
  static const historyStack = Key('AppFrame.historyStack');
  static const exercisesStack = Key('AppFrame.exercisesStack');
  static const exercisePicker = Key('AppFrame.exercisePicker');

  /// The navigation rail, present only in the wide layout. Its absence is how a
  /// test tells it is looking at the compact frame.
  static const navigationRail = Key('AppFrame.navigationRail');

  /// Placeholder holding a two-pane detail open before anything is selected.
  /// Asserting on it distinguishes "nothing selected" from "no detail pane".
  static const noSelection = Key('AppFrame.noSelection');

  /// Dismisses a two-pane detail. Distinct from a back button: it clears the
  /// selection rather than popping a route.
  static const closeDetail = Key('AppFrame.closeDetail');

  /// One goal's row on the goals card. Keyed per goal because the card shows
  /// several and they are otherwise indistinguishable to a finder.
  static Key goalRow(String? goalId) => Key('Goals.row.$goalId');

  /// Dismisses the goal detail surface.
  static const closeGoalDetail = Key('Goals.detail.close');

  /// Appends a rung to a goal's ladder.
  static const addRung = Key('Goals.ladder.add');

  /// Sets or changes a rung's deadline.
  static const rungDueDate = Key('Goals.rung.dueDate');

  /// One rung of a goal's ladder. Keyed per rung so a finder can tell them
  /// apart — swiping one away is how a rung is removed.
  static Key ladderRung(String? stageId) => Key('Goals.ladder.rung.$stageId');

  /// Stands in for the add-goal button once the server would refuse another.
  static const goalsAtCapacity = Key('Goals.atCapacity');

  /// Turns the goals card over to the goals already achieved.
  static const goalsViewAchieved = Key('Goals.viewAchieved');

  /// Turns it back to the goals still being worked on.
  static const goalsViewActive = Key('Goals.viewActive');

  /// Stands where the logout button does while the session is anonymous;
  /// opens the no-account dialog.
  static const noAccount = Key('Profile.noAccount');

  /// The no-account dialog's way to the login page.
  static const noAccountLogIn = Key('Profile.noAccount.logIn');

  /// The settings row that wipes an anonymous session's data off the device;
  /// opens the confirmation.
  static const eraseData = Key('Settings.eraseData');

  /// The confirmation's destructive action.
  static const eraseDataConfirm = Key('Settings.eraseData.confirm');

  /// The settings row that opens the export page; present in both sessions.
  static const exportData = Key('Settings.exportData');

  /// The export page's two actions, one per format.
  static const exportJson = Key('Export.json');
  static const exportCsv = Key('Export.csv');

  /// The profile row that shows the replay of an anonymous session's store
  /// into its new account — present only while there is something to say.
  static const upsyncRow = Key('Profile.upsync');

  /// The row's way to try again after the server could not be reached.
  static const upsyncRetry = Key('Profile.upsync.retry');

  /// Puts the finished row's line away.
  static const upsyncDismiss = Key('Profile.upsync.dismiss');

  /// The profile row that shows the history backfill — the pull counterpart
  /// of the upsync row, present only while it is paging or has stopped short.
  static const backfillRow = Key('Profile.backfill');

  /// The row's way to try again after the server could not be reached.
  static const backfillRetry = Key('Profile.backfill.retry');

  /// The first-launch onboarding's way out, on every screen but the last —
  /// where Continue is the same door, so it stands down.
  static const onboardingSkip = Key('Onboarding.skip');

  /// Advances the onboarding by one screen.
  static const onboardingNext = Key('Onboarding.next');

  /// The last onboarding screen's way into the app.
  static const onboardingContinue = Key('Onboarding.continue');

  /// The last onboarding screen's way to the login page.
  static const onboardingSignIn = Key('Onboarding.signIn');

  /// The onboarding's illustration, one per screen: what a window-size test
  /// measures to prove the cap holds.
  static const onboardingIllustration = Key('Onboarding.illustration');

  /// The onboarding's page dots: what a test measures to prove the footer
  /// stops resizing under them on the last screen.
  static const onboardingScreenCount = Key('Onboarding.screenCount');
}
