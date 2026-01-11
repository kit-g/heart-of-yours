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
  String get customThemeColorSetting => 'Custom theme color';

  @override
  String get customThemeColorSettingSubtitle => 'Used to generate a new theme';

  @override
  String get aboutApp => 'About app';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get congratulationsBody => 'Your workout is complete!';

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
  String get about => 'About';

  @override
  String get records => 'Records';

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
  String get logInBody => 'You\'ve already started something important. \r\nLet\'s keep going.';

  @override
  String get signUpTitle => 'Begin with Heart';

  @override
  String get signUpBody => 'Every journey starts with one decision. \r\nThis one\'s yours.';

  @override
  String get recoverTitle => 'Still with You';

  @override
  String get recoverBody => 'Your journey isn\'t lost. \r\nJust a moment of pause — we\'ll reset together.';

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
      'This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\r\n Archiving won\'t affect any of your past workouts — your history stays intact.';

  @override
  String get exerciseArchived => 'This exercise is archived \r\nand won\'t appear in your main library anymore.';

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
  String get customThemeColorSetting => 'Custom theme colour';

  @override
  String get customThemeColorSettingSubtitle => 'Used to generate a new theme';

  @override
  String get aboutApp => 'About app';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get congratulationsBody => 'Your workout is complete!';

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
    return 'Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\r\n\r\nWe love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. $emoji';
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
    return 'Your account has been scheduled for deletion on $date.\r\n\r\nIf you change your mind, you can restore your account anytime before this date.\r\n\r\nSimply click the button below to cancel the deletion and keep your account safe.';
  }

  @override
  String get accountDeletedAction => '🔥🏆 Undo the Goodbye 🥇🔥';

  @override
  String get about => 'About';

  @override
  String get records => 'Records';

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
      'There\'s an important update waiting — one that keeps your app working as it should.\r\n\r\nYou\'ll need to install it before continuing.\r\nThanks for your patience — and sorry for the interruption.';

  @override
  String updateRequiredCta(String storeName) {
    return 'Update on the $storeName';
  }

  @override
  String get addPhoto => 'Add photo';

  @override
  String get editWorkoutName => 'Edit workout name';

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
}
