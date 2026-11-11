import 'package:flutter/foundation.dart';

abstract final class AppKeys {
  const new _();

  static const profileStack = Key('AppFrame.profileStack');
  static const workoutStack = Key('AppFrame.workoutStack');
  static const keepAwakeBadge = Key('AppFrame.keepAwakeBadge');
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

  /// The new-goal dialog's way to a goal on a movement pattern, and on a
  /// muscle (#344).
  static const newGoalByPattern = Key('Goals.new.byPattern');
  static const newGoalByMuscle = Key('Goals.new.byMuscle');

  /// Sets or sessions, on the target form of a pattern or muscle goal.
  static const goalCountedMetric = Key('Goals.target.counted');

  /// Stands in for the add-goal button once the server would refuse another.
  static const goalsAtCapacity = Key('Goals.atCapacity');

  /// Turns the goals card over to the goals already achieved.
  static const goalsViewAchieved = Key('Goals.viewAchieved');

  /// Turns it back to the goals still being worked on.
  static const goalsViewActive = Key('Goals.viewActive');

  /// Stands where the logout button does while the session is anonymous;
  /// opens the no-account dialog.
  static const noAccount = Key('Profile.noAccount');

  /// The muscle map (#136) on the profile: the one offer, its two answers,
  /// the notice a no earns, and the card itself.
  static const recapsOffer = ValueKey('recapsOffer');
  static const recapsAccept = ValueKey('recapsAccept');
  static const recapsDecline = ValueKey('recapsDecline');
  static const recapCard = ValueKey('recapCard');
  static const recapsEntry = ValueKey('recapsEntry');
  static const monthlyReport = ValueKey('monthlyReport');
  static const muscleMapOffer = ValueKey('muscleMapOffer');
  static const muscleMapAccept = ValueKey('muscleMapAccept');
  static const muscleMapDecline = ValueKey('muscleMapDecline');
  static const featureDeclinedNotice = ValueKey('featureDeclinedNotice');
  static const rpeImportOffer = ValueKey('rpeImportOffer');
  static const rpeImportAccept = ValueKey('rpeImportAccept');
  static const rpeImportDecline = ValueKey('rpeImportDecline');
  static const muscleMapCard = ValueKey('muscleMapCard');

  /// Copy for AI (#259): its offer and answers, the ways in, and its sheet.
  static const copyForAiOffer = ValueKey('copyForAiOffer');
  static const copyForAiAccept = ValueKey('copyForAiAccept');
  static const copyForAiDecline = ValueKey('copyForAiDecline');
  static const copyForAiHistory = ValueKey('copyForAiHistory');
  static const copyForAiExercise = ValueKey('copyForAiExercise');
  static const copyForAiSheet = ValueKey('copyForAiSheet');
  static const copyForAiPeriod = ValueKey('copyForAiPeriod');
  static const copyForAiPreview = ValueKey('copyForAiPreview');
  static const copyForAiCopy = ValueKey('copyForAiCopy');
  static const copyForAiShare = ValueKey('copyForAiShare');
  static Key copyForAiWorkout(String id) => ValueKey('copyForAiWorkout.$id');

  /// Suspicious entries (#428): the one offer and its answers in History, the
  /// way to the list, a mark beside an entry and the decision it opens.
  static const entryReviewOffer = Key('EntryReview.offer');
  static const entryReviewAccept = Key('EntryReview.accept');
  static const entryReviewDecline = Key('EntryReview.decline');
  static const entryReviewButton = Key('EntryReview.button');
  static const entryReviewPage = Key('EntryReview.page');
  static Key anomalyMark(String id) => Key('EntryReview.mark.$id');

  /// Past workouts (#530): the way in from History's app bar.
  static const logPastWorkout = Key('History.logPastWorkout');
  static Key anomalyRow(String id) => Key('EntryReview.row.$id');
  static Key anomalyDecision(String decision) => Key('EntryReview.decision.$decision');
  static const muscleMapHeatmap = ValueKey('muscleMapHeatmap');
  static const muscleMapFigureTip = ValueKey('muscleMapFigureTip');
  static const workoutMuscleMap = ValueKey('workoutMuscleMap');
  static const templateMuscles = ValueKey('templateMuscles');
  static const templateMusclesToggle = ValueKey('templateMusclesToggle');
  static const musclesWorkedButton = ValueKey('musclesWorkedButton');
  static const muscleMapCellCaption = ValueKey('muscleMapCellCaption');

  /// The no-account dialog's way to the login page.
  static const noAccountLogIn = Key('Profile.noAccount.logIn');

  /// The settings row that wipes an anonymous session's data off the device;
  /// opens the confirmation.
  static const eraseData = Key('Settings.eraseData');

  /// The confirmation's destructive action.
  static const eraseDataConfirm = Key('Settings.eraseData.confirm');

  /// The settings row that opens the export page; present in both sessions.
  static const exportData = Key('Settings.exportData');

  /// The settings row that opens the release notes.
  static const whatsNew = Key('Settings.whatsNew');

  /// The settings row that opens the rest-timer list; present only while
  /// there is a timer on it.
  static const restTimers = Key('Settings.restTimers');
  static const features = Key('Settings.features');

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

  /// The credential form's fields, shared by logging in and signing up.
  ///
  /// Keyed because nothing else on them can be aimed at: the value lives in an
  /// `EditableText`, which `find.text` does not match, and the hint — the one
  /// thing it does match — sits in the decoration layer, where a tap cannot
  /// land. Without these the sign-up flow is undrivable, which is what kept
  /// the export page (account-only) out of reach of a driver run.
  static const loginEmail = Key('Login.email');
  static const loginName = Key('Login.name');
  static const loginPassword = Key('Login.password');

  /// The developer API (#271): the Settings row, the tokens page's controls
  /// and each token's row and revoke button.
  static const developerApi = Key('Settings.developerApi');
  static const apiTokensDocs = Key('ApiTokens.docs');
  static const newApiToken = Key('ApiTokens.new');
  static const retryApiTokens = Key('ApiTokens.retry');
  static Key apiTokenRow(String id) => Key('ApiTokens.row.$id');
  static Key revokeApiToken(String id) => Key('ApiTokens.revoke.$id');
  static const confirmRevokeApiToken = Key('ApiTokens.revoke.confirm');
  static const apiTokenName = Key('NewApiToken.name');
  static Key apiTokenPurposeOption(Object? purpose) => Key('NewApiToken.purpose.${purpose ?? 'unset'}');
  static const createApiToken = Key('NewApiToken.create');
  static const apiTokenSecret = Key('NewApiToken.secret');
  static const copyApiToken = Key('NewApiToken.copy');
  static const apiTokenStored = Key('NewApiToken.stored');

  /// Account control's sign-ins (#323): one row per provider, by its id, and
  /// the button on it.
  static Key signInRow(String provider) => Key('SignIns.row.$provider');
  static Key connectSignIn(String provider) => Key('SignIns.connect.$provider');
  static Key disconnectSignIn(String provider) => Key('SignIns.disconnect.$provider');

  /// The Programs offer on the Workout tab (#345), and its two answers.

  /// "From a folder" on the Workout tab's Programs header (#348).
  static const programsFromFolder = Key('Programs.fromFolder');
  static const programFormName = Key('Programs.form.name');
  static const programFormNote = Key('Programs.form.note');
  static const programFormSave = Key('Programs.form.save');

  /// One program's band on the Workout tab (#347), and its Start button.
  static Key programBand(String? programId) => Key('Programs.band.$programId');
  static Key programBandStatus(String? programId) => Key('Programs.band.status.$programId');
  static Key partOfProgram(String? programId) => Key('Programs.partOf.$programId');
  static const programInProgress = Key('Programs.inProgress');
  static Key workoutRecords(String workoutId) => Key('History.records.$workoutId');
  static const firstRecords = Key('Done.firstRecords');
  static Key goalSetAside(String? goalId) => Key('Goals.setAside.$goalId');
  static Key lensLine(String label) => Key('Lens.line.$label');
  static Key lensChart(String label) => Key('Lens.chart.$label');
  static const programCalendarSettings = Key('Programs.calendar.settings');
  static const libraryStartDays = Key('Programs.library.startDays');
  static const libraryStartDaysSkip = Key('Programs.library.startDays.skip');
  static const libraryStartDaysStart = Key('Programs.library.startDays.start');
  static const exerciseInProgram = Key('Programs.exerciseIn');
  static Key programStart(String? programId) => Key('Programs.band.start.$programId');

  /// "Not today" (#312), on a program's band or its page.
  static Key programNotToday(String? programId) => Key('Programs.notToday.$programId');

  /// A day set aside with "Not today" (#312), in History.
  static Key historySkip(String? skipId) => Key('History.skip.$skipId');
  static const skipPage = Key('History.skipPage');
  static const skipOpenProgram = Key('History.skipOpenProgram');

  /// "Not today" on the Workout tab (#312), and its Undo once the day is set
  /// aside.
  static const notTodayDay = Key('Workout.notToday');
  static const notTodayUndo = Key('Workout.notToday.undo');

  /// The sheet after a skip (#312): its reason chips, and its Undo.
  static const skipSheet = Key('Skip.sheet');
  static Key skipReason(String reason) => Key('Skip.reason.$reason');
  static const skipUndo = Key('Skip.undo');

  /// A skip's page: what the day looked like (#312).
  static const skipThatDay = Key('Skip.thatDay');

  /// A program in the device calendar (#391): the ask, the row on a program's
  /// page, and its dialog.
  static const programCalendarRow = Key('Programs.calendar.row');
  static const programCalendarAllDay = Key('Programs.calendar.allDay');
  static const programCalendarSave = Key('Programs.calendar.save');
  static const programCalendarRemove = Key('Programs.calendar.remove');
  static Key programCalendarChoice(String id) => Key('Programs.calendar.choice.$id');

  /// The Done page's program block (#351): what the session moved.
  static const doneProgram = Key('Done.program');

  /// Heart's ready-made programs (#352): the row on the Workout tab that opens
  /// them, the library's filter and cards, and a program's page.
  static const libraryEntry = Key('Programs.library');
  static const libraryEquipment = Key('Programs.library.equipment');
  static Key libraryProgram(String key) => Key('Programs.library.program.$key');
  static Key libraryHistory(String key) => Key('Programs.library.history.$key');
  static Key libraryNext(String key) => Key('Programs.library.next.$key');
  static const libraryFacts = Key('Programs.library.facts');
  static Key librarySession(String id) => Key('Programs.library.session.$id');
  static Key librarySource(String key) => Key('Programs.library.source.$key');
  static const libraryStart = Key('Programs.library.start');
  static const libraryOpenYours = Key('Programs.library.openYours');
  static const libraryNoRoom = Key('Programs.library.noRoom');
  static const programAbout = Key('Programs.about');

  /// A session joining a running program (#489), and leaving it.
  static const programAddSession = Key('Programs.addSession');
  static Key programSessionCandidate(String templateId) => Key('Programs.addSession.$templateId');
  static const programRemoveSession = Key('Programs.removeSession');
  static Key templateMenu(String templateId) => Key('Templates.menu.$templateId');

  /// A program's goals on its page (#353): what it implies, and what it grows.
  static const programGoals = Key('Programs.goals');
  static Key programGoalKeep(String? goalId) => Key('Programs.goals.keep.$goalId');
  static const programAgain = Key('Programs.again');
  static const goEasyRow = Key('Programs.goEasy');
  static Key goEasy(String key) => Key('Programs.goEasy.$key');
  static const goEasySessionMark = Key('Programs.goEasy.session');

  /// A program's constraint (#355): its row on the program page, and each
  /// choice in its sheet, `none` for nothing in particular.
  static const programConstraint = Key('Programs.constraint');
  static Key programConstraintChoice(String? key) => Key('Programs.constraint.${key ?? 'none'}');

  /// The profile's weekly sets card (#341) and its fold.
  static const lensCard = ValueKey('lensCard');
  static const lensShowAll = ValueKey('lensShowAll');

  /// The new-exercise dialog's movement pattern (#343), and each of its menu's
  /// choices.
  static const newExercisePattern = Key('NewExercise.pattern');
  static Key newExercisePatternOption(String? pattern) => Key('NewExercise.pattern.${pattern ?? 'none'}');
  static const musclePickerRole = Key('MusclePicker.role');
  static const musclePickerFigures = Key('MusclePicker.figures');

  /// The picker's offer to create an exercise named after a search that
  /// found nothing (#529).
  static const pickerCreateExercise = Key('ExercisePicker.createExercise');

  /// The Coaching space (#566): the way in on Profile, the way back out, its
  /// tabs, and the line that leads back to a workout still going.
  static const coachingButton = Key('Profile.coaching');
  static const coachingYourTraining = Key('Coaching.yourTraining');
  static const coachingClientsStack = Key('Coaching.clientsStack');
  static const coachingMessagesStack = Key('Coaching.messagesStack');
  static const coachingProgramsStack = Key('Coaching.programsStack');
  static const coachingMeStack = Key('Coaching.meStack');
  static const coachingBackToWorkout = Key('Coaching.backToWorkout');

  /// Inviting someone to be coached (#553): the action, the empty state's
  /// button, the name, the button that makes the link, and each invitation.
  static const coachingInviteAction = Key('Coaching.inviteAction');
  static const coachingInvite = Key('Coaching.invite');
  static const coachingInviteName = Key('Coaching.inviteName');
  static const coachingMakeLink = Key('Coaching.makeLink');

  static Key coachingInvitation(String id) => Key('Coaching.invitation.$id');

  /// The roster (#559): Clients or Activity, a reason to filter by, each
  /// client's row and its "looked at", and the former ones.
  static const coachingRosterView = Key('Coaching.rosterView');
  static const coachingActivityView = Key('Coaching.activityView');
  static const coachingFormerClients = Key('Coaching.formerClients');

  static Key coachingReasonFilter(String? reason) => Key('Coaching.reason.${reason ?? 'all'}');

  static Key coachingClient(String connectionId) => Key('Coaching.client.$connectionId');

  static Key coachingMarkReviewed(String connectionId) => Key('Coaching.reviewed.$connectionId');

  /// A coach's library (#557): a new program, each program and session, and
  /// what a program's page does.
  static const coachingNewProgram = Key('Coaching.newProgram');
  static const coachingNewProgramEmpty = Key('Coaching.newProgram.empty');
  static const coachingAddSession = Key('Coaching.addSession');
  static const coachingSendProgram = Key('Coaching.sendProgram');
  static const coachingSendConfirm = Key('Coaching.sendProgram.confirm');
  static const coachingProgramMenu = Key('Coaching.programMenu');
  static const coachingDeleteProgram = Key('Coaching.deleteProgram');
  static const coachingDeleteConfirm = Key('Coaching.deleteProgram.confirm');
  static const coachingUnsavedRetry = Key('Coaching.unsaved.retry');

  static Key coachingLibraryProgram(String id) => Key('Coaching.library.$id');

  static Key coachingLibrarySession(String id) => Key('Coaching.library.session.$id');

  static Key coachingRemoveSession(String id) => Key('Coaching.library.removeSession.$id');

  static Key coachingSendTo(String connectionId) => Key('Coaching.sendTo.$connectionId');

  static Key coachingHolder(String connectionId) => Key('Coaching.holder.$connectionId');

  /// The page an invitation link opens (#553), and its answers.
  static const invitationPage = Key('Invitation.page');
  static const invitationShareHistory = Key('Invitation.shareHistory');
  static const invitationShareGoals = Key('Invitation.shareGoals');
  static const invitationAccept = Key('Invitation.accept');
  static const invitationDecline = Key('Invitation.decline');
  static const invitationBlock = Key('Invitation.block');
  static const invitationMakeAccount = Key('Invitation.makeAccount');

  /// Your coach in Settings (#553): each coach, leaving one, and lifting a block.
  static Key yourCoach(String id) => Key('YourCoach.$id');
  static const yourCoachLeaveConfirm = Key('YourCoach.leaveConfirm');

  static Key yourCoachUnblock(String userId) => Key('YourCoach.unblock.$userId');
  static const invitationRetry = Key('Invitation.retry');
}
