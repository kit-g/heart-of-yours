// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'heart_language.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appearance => 'Appearance';

  @override
  String get units => 'Units';

  @override
  String get motto => 'Every beat counts.';

  @override
  String get toLightMode => 'Light';

  @override
  String get toDarkMode => 'Dark';

  @override
  String get toSystemMode => 'System';

  @override
  String get email => 'Email';

  @override
  String get yourEmail => 'Your email';

  @override
  String get cropAvatar => 'Crop avatar';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get name => 'Name';

  @override
  String get saveName => 'Save name';

  @override
  String get changeName => 'Change name';

  @override
  String get save => 'Save';

  @override
  String get settings => 'Settings';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get password => 'Password';

  @override
  String get logIn => 'Log in';

  @override
  String get logInTitle => 'Welcome Back';

  @override
  String get logInBody => 'You\'ve already started something important. \nLet\'s keep going.';

  @override
  String get signUpTitle => 'Begin with Heart';

  @override
  String get signUpBody => 'Every journey starts with one decision. \nThis one\'s yours.';

  @override
  String get recoverTitle => 'Still with You';

  @override
  String get recoverBody => 'Your journey isn\'t lost. \nJust a moment of pause — we\'ll reset together.';

  @override
  String get logInWithGoogle => 'Log in with Google';

  @override
  String get signUpWithGoogle => 'Sign up with Google';

  @override
  String get logInWithApple => 'Log in with Apple';

  @override
  String get signUpWithApple => 'Sign up with Apple';

  @override
  String get logOut => 'Log out';

  @override
  String get profile => 'Profile';

  @override
  String get workout => 'Workout';

  @override
  String get history => 'History';

  @override
  String get exercises => 'Exercises';

  @override
  String get search => 'Search';

  @override
  String get startNewWorkout => 'Start a new workout';

  @override
  String get cancelCurrentWorkoutTitle => 'Cancel current workout?';

  @override
  String get cancelCurrentWorkoutBody =>
      'You have a workout in progress. Do you want to cancel it and start a new one?';

  @override
  String get startNewWorkoutFromTemplate => 'Start a new workout from this template?';

  @override
  String get startWorkout => 'Start workout';

  @override
  String get cancelWorkout => 'Cancel workout';

  @override
  String get addExercises => 'Add exercises';

  @override
  String get addSet => 'Add set';

  @override
  String get newExercise => 'New exercise';

  @override
  String get createNewExercise => 'Create new exercise';

  @override
  String get exerciseOptions => 'Exercise options';

  @override
  String get showArchived => 'Show archived';

  @override
  String get archivedExercises => 'Archived exercises';

  @override
  String archiveConfirmTitle(Object exerciseName) {
    return 'Archive $exerciseName?';
  }

  @override
  String get archiveConfirmBody =>
      'This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\n Archiving won\'t affect any of your past workouts — your history stays intact.';

  @override
  String get exerciseArchived => 'This exercise is archived \nand won\'t appear in your main library anymore.';

  @override
  String get deleteSet => 'Delete set';

  @override
  String get set => 'Set';

  @override
  String get sets => 'Sets';

  @override
  String get previous => 'Previous';

  @override
  String get reps => 'Reps';

  @override
  String get time => 'Time';

  @override
  String get kg => 'kg';

  @override
  String get mile => 'mile';

  @override
  String get km => 'km';

  @override
  String get milesPlural => 'miles';

  @override
  String miles(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany miles',
      one: '$howMany mile',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get repeat => 'Repeat';

  @override
  String get add => 'Add';

  @override
  String get share => 'Share';

  @override
  String get okBang => 'Ok!';

  @override
  String get cancel => 'Cancel';

  @override
  String get finish => 'Finish';

  @override
  String get reset => 'Reset';

  @override
  String get h => 'h';

  @override
  String get min => 'min';

  @override
  String get sec => 'sec';

  @override
  String get lbs => 'lbs';

  @override
  String get skip => 'Skip';

  @override
  String lb(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany lbs',
      one: '$howMany lb',
    );
    return '$_temp0';
  }

  @override
  String get saveAsTemplate => 'Save as template';

  @override
  String get addNote => 'Add a note';

  @override
  String get replaceExercise => 'Replace exercise';

  @override
  String get weightUnit => 'Weight';

  @override
  String get distanceUnit => 'Distance';

  @override
  String get duration => 'Duration';

  @override
  String get imperial => 'Imperial';

  @override
  String get metric => 'Metric';

  @override
  String get restTimer => 'Rest timer';

  @override
  String get cancelTimer => 'Cancel timer';

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String morningWorkout(String when) {
    return '$when, Morning';
  }

  @override
  String eveningWorkout(String when) {
    return '$when, Evening';
  }

  @override
  String nightWorkout(String when) {
    return '$when, Night';
  }

  @override
  String afternoonWorkout(String when) {
    return '$when, Afternoon';
  }

  @override
  String get emptyHistoryTitle => 'Your completed workouts will be here';

  @override
  String get emptyHistoryBody => 'Go get them done!';

  @override
  String get historyEndReached => 'You\'ve reached the end';

  @override
  String get historyLoadMoreError => 'Couldn\'t load more workouts';

  @override
  String get retry => 'Retry';

  @override
  String get workoutTimeoutTitle => 'Still working out?';

  @override
  String get workoutTimeoutBody => 'Your workout\'s been idle for a while — jump back in or wrap it up.';

  @override
  String get notificationsDisabledReminder => 'Notifications are off, so you won\'t get rest-timer alerts.';

  @override
  String get themePresetSetting => 'Theme';

  @override
  String get themePresetSettingSubtitle => 'Presets tuned for both light and dark';

  @override
  String get themePresetForge => 'Forge';

  @override
  String get themePresetInk => 'Ink';

  @override
  String get themePresetUtility => 'Utility';

  @override
  String get themePresetEmber => 'Ember';

  @override
  String get aboutApp => 'About app';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get congratulationsBody => 'Your workout is complete!';

  @override
  String goalsAchievedHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Goals reached',
      one: 'Goal reached',
    );
    return '$_temp0';
  }

  @override
  String goalAchievedTarget(String goal, String target) {
    return '$goal · $target';
  }

  @override
  String get finishWorkoutTitle => 'Finish Workout?';

  @override
  String get finishWorkoutWarningTitle => 'Complete Your Workout?';

  @override
  String get finishWorkoutWarningBody =>
      'Any empty or invalid sets will be discarded, and all valid sets will be marked as completed.';

  @override
  String get finishWorkoutBody => 'Ready to finish this workout?';

  @override
  String get cancelWorkoutBody => 'All progress made so far will be lost.';

  @override
  String get cancelWorkoutTitle => 'Do you want to cancel this workout?';

  @override
  String get readyToFinish => 'Yes, I\'m done!';

  @override
  String get keepCurrentAccount => 'No, keep current workout';

  @override
  String get cancelAndStartNewWorkout => 'Yes, cancel that one and start a new workout';

  @override
  String get resumeWorkout => 'No, resume workout';

  @override
  String get deleteThis => 'Yes, delete this';

  @override
  String get deleted => 'Deleted';

  @override
  String get notReadyToFinish => 'No, one more set!';

  @override
  String get deleteTemplateTitle => 'Do you want to delete this workout template?';

  @override
  String get deleteTemplateBody => 'This cannot be undone';

  @override
  String get quitEditing => 'Quit editing?';

  @override
  String get changesWillBeLost => 'All changes will be lost';

  @override
  String get quitPage => 'Quit this page';

  @override
  String get stayHere => 'Stay here';

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String selected(Object count) {
    return 'Selected $count';
  }

  @override
  String forExercise(String exercise) {
    return 'for $exercise';
  }

  @override
  String get restTimerSubtitle => 'Adjust duration via the +/- buttons.';

  @override
  String get addSeconds => '+10s';

  @override
  String get subtractSeconds => '-10s';

  @override
  String get restComplete => 'Rest complete!';

  @override
  String get workoutsPerWeek => 'Workouts per week';

  @override
  String get workoutsPerWeekTitle => 'Your workouts will be presented here';

  @override
  String get workoutsPerWeekBody => 'Go get them done!';

  @override
  String get goals => 'Goals';

  @override
  String get addGoal => 'Add goal';

  @override
  String get noGoalsYet => 'No goals yet';

  @override
  String get workouts => 'Workouts';

  @override
  String get newGoal => 'New goal';

  @override
  String get goalTarget => 'Target';

  @override
  String get goalPerWeek => 'per week';

  @override
  String get goalPerMonth => 'per month';

  @override
  String goalDue(String date) {
    return 'Due $date';
  }

  @override
  String get goalComplete => 'Complete';

  @override
  String get goalMilestone => 'Milestone';

  @override
  String get goalWeekly => 'Weekly';

  @override
  String get goalMonthly => 'Monthly';

  @override
  String get goalLadder => 'Milestones';

  @override
  String get goalAddRung => 'Add milestone';

  @override
  String goalAchievedOn(String date) {
    return 'Achieved $date';
  }

  @override
  String get goalNoDeadline => 'No deadline';

  @override
  String get goalSetDeadline => 'Set a deadline';

  @override
  String get goalClearDeadline => 'Clear deadline';

  @override
  String get goalsViewAchieved => 'Achieved';

  @override
  String get goalsAchievedTitle => 'Achieved';

  @override
  String get goalsViewActive => 'Back';

  @override
  String get goalOpenWorkout => 'View the session';

  @override
  String get goalWorkoutGone => 'That session is no longer on this device';

  @override
  String get goalsAtCapacity => 'You have as many goals as Heart keeps. Delete one to make room for another.';

  @override
  String get category => 'Category';

  @override
  String get target => 'Target';

  @override
  String get removeFilter => 'Remove filter';

  @override
  String restCompleteBody(Object exercise) {
    return 'Next: $exercise';
  }

  @override
  String weightedSetRepresentation(Object weight, Object reps) {
    return '$weight x $reps';
  }

  @override
  String get templates => 'Templates';

  @override
  String get exampleTemplates => 'Example templates';

  @override
  String get template => 'Template';

  @override
  String get newTemplate => 'New Template';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderBody => 'The templates inside will be kept';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get noFolder => 'No folder';

  @override
  String get folderNameTaken => 'You already have a folder with this name';

  @override
  String get editTemplate => 'Edit Template';

  @override
  String get editWorkout => 'Edit Workout';

  @override
  String get templateName => 'Template name';

  @override
  String get workoutName => 'Workout name';

  @override
  String get cannotBeEmpty => 'Cannot be empty';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get yourPassword => 'Your password';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordBody =>
      'We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌';

  @override
  String get orConnector => '- or -';

  @override
  String get invalidCredentials => 'Well, that didn\'t work! Double-check your details, eh?';

  @override
  String get weakPassword => 'Almost there! Try a stronger password to keep your account safe.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noConnectivity => 'Uh-oh! The internet tripped over a dumbbell. 🏋️‍♂️ Try again in a sec!';

  @override
  String get signUp => 'Sign up';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get recoveryLinkMessage =>
      'If an account exists for this email, you\'ll receive a reset link shortly. Check your inbox and spam folder.';

  @override
  String get recoveryLinkMessageSent =>
      '💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide).';

  @override
  String get emailExistsTitle => 'Email already exists';

  @override
  String get emailExistsOkButton => 'Yes, sign me in!';

  @override
  String get emailExistsCancelButton => 'No, I got this';

  @override
  String emailExistsBody(Object address) {
    return 'An account with $address already exists. Would you like to log in instead?';
  }

  @override
  String get sendResetLinkBody => 'Enter you email and we\'ll help you reset your password';

  @override
  String get userDisabled => 'This account is disabled';

  @override
  String get unknownError => 'Unknown error occurred';

  @override
  String get accountControl => 'Account control';

  @override
  String get leaveFeedback => 'Leave feedback';

  @override
  String leaveFeedbackBody(Object emoji) {
    return 'Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\n\nWe love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. $emoji';
  }

  @override
  String get feedbackReceived => 'Your feedback was received, thank you!';

  @override
  String get toFeedback => 'To feedback!';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Are you sure you want to delete your account?';

  @override
  String deleteAccountBody(Object deadline) {
    return 'Your account is scheduled for deletion in $deadline days. During this time, you can still sign in and reverse this decision. Once the deadline has passed, your account and personal data will be permanently deleted.';
  }

  @override
  String get deleteAccountCancelMessage => 'Oh no, I like it here!';

  @override
  String get deleteAccountConfirmMessage => 'Yep, go on without me!';

  @override
  String get confirmDeleteAccountTitle => 'Confirm your account deletion';

  @override
  String get confirmDeleteAccountCancelMessage => 'Changed my mind, cancel';

  @override
  String get confirmDeleteAccountOkMessage => 'Farewell!';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String accountDeletedBody(Object date) {
    return 'Your account has been scheduled for deletion on $date.\n\nIf you change your mind, you can restore your account anytime before this date.\n\nSimply click the button below to cancel the deletion and keep your account safe.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Undo the Goodbye 🥇🔥';

  @override
  String get movement => 'Movement';

  @override
  String get pattern => 'Pattern';

  @override
  String get stability => 'Stability';

  @override
  String get skillAtMost => 'Skill at most';

  @override
  String get patternHelp =>
      'The movement itself — coarser than equipment, finer than body part. Exercises that share a pattern can stand in for one another.';

  @override
  String get stabilityHelp =>
      'How much the equipment holds the path for you. Free means you balance the weight yourself; machine means the path is fixed.';

  @override
  String get skillAtMostHelp =>
      'How much technique an exercise demands before it can be loaded safely. Choosing Moderate also includes Low.';

  @override
  String get clearFilters => 'Clear';

  @override
  String get alsoTry => 'Also try';

  @override
  String get about => 'About';

  @override
  String get records => 'Records';

  @override
  String get chartWeeklyAverage => 'Weekly average';

  @override
  String get chartMonthlyAverage => 'Monthly average';

  @override
  String get chartYearlyAverage => 'Yearly average';

  @override
  String get chartRangeMonth => '1M';

  @override
  String get chartRangeQuarter => '3M';

  @override
  String get chartRangeYear => '1Y';

  @override
  String get chartRangeAll => 'All';

  @override
  String get chartGenericLabel => 'Chart';

  @override
  String exerciseChartSummary(Object metric, Object start, Object end, Object latest, Object trend) {
    return '$metric from $start to $end. Latest: $latest. Trend: $trend.';
  }

  @override
  String get exerciseChartTrendUp => 'Increasing';

  @override
  String get exerciseChartTrendDown => 'Decreasing';

  @override
  String get exerciseChartTrendFlat => 'Flat';

  @override
  String healthCardSummary(String metric, String value, String when) {
    return '$metric, $value, $when';
  }

  @override
  String get charts => 'Charts';

  @override
  String get emptyExerciseHistoryTitle => 'Ghost Reps Detected 👻';

  @override
  String get emptyExerciseHistoryBody =>
      'Your exercise history is emptier than a gym on a Monday morning. Time to fill it up with some glorious PRs!';

  @override
  String get errorExerciseHistoryTitle => 'Oops! Someone Skipped the Data Day 🤷‍♀️';

  @override
  String get errorExerciseHistoryBody =>
      'Looks like the app tripped over its own shoelaces. Try again, and we promise to tie them tighter next time!';

  @override
  String get bestSetVolume => 'Best set volume';

  @override
  String get mostReps => 'Most reps';

  @override
  String get bestPace => 'Best pace';

  @override
  String get leastAssistance => 'Least assistance';

  @override
  String get repMaxes => 'Rep maxes';

  @override
  String repMaxCount(num reps) {
    String _temp0 = intl.Intl.pluralLogic(
      reps,
      locale: localeName,
      other: '$reps reps',
      one: '$reps rep',
    );
    return '$_temp0';
  }

  @override
  String get allTime => 'All time';

  @override
  String get sessions => 'Sessions';

  @override
  String get firstPerformed => 'First performed';

  @override
  String get totalTime => 'Total time';

  @override
  String get totalDistance => 'Total distance';

  @override
  String get personalRecords => 'Personal records';

  @override
  String get maxDuration => 'Max duration';

  @override
  String get maxDistance => 'Max distance';

  @override
  String get maxWeight => 'Max weight';

  @override
  String get maxReps => 'Max reps';

  @override
  String get capturePhoto => 'Take a new photo';

  @override
  String get chooseFromGallery => 'Choose from library';

  @override
  String get removeCurrentPhoto => 'Remove current photo';

  @override
  String get mine => 'Mine';

  @override
  String get goToWorkout => 'Go to Workout';

  @override
  String get setTimer => 'Set timer';

  @override
  String get updateRequiredTitle => 'Oops. That one’s on us';

  @override
  String get updateRequiredBody =>
      'There’s an important update waiting — one that keeps your app working as it should.\n\nYou’ll need to install it before continuing.\nThanks for your patience — and sorry for the interruption.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Update on the $storeName';
  }

  @override
  String get addPhoto => 'Add photo';

  @override
  String get editWorkoutName => 'Edit workout name';

  @override
  String get editWorkoutTimes => 'Edit times';

  @override
  String get adjustTimes => 'Adjust Start/End Time';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get endBeforeStart => 'End time can\'t be before the start time.';

  @override
  String get cropImage => 'Crop image';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get aboutExercise => 'About exercise';

  @override
  String get myDashboard => 'My Dashboard';

  @override
  String get newChart => 'New chart';

  @override
  String get addChartToProfile => 'Add to profile';

  @override
  String get addToActiveWorkout => 'Add to workout';

  @override
  String get exerciseAddedToWorkout => 'Added to workout';

  @override
  String get chartAddedToProfile => 'Added to profile';

  @override
  String get removeChartFromProfile => 'Remove from profile';

  @override
  String get emptyChartStateTitle => 'Looks a little empty here';

  @override
  String get emptyChartStateBody => 'Add your first set to start tracking real progress';

  @override
  String get topSetWeight => 'Top set weight';

  @override
  String get estimatedOneRepMax => 'Estimated 1RM';

  @override
  String get totalVolume => 'Total volume';

  @override
  String get averageWorkingWeight => 'Average working weight';

  @override
  String get assistanceWeight => 'Assistance weight';

  @override
  String get maxRepsInSet => 'Max reps in a set';

  @override
  String get totalReps => 'Total reps';

  @override
  String get cardioDistance => 'Distance';

  @override
  String get cardioDuration => 'Duration';

  @override
  String get averagePace => 'Average pace';

  @override
  String get totalTimeUnderTension => 'Total time under tension';

  @override
  String get passwordPolicyTitle => 'Let\'s make a password that lifts:';

  @override
  String passwordPolicyMinLength(int minLength) {
    return 'at least $minLength characters';
  }

  @override
  String passwordPolicyMaxLength(int maxLength) {
    return 'no more than $maxLength (we believe in limits)';
  }

  @override
  String get passwordPolicyUpperCase => 'one uppercase letter';

  @override
  String get passwordPolicyLowerCase => 'one lowercase letter';

  @override
  String get passwordPolicyDigit => 'one number somewhere in there';

  @override
  String get deleteImageDialogTitle => 'Remove this image?';

  @override
  String get deleteImageDialogBody => 'It won\'t affect the workout — just clears the picture';

  @override
  String get myProgression => 'My progression';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get weightUnitLabel => 'Weight unit';

  @override
  String get distanceUnitLabel => 'Distance unit';

  @override
  String get close => 'Close';

  @override
  String get noWorkoutSelectedTitle => 'Nothing selected';

  @override
  String get noWorkoutSelectedBody => 'Pick a workout to see what you did and make changes.';

  @override
  String get noExerciseSelectedTitle => 'Nothing selected';

  @override
  String get noExerciseSelectedBody => 'Pick an exercise to see how it\'s done, plus your history and records.';

  @override
  String get moreOptions => 'More options';

  @override
  String get viewProgressPhotos => 'View progress photos';

  @override
  String get confirmEdit => 'Confirm';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get viewAccountDetails => 'Account details';

  @override
  String get viewProfilePhoto => 'View profile photo';

  @override
  String durationPickerSetTo(Object duration) {
    return 'Set rest timer to $duration';
  }

  @override
  String get emptyWorkoutLabel => 'Empty workout';

  @override
  String progressPhotoLabel(Object date) {
    return 'Progress photo from $date';
  }

  @override
  String exerciseThumbnailLabel(Object exerciseName) {
    return '$exerciseName thumbnail';
  }

  @override
  String goalLadderSummary(Object achieved, Object total, Object current) {
    return '$achieved of $total targets reached. Current: $current.';
  }

  @override
  String restTimerRemaining(Object remaining) {
    return 'Rest timer: $remaining remaining';
  }

  @override
  String get health => 'Health';

  @override
  String get healthActiveEnergy => 'Active energy';

  @override
  String get healthBodyMass => 'Body mass';

  @override
  String get healthBpm => 'bpm';

  @override
  String get healthChecking => 'Looking for new readings…';

  @override
  String healthLatestReading(String when) {
    return 'Latest reading · $when';
  }

  @override
  String get healthDelete => 'Delete health data';

  @override
  String get healthDeleteBody =>
      'This clears what Heart has read onto this device. Nothing in your phone\'s health store changes, and Heart will read it again the next time it syncs.';

  @override
  String get healthDeleteTitle => 'Delete Heart\'s copy of your health data?';

  @override
  String get healthHeartRateVariability => 'Heart rate variability';

  @override
  String get healthHoursShort => 'h';

  @override
  String get healthInviteAction => 'Show my health data';

  @override
  String get healthInviteBody =>
      'Heart can show your resting heart rate, sleep, steps and body mass next to your workouts. It reads them from your phone\'s health store, and keeps them on this device.';

  @override
  String get healthInviteDismiss => 'Not now';

  @override
  String get healthInviteTitle => 'Health data';

  @override
  String get healthKilocalories => 'kcal';

  @override
  String get healthMilliseconds => 'ms';

  @override
  String get healthMinutesShort => 'm';

  @override
  String get healthOffInHealthApp => 'In the Health app, tap your profile picture, then Apps, and let Heart read.';

  @override
  String get healthOffInSettings =>
      'Let Heart read your health data in your device’s health settings. Allow past data too, or charts stop at the last 30 days.';

  @override
  String get healthOffTitle => 'Heart isn’t reading any health data';

  @override
  String get healthOnThisDevice => 'On this device';

  @override
  String get healthOpenHealthApp => 'Open the Health app';

  @override
  String get healthOpenHealthAppHint => 'Tap your profile picture, then Apps';

  @override
  String get healthOpenSettingsHint => 'Also allow access to past data';

  @override
  String get healthOpenSettings => 'Open settings';

  @override
  String get healthRestingHeartRate => 'Resting heart rate';

  @override
  String get healthSettingsBody =>
      'Heart reads resting heart rate, heart rate variability, sleep, steps, active energy and body mass from your phone\'s health store. They stay on this device.';

  @override
  String get healthWriteWorkouts => 'Save workouts to Health';

  @override
  String get healthWriteWorkoutsOn => 'Saving how long you train, and nothing else';

  @override
  String get healthWriteWorkoutsOff => 'Off · Heart is not saving your workouts';

  @override
  String get healthSleep => 'Sleep';

  @override
  String get healthSteps => 'Steps';

  @override
  String get deleteWorkoutTitle => 'Do you want to delete this workout?';

  @override
  String get deleteWorkoutBody => 'This cannot be undone';

  @override
  String get importData => 'Import workout history';

  @override
  String get importPreviewTitle => 'Ready to import';

  @override
  String importPreviewSummary(num workouts, num sets) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts workouts',
      one: '1 workout',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '$_temp0 and $_temp1 ready to come over';
  }

  @override
  String importPreviewSummaryPartial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts are new',
      one: '1 workout is new',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNothingNew(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'all $count workouts in this file are',
      one: 'the 1 workout in this file is',
    );
    return 'Nothing new — $_temp0 already here';
  }

  @override
  String importPreviewMatched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises already match the library',
      one: '1 exercise already matches the library',
    );
    return '$_temp0';
  }

  @override
  String importPreviewAlreadyHere(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts are already here — they will be skipped',
      one: '1 workout is already here — it will be skipped',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get importConsentTitle => 'New exercises found';

  @override
  String get importConsentBody =>
      'These didn\'t match anything in the library. Check the ones to bring over as your own custom exercises — anything unchecked stays behind, along with its sets.';

  @override
  String get importAction => 'Import';

  @override
  String importSetsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String importSkippedSets(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets stayed behind',
      one: '1 set stayed behind',
    );
    return '$_temp0 with the exercises you declined';
  }

  @override
  String get yourData => 'Your data';

  @override
  String get account => 'Account';

  @override
  String get app => 'App';

  @override
  String get importExplainerStrong =>
      'Lifted with Strong before? Bring your history along.\n\nIn the Strong app, go to Profile → Settings → Export Strong Data. It emails you a CSV file — save it, then pick it here.';

  @override
  String get importSafeToRetry =>
      'Everything comes over — workouts, sets, exercises. Importing the same file twice is safe: anything already here is skipped, never duplicated.';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get csvFiles => 'CSV files';

  @override
  String get importInFlight => 'Importing — hang tight…';

  @override
  String get importFailedHeadline => 'That file didn\'t work';

  @override
  String get importFailedBody =>
      'It couldn\'t be read as a Strong export. Pick the CSV file from Strong\'s export email and try again.';

  @override
  String get importReportTitle => 'Imported!';

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts imported',
      one: '1 workout imported',
      zero: 'No new workouts',
    );
    return '$_temp0';
  }

  @override
  String importSkippedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts were already here — skipped',
      one: '1 workout was already here — skipped',
    );
    return '$_temp0';
  }

  @override
  String importedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0 in all';
  }

  @override
  String importSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 couldn\'t be read';
  }

  @override
  String get importNewExercisesHeader => 'New custom exercises';

  @override
  String get importNewExercisesBody =>
      'These didn\'t match anything in the library, so they came over as your custom exercises:';
}

/// The translations for English, as used in Canada (`en_CA`).
class LEnCa extends LEn {
  LEnCa() : super('en_CA');

  @override
  String get appearance => 'Appearance';

  @override
  String get units => 'Units';

  @override
  String get motto => 'Every beat counts.';

  @override
  String get toLightMode => 'Light';

  @override
  String get toDarkMode => 'Dark';

  @override
  String get toSystemMode => 'System';

  @override
  String get email => 'Email';

  @override
  String get yourEmail => 'Your email';

  @override
  String get cropAvatar => 'Crop avatar';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get name => 'Name';

  @override
  String get saveName => 'Save name';

  @override
  String get changeName => 'Change name';

  @override
  String get save => 'Save';

  @override
  String get settings => 'Settings';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get password => 'Password';

  @override
  String get logIn => 'Log in';

  @override
  String get logInTitle => 'Welcome Back';

  @override
  String get logInBody => 'You\'ve already started something important.\nLet\'s keep going.';

  @override
  String get signUpTitle => 'Begin with Heart';

  @override
  String get signUpBody => 'Every journey starts with one decision.\nThis one\'s yours.';

  @override
  String get recoverTitle => 'Still with You';

  @override
  String get recoverBody => 'Your journey isn\'t lost.\nJust a moment of pause — we\'ll reset together.';

  @override
  String get logInWithGoogle => 'Log in with Google';

  @override
  String get signUpWithGoogle => 'Sign up with Google';

  @override
  String get logInWithApple => 'Log in with Apple';

  @override
  String get signUpWithApple => 'Sign up with Apple';

  @override
  String get logOut => 'Log out';

  @override
  String get profile => 'Profile';

  @override
  String get workout => 'Workout';

  @override
  String get history => 'History';

  @override
  String get exercises => 'Exercises';

  @override
  String get search => 'Search';

  @override
  String get startNewWorkout => 'Start a new workout';

  @override
  String get cancelCurrentWorkoutTitle => 'Cancel current workout?';

  @override
  String get cancelCurrentWorkoutBody =>
      'You have a workout in progress. Do you want to cancel it and start a new one?';

  @override
  String get startNewWorkoutFromTemplate => 'Start a new workout from this template?';

  @override
  String get startWorkout => 'Start workout';

  @override
  String get cancelWorkout => 'Cancel workout';

  @override
  String get addExercises => 'Add exercises';

  @override
  String get addSet => 'Add set';

  @override
  String get newExercise => 'New exercise';

  @override
  String get createNewExercise => 'Create new exercise';

  @override
  String get exerciseOptions => 'Exercise options';

  @override
  String get showArchived => 'Show archived';

  @override
  String get archivedExercises => 'Archived exercises';

  @override
  String archiveConfirmTitle(Object exerciseName) {
    return 'Archive $exerciseName?';
  }

  @override
  String get archiveConfirmBody =>
      'This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\n Archiving won\'t affect any of your past workouts — your history stays intact.';

  @override
  String get exerciseArchived => 'This exercise is archived\nand won\'t appear in your main library anymore.';

  @override
  String get deleteSet => 'Delete set';

  @override
  String get set => 'Set';

  @override
  String get sets => 'Sets';

  @override
  String get previous => 'Previous';

  @override
  String get reps => 'Reps';

  @override
  String get time => 'Time';

  @override
  String get kg => 'kg';

  @override
  String get mile => 'mile';

  @override
  String get km => 'km';

  @override
  String get milesPlural => 'miles';

  @override
  String miles(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany miles',
      one: '$howMany mile',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get repeat => 'Repeat';

  @override
  String get add => 'Add';

  @override
  String get share => 'Share';

  @override
  String get okBang => 'Ok!';

  @override
  String get cancel => 'Cancel';

  @override
  String get finish => 'Finish';

  @override
  String get reset => 'Reset';

  @override
  String get h => 'h';

  @override
  String get min => 'min';

  @override
  String get sec => 'sec';

  @override
  String get lbs => 'lbs';

  @override
  String get skip => 'Skip';

  @override
  String lb(num howMany) {
    String _temp0 = intl.Intl.pluralLogic(
      howMany,
      locale: localeName,
      other: '$howMany lbs',
      one: '$howMany lb',
    );
    return '$_temp0';
  }

  @override
  String get saveAsTemplate => 'Save as template';

  @override
  String get addNote => 'Add a note';

  @override
  String get replaceExercise => 'Replace exercise';

  @override
  String get weightUnit => 'Weight';

  @override
  String get distanceUnit => 'Distance';

  @override
  String get duration => 'Duration';

  @override
  String get imperial => 'Imperial';

  @override
  String get metric => 'Metric';

  @override
  String get restTimer => 'Rest timer';

  @override
  String get cancelTimer => 'Cancel timer';

  @override
  String get removeExercise => 'Remove exercise';

  @override
  String morningWorkout(String when) {
    return '$when, Morning';
  }

  @override
  String eveningWorkout(String when) {
    return '$when, Evening';
  }

  @override
  String nightWorkout(String when) {
    return '$when, Night';
  }

  @override
  String afternoonWorkout(String when) {
    return '$when, Afternoon';
  }

  @override
  String get emptyHistoryTitle => 'Your completed workouts will be here';

  @override
  String get emptyHistoryBody => 'Go get them done!';

  @override
  String get historyEndReached => 'You\'ve reached the end';

  @override
  String get historyLoadMoreError => 'Couldn\'t load more workouts';

  @override
  String get retry => 'Retry';

  @override
  String get workoutTimeoutTitle => 'Still working out?';

  @override
  String get workoutTimeoutBody => 'Your workout\'s been idle for a while — jump back in or wrap it up.';

  @override
  String get notificationsDisabledReminder => 'Notifications are off, so you won\'t get rest-timer alerts.';

  @override
  String get themePresetSetting => 'Theme';

  @override
  String get themePresetSettingSubtitle => 'Presets tuned for both light and dark';

  @override
  String get themePresetForge => 'Forge';

  @override
  String get themePresetInk => 'Ink';

  @override
  String get themePresetUtility => 'Utility';

  @override
  String get themePresetEmber => 'Ember';

  @override
  String get aboutApp => 'About app';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get congratulationsBody => 'Your workout is complete!';

  @override
  String goalsAchievedHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Goals reached',
      one: 'Goal reached',
    );
    return '$_temp0';
  }

  @override
  String goalAchievedTarget(String goal, String target) {
    return '$goal · $target';
  }

  @override
  String get finishWorkoutTitle => 'Finish Workout?';

  @override
  String get finishWorkoutWarningTitle => 'Complete Your Workout?';

  @override
  String get finishWorkoutWarningBody =>
      'Any empty or invalid sets will be discarded, and all valid sets will be marked as completed.';

  @override
  String get finishWorkoutBody => 'Ready to finish this workout?';

  @override
  String get cancelWorkoutBody => 'All progress made so far will be lost.';

  @override
  String get cancelWorkoutTitle => 'Do you want to cancel this workout?';

  @override
  String get readyToFinish => 'Yes, I\'m done!';

  @override
  String get keepCurrentAccount => 'No, keep current workout';

  @override
  String get cancelAndStartNewWorkout => 'Yes, cancel that one and start a new workout';

  @override
  String get resumeWorkout => 'No, resume workout';

  @override
  String get deleteThis => 'Yes, delete this';

  @override
  String get deleted => 'Deleted';

  @override
  String get notReadyToFinish => 'No, one more set!';

  @override
  String get deleteTemplateTitle => 'Do you want to delete this workout template?';

  @override
  String get deleteTemplateBody => 'This cannot be undone';

  @override
  String get quitEditing => 'Quit editing?';

  @override
  String get changesWillBeLost => 'All changes will be lost';

  @override
  String get quitPage => 'Quit this page';

  @override
  String get stayHere => 'Stay here';

  @override
  String get notificationSettings => 'Notification settings';

  @override
  String selected(Object count) {
    return 'Selected $count';
  }

  @override
  String forExercise(String exercise) {
    return 'for $exercise';
  }

  @override
  String get restTimerSubtitle => 'Adjust duration via the +/- buttons.';

  @override
  String get addSeconds => '+10s';

  @override
  String get subtractSeconds => '-10s';

  @override
  String get restComplete => 'Rest complete!';

  @override
  String get workoutsPerWeek => 'Workouts per week';

  @override
  String get workoutsPerWeekTitle => 'Your workouts will be presented here';

  @override
  String get workoutsPerWeekBody => 'Go get them done!';

  @override
  String get goals => 'Goals';

  @override
  String get addGoal => 'Add goal';

  @override
  String get noGoalsYet => 'No goals yet';

  @override
  String get workouts => 'Workouts';

  @override
  String get newGoal => 'New goal';

  @override
  String get goalTarget => 'Target';

  @override
  String get goalPerWeek => 'per week';

  @override
  String get goalPerMonth => 'per month';

  @override
  String goalDue(String date) {
    return 'Due $date';
  }

  @override
  String get goalComplete => 'Complete';

  @override
  String get goalMilestone => 'Milestone';

  @override
  String get goalWeekly => 'Weekly';

  @override
  String get goalMonthly => 'Monthly';

  @override
  String get goalLadder => 'Milestones';

  @override
  String get goalAddRung => 'Add milestone';

  @override
  String goalAchievedOn(String date) {
    return 'Achieved $date';
  }

  @override
  String get goalNoDeadline => 'No deadline';

  @override
  String get goalSetDeadline => 'Set a deadline';

  @override
  String get goalClearDeadline => 'Clear deadline';

  @override
  String get goalsViewAchieved => 'Achieved';

  @override
  String get goalsAchievedTitle => 'Achieved';

  @override
  String get goalsViewActive => 'Back';

  @override
  String get goalOpenWorkout => 'View the session';

  @override
  String get goalWorkoutGone => 'That session is no longer on this device';

  @override
  String get goalsAtCapacity => 'You have as many goals as Heart keeps. Delete one to make room for another.';

  @override
  String get category => 'Category';

  @override
  String get target => 'Target';

  @override
  String get removeFilter => 'Remove filter';

  @override
  String restCompleteBody(Object exercise) {
    return 'Next: $exercise';
  }

  @override
  String weightedSetRepresentation(Object weight, Object reps) {
    return '$weight x $reps';
  }

  @override
  String get templates => 'Templates';

  @override
  String get exampleTemplates => 'Example templates';

  @override
  String get template => 'Template';

  @override
  String get newTemplate => 'New Template';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String get deleteFolderBody => 'The templates inside will be kept';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get noFolder => 'No folder';

  @override
  String get folderNameTaken => 'You already have a folder with this name';

  @override
  String get editTemplate => 'Edit Template';

  @override
  String get editWorkout => 'Edit Workout';

  @override
  String get templateName => 'Template name';

  @override
  String get workoutName => 'Workout name';

  @override
  String get cannotBeEmpty => 'Cannot be empty';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get yourPassword => 'Your password';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordBody =>
      'We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌';

  @override
  String get orConnector => '- or -';

  @override
  String get invalidCredentials => 'Well, that didn\'t work! Double-check your details, eh?';

  @override
  String get weakPassword => 'Almost there! Try a stronger password to keep your account safe.';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noConnectivity => 'Uh-oh! The internet tripped over a dumbbell. 🏋️‍♂️ Try again in a sec!';

  @override
  String get signUp => 'Sign up';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get recoveryLinkMessage =>
      'If an account exists for this email, you\'ll receive a reset link shortly. Check your inbox and spam folder.';

  @override
  String get recoveryLinkMessageSent =>
      '💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide).';

  @override
  String get emailExistsTitle => 'Email already exists';

  @override
  String get emailExistsOkButton => 'Yes, sign me in!';

  @override
  String get emailExistsCancelButton => 'No, I got this';

  @override
  String emailExistsBody(Object address) {
    return 'An account with $address already exists. Would you like to log in instead?';
  }

  @override
  String get sendResetLinkBody => 'Enter you email and we\'ll help you reset your password';

  @override
  String get userDisabled => 'This account is disabled';

  @override
  String get unknownError => 'Unknown error occurred';

  @override
  String get accountControl => 'Account control';

  @override
  String get leaveFeedback => 'Leave feedback';

  @override
  String leaveFeedbackBody(Object emoji) {
    return 'Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\n\nWe love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. $emoji';
  }

  @override
  String get feedbackReceived => 'Your feedback was received, thank you!';

  @override
  String get toFeedback => 'To feedback!';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Are you sure you want to delete your account?';

  @override
  String deleteAccountBody(Object deadline) {
    return 'Your account is scheduled for deletion in $deadline days. During this time, you can still sign in and reverse this decision. Once the deadline has passed, your account and personal data will be permanently deleted.';
  }

  @override
  String get deleteAccountCancelMessage => 'Oh no, I like it here!';

  @override
  String get deleteAccountConfirmMessage => 'Yep, go on without me!';

  @override
  String get confirmDeleteAccountTitle => 'Confirm your account deletion';

  @override
  String get confirmDeleteAccountCancelMessage => 'Changed my mind, cancel';

  @override
  String get confirmDeleteAccountOkMessage => 'Farewell!';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String accountDeletedBody(Object date) {
    return 'Your account has been scheduled for deletion on $date.\n\nIf you change your mind, you can restore your account anytime before this date.\n\nSimply click the button below to cancel the deletion and keep your account safe.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Undo the Goodbye 🥇🔥';

  @override
  String get movement => 'Movement';

  @override
  String get pattern => 'Pattern';

  @override
  String get stability => 'Stability';

  @override
  String get skillAtMost => 'Skill at most';

  @override
  String get patternHelp =>
      'The movement itself — coarser than equipment, finer than body part. Exercises that share a pattern can stand in for one another.';

  @override
  String get stabilityHelp =>
      'How much the equipment holds the path for you. Free means you balance the weight yourself; machine means the path is fixed.';

  @override
  String get skillAtMostHelp =>
      'How much technique an exercise demands before it can be loaded safely. Choosing Moderate also includes Low.';

  @override
  String get clearFilters => 'Clear';

  @override
  String get alsoTry => 'Also try';

  @override
  String get about => 'About';

  @override
  String get records => 'Records';

  @override
  String get chartWeeklyAverage => 'Weekly average';

  @override
  String get chartMonthlyAverage => 'Monthly average';

  @override
  String get chartYearlyAverage => 'Yearly average';

  @override
  String get chartRangeMonth => '1M';

  @override
  String get chartRangeQuarter => '3M';

  @override
  String get chartRangeYear => '1Y';

  @override
  String get chartRangeAll => 'All';

  @override
  String get chartGenericLabel => 'Chart';

  @override
  String exerciseChartSummary(Object metric, Object start, Object end, Object latest, Object trend) {
    return '$metric from $start to $end. Latest: $latest. Trend: $trend.';
  }

  @override
  String get exerciseChartTrendUp => 'Increasing';

  @override
  String get exerciseChartTrendDown => 'Decreasing';

  @override
  String get exerciseChartTrendFlat => 'Flat';

  @override
  String healthCardSummary(String metric, String value, String when) {
    return '$metric, $value, $when';
  }

  @override
  String get charts => 'Charts';

  @override
  String get emptyExerciseHistoryTitle => 'Ghost Reps Detected 👻';

  @override
  String get emptyExerciseHistoryBody =>
      'Your exercise history is emptier than a gym on a Monday morning. Time to fill it up with some glorious PRs!';

  @override
  String get errorExerciseHistoryTitle => 'Oops! Someone Skipped the Data Day 🤷‍♀️';

  @override
  String get errorExerciseHistoryBody =>
      'Looks like the app tripped over its own shoelaces. Try again, and we promise to tie them tighter next time!';

  @override
  String get bestSetVolume => 'Best set volume';

  @override
  String get mostReps => 'Most reps';

  @override
  String get bestPace => 'Best pace';

  @override
  String get leastAssistance => 'Least assistance';

  @override
  String get repMaxes => 'Rep maxes';

  @override
  String repMaxCount(num reps) {
    String _temp0 = intl.Intl.pluralLogic(
      reps,
      locale: localeName,
      other: '$reps reps',
      one: '$reps rep',
    );
    return '$_temp0';
  }

  @override
  String get allTime => 'All time';

  @override
  String get sessions => 'Sessions';

  @override
  String get firstPerformed => 'First performed';

  @override
  String get totalTime => 'Total time';

  @override
  String get totalDistance => 'Total distance';

  @override
  String get personalRecords => 'Personal records';

  @override
  String get maxDuration => 'Max duration';

  @override
  String get maxDistance => 'Max distance';

  @override
  String get maxWeight => 'Max weight';

  @override
  String get maxReps => 'Max reps';

  @override
  String get capturePhoto => 'Take a new photo';

  @override
  String get chooseFromGallery => 'Choose from library';

  @override
  String get removeCurrentPhoto => 'Remove current photo';

  @override
  String get mine => 'Mine';

  @override
  String get goToWorkout => 'Go to Workout';

  @override
  String get setTimer => 'Set timer';

  @override
  String get updateRequiredTitle => 'Oops. That one\'s on us';

  @override
  String get updateRequiredBody =>
      'There\'s an important update waiting — one that keeps your app working as it should.\n\nYou\'ll need to install it before continuing.\nThanks for your patience — and sorry for the interruption.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Update on the $storeName';
  }

  @override
  String get addPhoto => 'Add photo';

  @override
  String get editWorkoutName => 'Edit workout name';

  @override
  String get editWorkoutTimes => 'Edit times';

  @override
  String get adjustTimes => 'Adjust Start/End Time';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get endBeforeStart => 'End time can\'t be before the start time.';

  @override
  String get cropImage => 'Crop image';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get aboutExercise => 'About exercise';

  @override
  String get myDashboard => 'My Dashboard';

  @override
  String get newChart => 'New chart';

  @override
  String get addChartToProfile => 'Add to profile';

  @override
  String get addToActiveWorkout => 'Add to workout';

  @override
  String get exerciseAddedToWorkout => 'Added to workout';

  @override
  String get chartAddedToProfile => 'Added to profile';

  @override
  String get removeChartFromProfile => 'Remove from profile';

  @override
  String get emptyChartStateTitle => 'Looks a little empty here';

  @override
  String get emptyChartStateBody => 'Add your first set to start tracking real progress';

  @override
  String get topSetWeight => 'Top set weight';

  @override
  String get estimatedOneRepMax => 'Estimated 1RM';

  @override
  String get totalVolume => 'Total volume';

  @override
  String get averageWorkingWeight => 'Average working weight';

  @override
  String get assistanceWeight => 'Assistance weight';

  @override
  String get maxRepsInSet => 'Max reps in a set';

  @override
  String get totalReps => 'Total reps';

  @override
  String get cardioDistance => 'Distance';

  @override
  String get cardioDuration => 'Duration';

  @override
  String get averagePace => 'Average pace';

  @override
  String get totalTimeUnderTension => 'Total time under tension';

  @override
  String get passwordPolicyTitle => 'Let\'s make a password that lifts:';

  @override
  String passwordPolicyMinLength(int minLength) {
    return 'at least $minLength characters';
  }

  @override
  String passwordPolicyMaxLength(int maxLength) {
    return 'no more than $maxLength (we believe in limits)';
  }

  @override
  String get passwordPolicyUpperCase => 'one uppercase letter';

  @override
  String get passwordPolicyLowerCase => 'one lowercase letter';

  @override
  String get passwordPolicyDigit => 'one number somewhere in there';

  @override
  String get deleteImageDialogTitle => 'Remove this image?';

  @override
  String get deleteImageDialogBody => 'It won\'t affect the workout — just clears the picture';

  @override
  String get myProgression => 'My progression';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get weightUnitLabel => 'Weight unit';

  @override
  String get distanceUnitLabel => 'Distance unit';

  @override
  String get close => 'Close';

  @override
  String get noWorkoutSelectedTitle => 'Nothing selected';

  @override
  String get noWorkoutSelectedBody => 'Pick a workout to see what you did and make changes.';

  @override
  String get noExerciseSelectedTitle => 'Nothing selected';

  @override
  String get noExerciseSelectedBody => 'Pick an exercise to see how it\'s done, plus your history and records.';

  @override
  String get moreOptions => 'More options';

  @override
  String get viewProgressPhotos => 'View progress photos';

  @override
  String get confirmEdit => 'Confirm';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get viewAccountDetails => 'Account details';

  @override
  String get viewProfilePhoto => 'View profile photo';

  @override
  String durationPickerSetTo(Object duration) {
    return 'Set rest timer to $duration';
  }

  @override
  String get emptyWorkoutLabel => 'Empty workout';

  @override
  String progressPhotoLabel(Object date) {
    return 'Progress photo from $date';
  }

  @override
  String exerciseThumbnailLabel(Object exerciseName) {
    return '$exerciseName thumbnail';
  }

  @override
  String goalLadderSummary(Object achieved, Object total, Object current) {
    return '$achieved of $total targets reached. Current: $current.';
  }

  @override
  String restTimerRemaining(Object remaining) {
    return 'Rest timer: $remaining remaining';
  }

  @override
  String get health => 'Health';

  @override
  String get healthActiveEnergy => 'Active energy';

  @override
  String get healthBodyMass => 'Body mass';

  @override
  String get healthBpm => 'bpm';

  @override
  String get healthChecking => 'Looking for new readings…';

  @override
  String healthLatestReading(String when) {
    return 'Latest reading · $when';
  }

  @override
  String get healthDelete => 'Delete health data';

  @override
  String get healthDeleteBody =>
      'This clears what Heart has read onto this device. Nothing in your phone\'s health store changes, and Heart will read it again the next time it syncs.';

  @override
  String get healthDeleteTitle => 'Delete Heart\'s copy of your health data?';

  @override
  String get healthHeartRateVariability => 'Heart rate variability';

  @override
  String get healthHoursShort => 'h';

  @override
  String get healthInviteAction => 'Show my health data';

  @override
  String get healthInviteBody =>
      'Heart can show your resting heart rate, sleep, steps and body mass next to your workouts. It reads them from your phone\'s health store, and keeps them on this device.';

  @override
  String get healthInviteDismiss => 'Not now';

  @override
  String get healthInviteTitle => 'Health data';

  @override
  String get healthKilocalories => 'kcal';

  @override
  String get healthMilliseconds => 'ms';

  @override
  String get healthMinutesShort => 'm';

  @override
  String get healthOffInHealthApp => 'In the Health app, tap your profile picture, then Apps, and let Heart read.';

  @override
  String get healthOffInSettings =>
      'Let Heart read your health data in your device’s health settings. Allow past data too, or charts stop at the last 30 days.';

  @override
  String get healthOffTitle => 'Heart isn’t reading any health data';

  @override
  String get healthOnThisDevice => 'On this device';

  @override
  String get healthOpenHealthApp => 'Open the Health app';

  @override
  String get healthOpenHealthAppHint => 'Tap your profile picture, then Apps';

  @override
  String get healthOpenSettingsHint => 'Also allow access to past data';

  @override
  String get healthOpenSettings => 'Open settings';

  @override
  String get healthRestingHeartRate => 'Resting heart rate';

  @override
  String get healthSettingsBody =>
      'Heart reads resting heart rate, heart rate variability, sleep, steps, active energy and body mass from your phone\'s health store. They stay on this device.';

  @override
  String get healthWriteWorkouts => 'Save workouts to Health';

  @override
  String get healthWriteWorkoutsOn => 'Saving how long you train, and nothing else';

  @override
  String get healthWriteWorkoutsOff => 'Off · Heart is not saving your workouts';

  @override
  String get healthSleep => 'Sleep';

  @override
  String get healthSteps => 'Steps';

  @override
  String get deleteWorkoutTitle => 'Do you want to delete this workout?';

  @override
  String get deleteWorkoutBody => 'This cannot be undone';

  @override
  String get importData => 'Import workout history';

  @override
  String get importPreviewTitle => 'Ready to import';

  @override
  String importPreviewSummary(num workouts, num sets) {
    String _temp0 = intl.Intl.pluralLogic(
      workouts,
      locale: localeName,
      other: '$workouts workouts',
      one: '1 workout',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sets,
      locale: localeName,
      other: '$sets sets',
      one: '1 set',
    );
    return '$_temp0 and $_temp1 ready to come over';
  }

  @override
  String importPreviewSummaryPartial(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts are new',
      one: '1 workout is new',
    );
    return '$_temp0';
  }

  @override
  String importPreviewNothingNew(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'all $count workouts in this file are',
      one: 'the 1 workout in this file is',
    );
    return 'Nothing new — $_temp0 already here';
  }

  @override
  String importPreviewMatched(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises already match the library',
      one: '1 exercise already matches the library',
    );
    return '$_temp0';
  }

  @override
  String importPreviewAlreadyHere(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts are already here — they will be skipped',
      one: '1 workout is already here — it will be skipped',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get importConsentTitle => 'New exercises found';

  @override
  String get importConsentBody =>
      'These didn\'t match anything in the library. Check the ones to bring over as your own custom exercises — anything unchecked stays behind, along with its sets.';

  @override
  String get importAction => 'Import';

  @override
  String importSetsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String importSkippedSets(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets stayed behind',
      one: '1 set stayed behind',
    );
    return '$_temp0 with the exercises you declined';
  }

  @override
  String get yourData => 'Your data';

  @override
  String get account => 'Account';

  @override
  String get app => 'App';

  @override
  String get importExplainerStrong =>
      'Lifted with Strong before? Bring your history along.\n\nIn the Strong app, go to Profile → Settings → Export Strong Data. It emails you a CSV file — save it, then pick it here.';

  @override
  String get importSafeToRetry =>
      'Everything comes over — workouts, sets, exercises. Importing the same file twice is safe: anything already here is skipped, never duplicated.';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get csvFiles => 'CSV files';

  @override
  String get importInFlight => 'Importing — hang tight…';

  @override
  String get importFailedHeadline => 'That file didn\'t work';

  @override
  String get importFailedBody =>
      'It couldn\'t be read as a Strong export. Pick the CSV file from Strong\'s export email and try again.';

  @override
  String get importReportTitle => 'Imported!';

  @override
  String importedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts imported',
      one: '1 workout imported',
      zero: 'No new workouts',
    );
    return '$_temp0';
  }

  @override
  String importSkippedWorkouts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workouts were already here — skipped',
      one: '1 workout was already here — skipped',
    );
    return '$_temp0';
  }

  @override
  String importedSets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0 in all';
  }

  @override
  String importSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 couldn\'t be read';
  }

  @override
  String get importNewExercisesHeader => 'New custom exercises';

  @override
  String get importNewExercisesBody =>
      'These didn\'t match anything in the library, so they came over as your custom exercises:';
}
