// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en_CA locale. All the
// messages from the main program should be duplicated here with the same
// function name.
// @dart=2.12
// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = MessageLookup();

typedef String? MessageIfAbsent(
    String? messageStr, List<Object>? args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'en_CA';

  static m0(date) => "Your account has been scheduled for deletion on ${date}.\n\nIf you change your mind, you can restore your account anytime before this date.\n\nSimply click the button below to cancel the deletion and keep your account safe.";

  static m1(exerciseName) => "Archive ${exerciseName}?";

  static m2(deadline) => "Your account is scheduled for deletion in ${deadline} days. During this time, you can still sign in and reverse this decision. Once the deadline has passed, your account and personal data will be permanently deleted.";

  static m3(address) => "An account with ${address} already exists. Would you like to log in instead?";

  static m4(exercise) => "for ${exercise}";

  static m5(howMany) => "${Intl.plural(howMany, one: '${howMany} lb', other: '${howMany} lbs')}";

  static m6(emoji) => "Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\n\nWe love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. So thanks. Seriously. ${emoji}";

  static m7(howMany) => "${Intl.plural(howMany, one: '${howMany} mile', other: '${howMany} miles')}";

  static m8(exercise) => "Next: ${exercise}";

  static m9(count) => "Selected ${count}";

  static m10(weight, reps) => "${weight} x ${reps}";

  @override
  final Map<String, dynamic> messages = _notInlinedMessages(_notInlinedMessages);

  static Map<String, dynamic> _notInlinedMessages(Object? _) => {
      'about': MessageLookupByLibrary.simpleMessage('About'),
    'aboutApp': MessageLookupByLibrary.simpleMessage('About app'),
    'accountControl': MessageLookupByLibrary.simpleMessage('Account control'),
    'accountDeleted': MessageLookupByLibrary.simpleMessage('Account deleted'),
    'accountDeletedAction': MessageLookupByLibrary.simpleMessage('🔥🏆 Undo the Goodbye 🥇🔥'),
    'accountDeletedBody': m0,
    'add': MessageLookupByLibrary.simpleMessage('Add'),
    'addExercises': MessageLookupByLibrary.simpleMessage('Add exercises'),
    'addNote': MessageLookupByLibrary.simpleMessage('Add a note'),
    'addSeconds': MessageLookupByLibrary.simpleMessage('+10s'),
    'addSet': MessageLookupByLibrary.simpleMessage('Add set'),
    'afternoonWorkout': MessageLookupByLibrary.simpleMessage('Afternoon Workout'),
    'appearance': MessageLookupByLibrary.simpleMessage('Appearance'),
    'archive': MessageLookupByLibrary.simpleMessage('Archive'),
    'archiveConfirmBody': MessageLookupByLibrary.simpleMessage('This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\n Archiving won\'t affect any of your past workouts — your history stays intact.'),
    'archiveConfirmTitle': m1,
    'archivedExercises': MessageLookupByLibrary.simpleMessage('Archived exercises'),
    'cancel': MessageLookupByLibrary.simpleMessage('Cancel'),
    'cancelAndStartNewWorkout': MessageLookupByLibrary.simpleMessage('Yes, cancel that one and start a new workout'),
    'cancelCurrentWorkoutBody': MessageLookupByLibrary.simpleMessage('You have a workout in progress. Do you want to cancel it and start a new one?'),
    'cancelCurrentWorkoutTitle': MessageLookupByLibrary.simpleMessage('Cancel current workout?'),
    'cancelTimer': MessageLookupByLibrary.simpleMessage('Cancel timer'),
    'cancelWorkout': MessageLookupByLibrary.simpleMessage('Cancel workout'),
    'cancelWorkoutBody': MessageLookupByLibrary.simpleMessage('All progress made so far will be lost.'),
    'cancelWorkoutTitle': MessageLookupByLibrary.simpleMessage('Do you want to cancel this workout?'),
    'cannotBeEmpty': MessageLookupByLibrary.simpleMessage('Cannot be empty'),
    'capturePhoto': MessageLookupByLibrary.simpleMessage('Take a new photo'),
    'category': MessageLookupByLibrary.simpleMessage('Category'),
    'changeName': MessageLookupByLibrary.simpleMessage('Change name'),
    'changesWillBeLost': MessageLookupByLibrary.simpleMessage('All changes will be lost'),
    'charts': MessageLookupByLibrary.simpleMessage('Charts'),
    'chooseFromGallery': MessageLookupByLibrary.simpleMessage('Choose from library'),
    'confirmDeleteAccountCancelMessage': MessageLookupByLibrary.simpleMessage('Changed my mind, cancel'),
    'confirmDeleteAccountOkMessage': MessageLookupByLibrary.simpleMessage('Farewell!'),
    'confirmDeleteAccountTitle': MessageLookupByLibrary.simpleMessage('Confirm your account deletion'),
    'congratulations': MessageLookupByLibrary.simpleMessage('Congratulations!'),
    'congratulationsBody': MessageLookupByLibrary.simpleMessage('Your workout is complete!'),
    'createNewExercise': MessageLookupByLibrary.simpleMessage('Create new exercise'),
    'cropAvatar': MessageLookupByLibrary.simpleMessage('Crop avatar'),
    'customThemeColorSetting': MessageLookupByLibrary.simpleMessage('Custom theme color'),
    'customThemeColorSettingSubtitle': MessageLookupByLibrary.simpleMessage('Used to generate a new theme'),
    'dangerZone': MessageLookupByLibrary.simpleMessage('Danger zone'),
    'delete': MessageLookupByLibrary.simpleMessage('Delete'),
    'deleteAccount': MessageLookupByLibrary.simpleMessage('Delete account'),
    'deleteAccountBody': m2,
    'deleteAccountCancelMessage': MessageLookupByLibrary.simpleMessage('Oh no, I like it here!'),
    'deleteAccountConfirmMessage': MessageLookupByLibrary.simpleMessage('Yep, go on without me!'),
    'deleteAccountTitle': MessageLookupByLibrary.simpleMessage('Are you sure you want to delete your account?'),
    'deleteSet': MessageLookupByLibrary.simpleMessage('Delete set'),
    'deleteTemplateBody': MessageLookupByLibrary.simpleMessage('This cannot be undone'),
    'deleteTemplateTitle': MessageLookupByLibrary.simpleMessage('Do you want to delete this workout template?'),
    'deleteThis': MessageLookupByLibrary.simpleMessage('Yes, delete this'),
    'deleted': MessageLookupByLibrary.simpleMessage('Deleted'),
    'distanceUnit': MessageLookupByLibrary.simpleMessage('Distance'),
    'duration': MessageLookupByLibrary.simpleMessage('Duration'),
    'edit': MessageLookupByLibrary.simpleMessage('Edit'),
    'editTemplate': MessageLookupByLibrary.simpleMessage('Edit Template'),
    'editWorkout': MessageLookupByLibrary.simpleMessage('Edit Workout'),
    'email': MessageLookupByLibrary.simpleMessage('Email'),
    'emailExistsBody': m3,
    'emailExistsCancelButton': MessageLookupByLibrary.simpleMessage('No, I got this'),
    'emailExistsOkButton': MessageLookupByLibrary.simpleMessage('Yes, sign me in!'),
    'emailExistsTitle': MessageLookupByLibrary.simpleMessage('Email already exists'),
    'emptyExerciseHistoryBody': MessageLookupByLibrary.simpleMessage('Your exercise history is emptier than a gym on a Monday morning. Time to fill it up with some glorious PRs!'),
    'emptyExerciseHistoryTitle': MessageLookupByLibrary.simpleMessage('Ghost Reps Detected 👻'),
    'emptyHistoryBody': MessageLookupByLibrary.simpleMessage('Go get them done!'),
    'emptyHistoryTitle': MessageLookupByLibrary.simpleMessage('Your completed workouts will be here'),
    'errorExerciseHistoryBody': MessageLookupByLibrary.simpleMessage('Looks like the app tripped over its own shoelaces. Try again, and we promise to tie them tighter next time!'),
    'errorExerciseHistoryTitle': MessageLookupByLibrary.simpleMessage('Oops! Someone Skipped the Data Day 🤷‍♀️'),
    'eveningWorkout': MessageLookupByLibrary.simpleMessage('Evening Workout'),
    'exampleTemplates': MessageLookupByLibrary.simpleMessage('Example templates'),
    'exerciseArchived': MessageLookupByLibrary.simpleMessage('This exercise is archived \nand won\'t appear in your main library anymore.'),
    'exerciseOptions': MessageLookupByLibrary.simpleMessage('Exercise options'),
    'exercises': MessageLookupByLibrary.simpleMessage('Exercises'),
    'feedbackReceived': MessageLookupByLibrary.simpleMessage('Your feedback was received, thank you!'),
    'finish': MessageLookupByLibrary.simpleMessage('Finish'),
    'finishWorkoutBody': MessageLookupByLibrary.simpleMessage('Ready to finish this workout?'),
    'finishWorkoutTitle': MessageLookupByLibrary.simpleMessage('Finish Workout?'),
    'finishWorkoutWarningBody': MessageLookupByLibrary.simpleMessage('Any empty or invalid sets will be discarded, and all valid sets will be marked as completed.'),
    'finishWorkoutWarningTitle': MessageLookupByLibrary.simpleMessage('Complete Your Workout?'),
    'forExercise': m4,
    'forgotPassword': MessageLookupByLibrary.simpleMessage('Forgot password?'),
    'h': MessageLookupByLibrary.simpleMessage('h'),
    'hidePassword': MessageLookupByLibrary.simpleMessage('Hide password'),
    'history': MessageLookupByLibrary.simpleMessage('History'),
    'imperial': MessageLookupByLibrary.simpleMessage('Imperial'),
    'invalidCredentials': MessageLookupByLibrary.simpleMessage('Well, that didn\'t work! Double-check your details, eh?'),
    'keepCurrentAccount': MessageLookupByLibrary.simpleMessage('No, keep current workout'),
    'kg': MessageLookupByLibrary.simpleMessage('kg'),
    'km': MessageLookupByLibrary.simpleMessage('km'),
    'lb': m5,
    'lbs': MessageLookupByLibrary.simpleMessage('lbs'),
    'leaveFeedback': MessageLookupByLibrary.simpleMessage('Leave feedback'),
    'leaveFeedbackBody': m6,
    'logIn': MessageLookupByLibrary.simpleMessage('Log in'),
    'logInBody': MessageLookupByLibrary.simpleMessage('You\'ve already started something important. \nLet\'s keep going.'),
    'logInTitle': MessageLookupByLibrary.simpleMessage('Welcome Back'),
    'logInWithApple': MessageLookupByLibrary.simpleMessage('Log in with Apple'),
    'logInWithGoogle': MessageLookupByLibrary.simpleMessage('Log in with Google'),
    'logOut': MessageLookupByLibrary.simpleMessage('Log out'),
    'maxDistance': MessageLookupByLibrary.simpleMessage('Max distance'),
    'maxDuration': MessageLookupByLibrary.simpleMessage('Max duration'),
    'maxReps': MessageLookupByLibrary.simpleMessage('Max reps'),
    'maxWeight': MessageLookupByLibrary.simpleMessage('Max weight'),
    'metric': MessageLookupByLibrary.simpleMessage('Metric'),
    'mile': MessageLookupByLibrary.simpleMessage('mile'),
    'miles': m7,
    'milesPlural': MessageLookupByLibrary.simpleMessage('miles'),
    'min': MessageLookupByLibrary.simpleMessage('min'),
    'morningWorkout': MessageLookupByLibrary.simpleMessage('Morning Workout'),
    'motto': MessageLookupByLibrary.simpleMessage('Every beat counts.'),
    'name': MessageLookupByLibrary.simpleMessage('Name'),
    'nameOptional': MessageLookupByLibrary.simpleMessage('Name (optional)'),
    'newExercise': MessageLookupByLibrary.simpleMessage('New exercise'),
    'newTemplate': MessageLookupByLibrary.simpleMessage('New Template'),
    'nightWorkout': MessageLookupByLibrary.simpleMessage('Night Workout'),
    'noConnectivity': MessageLookupByLibrary.simpleMessage('Uh-oh! The internet tripped over a dumbbell. 🏋️‍♂️ Try again in a sec!'),
    'notReadyToFinish': MessageLookupByLibrary.simpleMessage('No, one more set!'),
    'notificationSettings': MessageLookupByLibrary.simpleMessage('Notification settings'),
    'ok': MessageLookupByLibrary.simpleMessage('OK'),
    'okBang': MessageLookupByLibrary.simpleMessage('Ok!'),
    'orConnector': MessageLookupByLibrary.simpleMessage('- or -'),
    'password': MessageLookupByLibrary.simpleMessage('Password'),
    'personalRecords': MessageLookupByLibrary.simpleMessage('Personal records'),
    'previous': MessageLookupByLibrary.simpleMessage('Previous'),
    'profile': MessageLookupByLibrary.simpleMessage('Profile'),
    'quitEditing': MessageLookupByLibrary.simpleMessage('Quit editing?'),
    'quitPage': MessageLookupByLibrary.simpleMessage('Quit this page'),
    'readyToFinish': MessageLookupByLibrary.simpleMessage('Yes, I\'m done!'),
    'records': MessageLookupByLibrary.simpleMessage('Records'),
    'recoverBody': MessageLookupByLibrary.simpleMessage('Your journey isn\'t lost. \nJust a moment of pause — we\'ll reset together.'),
    'recoverTitle': MessageLookupByLibrary.simpleMessage('Still with You'),
    'recoveryLinkMessage': MessageLookupByLibrary.simpleMessage('If an account exists for this email, you\'ll receive a reset link shortly. Check your inbox and spam folder.'),
    'recoveryLinkMessageSent': MessageLookupByLibrary.simpleMessage('💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide).'),
    'removeCurrentPhoto': MessageLookupByLibrary.simpleMessage('Remove current photo'),
    'removeExercise': MessageLookupByLibrary.simpleMessage('Remove exercise'),
    'removeFilter': MessageLookupByLibrary.simpleMessage('Remove filter'),
    'repeat': MessageLookupByLibrary.simpleMessage('Repeat'),
    'replaceExercise': MessageLookupByLibrary.simpleMessage('Replace exercise'),
    'reps': MessageLookupByLibrary.simpleMessage('Reps'),
    'reset': MessageLookupByLibrary.simpleMessage('Reset'),
    'resetPassword': MessageLookupByLibrary.simpleMessage('Reset password'),
    'resetPasswordBody': MessageLookupByLibrary.simpleMessage('We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌'),
    'restComplete': MessageLookupByLibrary.simpleMessage('Rest complete!'),
    'restCompleteBody': m8,
    'restTimer': MessageLookupByLibrary.simpleMessage('Rest timer'),
    'restTimerSubtitle': MessageLookupByLibrary.simpleMessage('Adjust duration via the +/- buttons.'),
    'resumeWorkout': MessageLookupByLibrary.simpleMessage('No, resume workout'),
    'save': MessageLookupByLibrary.simpleMessage('Save'),
    'saveAsTemplate': MessageLookupByLibrary.simpleMessage('Save as template'),
    'saveName': MessageLookupByLibrary.simpleMessage('Save name'),
    'search': MessageLookupByLibrary.simpleMessage('Search'),
    'selected': m9,
    'sendResetLink': MessageLookupByLibrary.simpleMessage('Send Reset Link'),
    'sendResetLinkBody': MessageLookupByLibrary.simpleMessage('Enter you email and we\'ll help you reset your password'),
    'set': MessageLookupByLibrary.simpleMessage('Set'),
    'sets': MessageLookupByLibrary.simpleMessage('Sets'),
    'settings': MessageLookupByLibrary.simpleMessage('Settings'),
    'share': MessageLookupByLibrary.simpleMessage('Share'),
    'showArchived': MessageLookupByLibrary.simpleMessage('Show archived'),
    'showPassword': MessageLookupByLibrary.simpleMessage('Show password'),
    'signUp': MessageLookupByLibrary.simpleMessage('Sign up'),
    'signUpBody': MessageLookupByLibrary.simpleMessage('Every journey starts with one decision. \nThis one\'s yours.'),
    'signUpTitle': MessageLookupByLibrary.simpleMessage('Begin with Heart'),
    'signUpWithApple': MessageLookupByLibrary.simpleMessage('Sign up with Apple'),
    'signUpWithGoogle': MessageLookupByLibrary.simpleMessage('Sign up with Google'),
    'skip': MessageLookupByLibrary.simpleMessage('Skip'),
    'startNewWorkout': MessageLookupByLibrary.simpleMessage('Start a new workout'),
    'startNewWorkoutFromTemplate': MessageLookupByLibrary.simpleMessage('Start a new workout from this template?'),
    'startWorkout': MessageLookupByLibrary.simpleMessage('Start workout'),
    'stayHere': MessageLookupByLibrary.simpleMessage('Stay here'),
    'subtractSeconds': MessageLookupByLibrary.simpleMessage('-10s'),
    'target': MessageLookupByLibrary.simpleMessage('Target'),
    'template': MessageLookupByLibrary.simpleMessage('Template'),
    'templateName': MessageLookupByLibrary.simpleMessage('Template name'),
    'templates': MessageLookupByLibrary.simpleMessage('Templates'),
    'time': MessageLookupByLibrary.simpleMessage('Time'),
    'toDarkMode': MessageLookupByLibrary.simpleMessage('Dark'),
    'toFeedback': MessageLookupByLibrary.simpleMessage('To feedback!'),
    'toLightMode': MessageLookupByLibrary.simpleMessage('Light'),
    'toSystemMode': MessageLookupByLibrary.simpleMessage('System'),
    'unarchive': MessageLookupByLibrary.simpleMessage('Unarchive'),
    'units': MessageLookupByLibrary.simpleMessage('Units'),
    'unknownError': MessageLookupByLibrary.simpleMessage('Unknown error occurred'),
    'userDisabled': MessageLookupByLibrary.simpleMessage('This account is disabled'),
    'weakPassword': MessageLookupByLibrary.simpleMessage('Almost there! Try a stronger password to keep your account safe.'),
    'weightUnit': MessageLookupByLibrary.simpleMessage('Weight'),
    'weightedSetRepresentation': m10,
    'workout': MessageLookupByLibrary.simpleMessage('Workout'),
    'workoutName': MessageLookupByLibrary.simpleMessage('Workout name'),
    'workoutsPerWeek': MessageLookupByLibrary.simpleMessage('Workouts per week'),
    'workoutsPerWeekBody': MessageLookupByLibrary.simpleMessage('Go get them done!'),
    'workoutsPerWeekTitle': MessageLookupByLibrary.simpleMessage('Your workouts will be presented here'),
    'yourEmail': MessageLookupByLibrary.simpleMessage('Your email'),
    'yourPassword': MessageLookupByLibrary.simpleMessage('Your password')
  };
}
