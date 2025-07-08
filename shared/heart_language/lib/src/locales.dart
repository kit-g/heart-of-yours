import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/messages_all.dart';

class L {
  static Future<L> load(Locale locale) {
    final name = locale.countryCode!.isEmpty ? locale.languageCode : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return L();
    });
  }

  static L of(BuildContext context) => Localizations.of<L>(context, L)!;

  String get appearance {
    return Intl.message(
      'Appearance',
      name: 'appearance',
      desc: 'Label',
    );
  }

  String get units {
    return Intl.message(
      'Units',
      name: 'units',
      desc: 'Label',
    );
  }

  String get motto {
    return Intl.message(
      'Every beat counts.',
      name: 'motto',
      desc: 'App\'s motto',
    );
  }

  String get toLightMode {
    return Intl.message(
      'Light',
      name: 'toLightMode',
      desc: 'tooltip',
    );
  }

  String get toDarkMode {
    return Intl.message(
      'Dark',
      name: 'toDarkMode',
      desc: 'tooltip',
    );
  }

  String get toSystemMode {
    return Intl.message(
      'System',
      name: 'toSystemMode',
      desc: 'tooltip',
    );
  }

  String get email {
    return Intl.message(
      'Email',
      name: 'email',
      desc: 'Generic label',
    );
  }

  String get yourEmail {
    return Intl.message(
      'Your email',
      name: 'yourEmail',
      desc: 'Generic label',
    );
  }

  String get cropAvatar {
    return Intl.message(
      'Crop avatar',
      name: 'cropAvatar',
      desc: 'Label in the image cropper',
    );
  }

  String get nameOptional {
    return Intl.message(
      'Name (optional)',
      name: 'nameOptional',
      desc: 'Field hint',
    );
  }

  String get name {
    return Intl.message(
      'Name',
      name: 'name',
      desc: 'Field hint',
    );
  }

  String get saveName {
    return Intl.message(
      'Save name',
      name: 'saveName',
      desc: 'Hint',
    );
  }

  String get changeName {
    return Intl.message(
      'Change name',
      name: 'changeName',
      desc: 'Hint',
    );
  }

  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: 'Generic label',
    );
  }

  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: 'Generic label',
    );
  }

  String get archive {
    return Intl.message(
      'Archive',
      name: 'archive',
      desc: 'CTA, verb',
    );
  }

  String get unarchive {
    return Intl.message(
      'Unarchive',
      name: 'unarchive',
      desc: 'CTA, verb',
    );
  }

  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: 'Generic label',
    );
  }

  String get logIn {
    return Intl.message(
      'Log in',
      name: 'login',
      desc: 'Generic label',
    );
  }

  String get logInTitle {
    return Intl.message(
      'Welcome Back',
      name: 'logInTitle',
      desc: 'Login page copy',
    );
  }

  String get logInBody {
    return Intl.message(
      'You’ve already started something important. \nLet’s keep going.',
      name: 'logInBody',
      desc: 'Login page copy',
    );
  }

  String get signUpTitle {
    return Intl.message(
      'Begin with Heart',
      name: 'signUpTitle',
      desc: 'Sign up page copy',
    );
  }

  String get signUpBody {
    return Intl.message(
      'Every journey starts with one decision. \nThis one’s yours.',
      name: 'signUpBody',
      desc: 'Sign up page copy',
    );
  }

  String get recoverTitle {
    return Intl.message(
      'Still with You',
      name: 'recoverTitle',
      desc: 'Recover page copy',
    );
  }

  String get recoverBody {
    return Intl.message(
      'Your journey isn’t lost. \nJust a moment of pause — we’ll reset together.',
      name: 'recoverBody',
      desc: 'Recover page copy',
    );
  }

  String get logInWithGoogle {
    return Intl.message(
      'Log in with Google',
      name: 'logInWithGoogle',
      desc: 'Button label',
    );
  }

  String get signUpWithGoogle {
    return Intl.message(
      'Sign up with Google',
      name: 'signUpWithGoogle',
      desc: 'Button label',
    );
  }

  String get logInWithApple {
    return Intl.message(
      'Log in with Apple',
      name: 'logInWithApple',
      desc: 'Button label',
    );
  }

  String get signUpWithApple {
    return Intl.message(
      'Sign up with Apple',
      name: 'signUpWithApple',
      desc: 'Button label',
    );
  }

  String get logOut {
    return Intl.message(
      'Log out',
      name: 'logOut',
      desc: 'Generic label',
    );
  }

  String get profile {
    return Intl.message(
      'Profile',
      name: 'profile',
      desc: 'Generic label, e.g. bottom nav bar',
    );
  }

  String get workout {
    return Intl.message(
      'Workout',
      name: 'workout',
      desc: 'Generic label, e.g. bottom nav bar',
    );
  }

  String get history {
    return Intl.message(
      'History',
      name: 'history',
      desc: 'Generic label, e.g. bottom nav bar',
    );
  }

  String get exercises {
    return Intl.message(
      'Exercises',
      name: 'exercises',
      desc: 'Generic label, e.g. bottom nav bar',
    );
  }

  String get search {
    return Intl.message(
      'Search',
      name: 'search',
      desc: 'Generic label, e.g. bin the search bar',
    );
  }

  String get startNewWorkout {
    return Intl.message(
      'Start a new workout',
      name: 'startNewWorkout',
      desc: 'Button label',
    );
  }

  String get cancelCurrentWorkoutTitle {
    return Intl.message(
      'Cancel current workout?',
      name: 'cancelCurrentWorkoutTitle',
      desc: 'Button label',
    );
  }

  String get cancelCurrentWorkoutBody {
    return Intl.message(
      'You have a workout in progress. Do you want to cancel it and start a new one?',
      name: 'cancelCurrentWorkoutBody',
      desc: 'Button label',
    );
  }

  String get startNewWorkoutFromTemplate {
    return Intl.message(
      'Start a new workout from this template?',
      name: 'startNewWorkoutFromTemplate',
      desc: 'Alert dialog',
    );
  }

  String get startWorkout {
    return Intl.message(
      'Start workout',
      name: 'startWorkout',
      desc: 'App bar title',
    );
  }

  String get cancelWorkout {
    return Intl.message(
      'Cancel workout',
      name: 'cancelWorkout',
      desc: 'Button text',
    );
  }

  String get addExercises {
    return Intl.message(
      'Add exercises',
      name: 'addExercises',
      desc: 'Button text',
    );
  }

  String get addSet {
    return Intl.message(
      'Add set',
      name: 'addSet',
      desc: 'Button text',
    );
  }

  String get newExercise {
    return Intl.message(
      'New exercise',
      name: 'newExercise',
      desc: 'Button tooltip',
    );
  }

  String get createNewExercise {
    return Intl.message(
      'Create new exercise',
      name: 'createNewExercise',
      desc: 'Dialog header',
    );
  }

  String get exerciseOptions {
    return Intl.message(
      'Exercise options',
      name: 'exerciseOptions',
      desc: 'Button tooltip',
    );
  }

  String get showArchived {
    return Intl.message(
      'Show archived',
      name: 'showArchived',
      desc: 'Menu button, as in "Show archived exercises',
    );
  }

  String get archivedExercises {
    return Intl.message(
      'Archived exercises',
      name: 'archivedExercises',
      desc: 'App bar',
    );
  }

  String archiveConfirmTitle(String exerciseName) {
    return Intl.message(
      'Archive $exerciseName?',
      name: 'archiveConfirmTitle',
      desc: 'Dialog title, e.g., "Archive Push ups?"',
      args: [exerciseName],
    );
  }

  String get archiveConfirmBody {
    return Intl.message(
      'This exercise will be moved to Archived Exercises (find it under Exercises → More → Show archived).\n Archiving won’t affect any of your past workouts — your history stays intact.',
      name: 'archiveConfirm',
      desc: 'Dialog body',
    );
  }

  String get exerciseArchived {
    return Intl.message(
      'This exercise is archived \nand won’t appear in your main library anymore.',
      name: 'exerciseArchived',
      desc: 'Tooltip over archived icon',
    );
  }

  String get deleteSet {
    return Intl.message(
      'Delete set',
      name: 'deleteSet',
      desc: 'Button text',
    );
  }

  String get set {
    return Intl.message(
      'Set',
      name: 'set',
      desc: 'Workout table, column header',
    );
  }

  String get sets {
    return Intl.message(
      'Sets',
      name: 'sets',
      desc: 'Card header',
    );
  }

  String get previous {
    return Intl.message(
      'Previous',
      name: 'previous',
      desc: 'Workout table, column header, as in "previous exercise"',
    );
  }

  String get reps {
    return Intl.message(
      'Reps',
      name: 'reps',
      desc: 'Workout table, column header',
    );
  }

  String get time {
    return Intl.message(
      'Time',
      name: 'time',
      desc: 'Workout table, column header',
    );
  }

  String get kg {
    return Intl.message(
      'kg',
      name: 'kg',
      desc: 'Generic label, kilograms',
    );
  }

  String get mile {
    return Intl.message(
      'mile',
      name: 'mile',
      desc: 'Generic label, miles',
    );
  }

  String get km {
    return Intl.message(
      'km',
      name: 'km',
      desc: 'Generic label, km',
    );
  }

  String get milesPlural {
    return Intl.message(
      'miles',
      name: 'milePlural',
      desc: 'Generic label, miles',
    );
  }

  String miles(int howMany) {
    return Intl.plural(
      howMany,
      one: '$howMany mile',
      other: '$howMany miles',
      name: 'miles',
      desc: 'Generic label, miles',
    );
  }

  String get ok {
    return Intl.message(
      'OK',
      name: 'ok',
      desc: 'Generic label',
    );
  }

  String get edit {
    return Intl.message(
      'Edit',
      name: 'edit',
      desc: 'Generic label',
    );
  }

  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: 'Generic label',
    );
  }

  String get repeat {
    return Intl.message(
      'Repeat',
      name: 'repeat',
      desc: 'Generic label',
    );
  }

  String get add {
    return Intl.message(
      'Add',
      name: 'add',
      desc: 'Generic label',
    );
  }

  String get share {
    return Intl.message(
      'Share',
      name: 'share',
      desc: 'Generic label',
    );
  }

  String get okBang {
    return Intl.message(
      'Ok!',
      name: 'okBang',
      desc: 'Generic label',
    );
  }

  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: 'Generic label, "cancel" button',
    );
  }

  String get finish {
    return Intl.message(
      'Finish',
      name: 'finish',
      desc: 'Generic label, "finish workout" button',
    );
  }

  String get reset {
    return Intl.message(
      'Reset',
      name: 'reset',
      desc: 'Generic label, "Reset" button',
    );
  }

  String get h {
    return Intl.message(
      'h',
      name: 'h',
      desc: 'Abbreviation for "hours"',
    );
  }

  String get min {
    return Intl.message(
      'min',
      name: 'min',
      desc: 'Abbreviation for "minutes"',
    );
  }

  String get lbs {
    return Intl.message(
      'lbs',
      name: 'lbs',
      desc: 'Generic label, pounds',
    );
  }

  String get skip {
    return Intl.message(
      'Skip',
      name: 'skip',
      desc: 'Generic label, verb',
    );
  }

  String lb(int howMany) {
    return Intl.plural(
      howMany,
      one: '$howMany lb',
      other: '$howMany lbs',
      name: 'lbs',
      desc: 'Generic label, pounds',
    );
  }

  String get saveAsTemplate {
    return Intl.message(
      'Save as template',
      name: 'saveAsTemplate',
      desc: 'Workout set option, "save this workout as a template"',
    );
  }

  String get addNote {
    return Intl.message(
      'Add a note',
      name: 'addNote',
      desc: 'Exercise set option, "add a note to this set"',
    );
  }

  String get replaceExercise {
    return Intl.message(
      'Replace exercise',
      name: 'replaceExercise',
      desc: 'Exercise set option',
    );
  }

  String get weightUnit {
    return Intl.message(
      'Weight',
      name: 'weightUnit',
      desc: 'Exercise set option, "choose weight unit for this set"',
    );
  }

  String get distanceUnit {
    return Intl.message(
      'Distance',
      name: 'distanceUnit',
      desc: 'Exercise set option, "choose distance unit for this set"',
    );
  }

  String get duration {
    return Intl.message(
      'Duration',
      name: 'duration',
      desc: 'Duration label',
    );
  }

  String get imperial {
    return Intl.message(
      'Imperial',
      name: 'imperial',
      desc: 'Measurement unit setting',
    );
  }

  String get metric {
    return Intl.message(
      'Metric',
      name: 'metric',
      desc: 'Measurement unit setting',
    );
  }

  String get restTimer {
    return Intl.message(
      'Rest timer',
      name: 'restTimer',
      desc: 'Exercise set option, "Set the rest timer for this exercise"',
    );
  }

  String get cancelTimer {
    return Intl.message(
      'Cancel timer',
      name: 'cancelTimer',
      desc: 'Button text',
    );
  }

  String get removeExercise {
    return Intl.message(
      'Remove exercise',
      name: 'removeExercise',
      desc: 'Exercise set option, "Remove this exercise from workout"',
    );
  }

  String get morningWorkout {
    return Intl.message(
      'Morning Workout',
      name: 'morningWorkout',
      desc: 'Default workout name',
    );
  }

  String get eveningWorkout {
    return Intl.message(
      'Evening Workout',
      name: 'eveningWorkout',
      desc: 'Default workout name',
    );
  }

  String get nightWorkout {
    return Intl.message(
      'Night Workout',
      name: 'nightWorkout',
      desc: 'Default workout name',
    );
  }

  String get afternoonWorkout {
    return Intl.message(
      'Afternoon Workout',
      name: 'afternoonWorkout',
      desc: 'Default workout name',
    );
  }

  String get emptyHistoryTitle {
    return Intl.message(
      'Your completed workouts will be here',
      name: 'emptyHistoryTitle',
      desc: 'emptyHistoryTitle',
    );
  }

  String get emptyHistoryBody {
    return Intl.message(
      'Go get them done!',
      name: 'emptyHistoryBody',
      desc: 'emptyHistoryBody',
    );
  }

  String get customThemeColorSetting {
    return Intl.message(
      'Custom theme color',
      name: 'customThemeColorSetting',
      desc: 'Setting item name',
    );
  }

  String get customThemeColorSettingSubtitle {
    return Intl.message(
      'Used to generate a new theme',
      name: 'customThemeColorSettingSubtitle',
      desc: 'Setting item subtitle',
    );
  }

  String get aboutApp {
    return Intl.message(
      'About app',
      name: 'aboutApp',
      desc: 'Setting item title',
    );
  }

  String get congratulations {
    return Intl.message(
      'Congratulations!',
      name: 'congratulations',
      desc: 'Workout complete screen, title',
    );
  }

  String get congratulationsBody {
    return Intl.message(
      'Your workout is complete!',
      name: 'congratulationsBody',
      desc: 'Workout complete screen, body',
    );
  }

  String get finishWorkoutTitle {
    return Intl.message(
      'Finish Workout?',
      name: 'finishWorkoutTitle',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get finishWorkoutWarningTitle {
    return Intl.message(
      'Complete Your Workout?',
      name: 'finishWorkoutWarningTitle',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get finishWorkoutWarningBody {
    return Intl.message(
      'Any empty or invalid sets will be discarded, and all valid sets will be marked as completed.',
      name: 'finishWorkoutWarningBody',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get finishWorkoutBody {
    return Intl.message(
      'Ready to finish this workout?',
      name: 'finishWorkoutBody',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get cancelWorkoutBody {
    return Intl.message(
      'All progress made so far will be lost.',
      name: 'cancelWorkoutBody',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get cancelWorkoutTitle {
    return Intl.message(
      'Do you want to cancel this workout?',
      name: 'cancelWorkoutTitle',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get readyToFinish {
    return Intl.message(
      'Yes, I\'m done!',
      name: 'readyToFinish',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get keepCurrentAccount {
    return Intl.message(
      'No, keep current workout',
      name: 'keepCurrentAccount',
      desc: 'Workout start confirmation dialog',
    );
  }

  String get cancelAndStartNewWorkout {
    return Intl.message(
      'Yes, cancel that one and start a new workout',
      name: 'cancelAndStartNewWorkout',
      desc: 'Workout start confirmation dialog',
    );
  }

  String get resumeWorkout {
    return Intl.message(
      'No, resume workout',
      name: 'resumeWorkout',
      desc: 'Workout cancellation confirmation dialog',
    );
  }

  String get deleteThis {
    return Intl.message(
      'Yes, delete this',
      name: 'deleteThis',
      desc: 'Generic label',
    );
  }

  String get deleted {
    return Intl.message(
      'Deleted',
      name: 'deleted',
      desc: 'Generic label',
    );
  }

  String get notReadyToFinish {
    return Intl.message(
      'No, one more set!',
      name: 'notReadyToFinish',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get deleteTemplateTitle {
    return Intl.message(
      'Do you want to delete this workout template?',
      name: 'deleteTemplateTitle',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get deleteTemplateBody {
    return Intl.message(
      'This cannot be undone',
      name: 'deleteTemplateBody',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get quitEditing {
    return Intl.message(
      'Quit editing?',
      name: 'quitEditing',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get changesWillBeLost {
    return Intl.message(
      'All changes will be lost',
      name: 'changesWillBeLost',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get quitPage {
    return Intl.message(
      'Quit this page',
      name: 'quitPage',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get stayHere {
    return Intl.message(
      'Stay here',
      name: 'stayHere',
      desc: 'Template deletion confirmation dialog',
    );
  }

  String get notificationSettings {
    return Intl.message(
      'Notification settings',
      name: 'notificationSettings',
      desc: 'Settings item',
    );
  }

  String selected(int count) {
    return Intl.message(
      'Selected $count',
      name: 'selected',
      desc: 'Selected 4 exercises',
    );
  }

  String forExercise(String exercise) {
    return Intl.message(
      'for $exercise',
      name: 'forExercise',
      desc: 'As in "Rest timer for bicep curl"',
    );
  }

  String defaultWorkoutName() {
    return switch (DateTime.now().hour) {
      >= 5 && < 12 => morningWorkout,
      >= 12 && < 17 => afternoonWorkout,
      >= 17 && < 21 => eveningWorkout,
      _ => nightWorkout,
    };
  }

  String get restTimerSubtitle {
    return Intl.message(
      'Adjust duration via the +/- buttons.',
      name: 'restTimerSubtitle',
      desc: 'Rest timer',
    );
  }

  String get addSeconds {
    return Intl.message(
      '+10s',
      name: 'addSeconds',
      desc: 'Rest timer',
    );
  }

  String get subtractSeconds {
    return Intl.message(
      '-10s',
      name: 'subtractSeconds',
      desc: 'Rest timer',
    );
  }

  String get restComplete {
    return Intl.message(
      'Rest complete!',
      name: 'restComplete',
      desc: 'Rest notification banner',
    );
  }

  String get workoutsPerWeek {
    return Intl.message(
      'Workouts per week',
      name: 'workoutsPerWeek',
      desc: 'Chart label',
    );
  }

  String get workoutsPerWeekTitle {
    return Intl.message(
      'Your workouts will be presented here',
      name: 'workoutsPerWeekTitle',
      desc: 'Chart label',
    );
  }

  String get workoutsPerWeekBody {
    return Intl.message(
      'Go get them done!',
      name: 'workoutsPerWeekBody',
      desc: 'Chart label',
    );
  }

  String get category {
    return Intl.message(
      'Category',
      name: 'category',
      desc: 'Label button that allows to choose Exercise category',
    );
  }

  String get target {
    return Intl.message(
      'Target',
      name: 'target',
      desc: 'Label button that allows to choose Exercise target muscle group',
    );
  }

  String get removeFilter {
    return Intl.message(
      'Remove filter',
      name: 'removeFilter',
      desc: 'Tooltip on the button that removes exercise filter',
    );
  }

  String restCompleteBody(String exercise) {
    return Intl.message(
      'Next: $exercise',
      name: 'restCompleteBody',
      desc: 'Rest notification banner',
    );
  }

  String weightedSetRepresentation(String weight, int reps) {
    return Intl.message(
      '$weight x $reps',
      name: 'weightedSetRepresentation',
      desc: 'Rest notification banner',
      args: [weight, reps],
    );
  }

  String get templates {
    return Intl.message(
      'Templates',
      name: 'templates',
      desc: 'Workout templates section header',
    );
  }

  String get exampleTemplates {
    return Intl.message(
      'Example templates',
      name: 'exampleTemplates',
      desc: 'Workout templates section header',
    );
  }

  String get template {
    return Intl.message(
      'Template',
      name: 'template',
      desc: 'A single workout template',
    );
  }

  String get newTemplate {
    return Intl.message(
      'New Template',
      name: 'newTemplate',
      desc: 'New template form header',
    );
  }

  String get editTemplate {
    return Intl.message(
      'Edit Template',
      name: 'editTemplate',
      desc: 'Edit template form header',
    );
  }

  String get editWorkout {
    return Intl.message(
      'Edit Workout',
      name: 'editWorkout',
      desc: 'Edit workout form header',
    );
  }

  String get templateName {
    return Intl.message(
      'Template name',
      name: 'templateName',
      desc: 'Edit template text field hint',
    );
  }

  String get workoutName {
    return Intl.message(
      'Workout name',
      name: 'workoutName',
      desc: 'Edit workout text field hint',
    );
  }

  String get cannotBeEmpty {
    return Intl.message(
      'Cannot be empty',
      name: 'cannotBeEmpty',
      desc: 'Form validation message',
    );
  }

  String get showPassword {
    return Intl.message(
      'Show password',
      name: 'showPassword',
      desc: 'Tooltip message',
    );
  }

  String get hidePassword {
    return Intl.message(
      'Hide password',
      name: 'hidePassword',
      desc: 'Tooltip message',
    );
  }

  String get yourPassword {
    return Intl.message(
      'Your password',
      name: 'yourPassword',
      desc: 'Tooltip message',
    );
  }

  String get resetPassword {
    return Intl.message(
      'Reset password',
      name: 'resetPassword',
      desc: 'Button',
    );
  }

  String get resetPasswordBody {
    return Intl.message(
      'We’ll send a reset link to your email faster than you can say “forgot my password.” No turning back after this—unless you cancel, of course. 😌',
      name: 'resetPasswordBody',
      desc: 'Button',
    );
  }

  String get orConnector {
    return Intl.message(
      '- or -',
      name: 'orConnector',
      desc: 'Connects two widgets, this OR that',
    );
  }

  String get invalidCredentials {
    return Intl.message(
      'Well, that didn\'t work! Double-check your details, eh?',
      name: 'invalidCredentials',
      desc: 'Login error message',
    );
  }

  String get weakPassword {
    return Intl.message(
      'Almost there! Try a stronger password to keep your account safe.',
      name: 'invalidCredentials',
      desc: 'Login error message',
    );
  }

  String get forgotPassword {
    return Intl.message(
      'Forgot password?',
      name: 'forgotPassword',
      desc: 'Login button',
    );
  }

  String get noConnectivity {
    return Intl.message(
      'Uh-oh! The internet tripped over a dumbbell. 🏋️‍♂️ Try again in a sec!',
      name: 'noConnectivity',
      desc: 'Error message',
    );
  }

  String get signUp {
    return Intl.message(
      'Sign up',
      name: 'signUp',
      desc: 'Generic label',
    );
  }

  String get sendResetLink {
    return Intl.message(
      'Send Reset Link',
      name: 'sendResetLink',
      desc: 'Password recovery flow',
    );
  }

  String get recoveryLinkMessage {
    return Intl.message(
      'If an account exists for this email, you’ll receive a reset link shortly. Check your inbox and spam folder.',
      name: 'recoveryLinkMessage',
      desc: 'Password recovery flow',
    );
  }

  String get recoveryLinkMessageSent {
    return Intl.message(
      '💌Your password setup email is on its way! Check your inbox (or maybe your spam folder—it likes to hide).',
      name: 'recoveryLinkMessageSent',
      desc: 'Password recovery flow',
    );
  }

  String get emailExistsTitle {
    return Intl.message(
      'Email already exists',
      name: 'emailExistsTitle',
      desc: 'Email exists dialog',
    );
  }

  String get emailExistsOkButton {
    return Intl.message(
      'Yes, sign me in!',
      name: 'emailExistsOkButton',
      desc: 'Email exists dialog',
    );
  }

  String get emailExistsCancelButton {
    return Intl.message(
      'No, I got this',
      name: 'emailExistsCancelButton',
      desc: 'Email exists dialog',
    );
  }

  String emailExistsBody(String address) {
    return Intl.message(
      'An account with $address already exists. Would you like to log in instead?',
      name: 'emailExistsBody',
      desc: 'Email exists dialog',
      args: [address],
    );
  }

  String get sendResetLinkBody {
    return Intl.message(
      'Enter you email and we\'ll help you reset your password',
      name: 'sendResetLinkBody',
      desc: 'Password recovery flow',
    );
  }

  String get userDisabled {
    return Intl.message(
      'This account is disabled',
      name: 'userDisabled',
      desc: 'Login error message',
    );
  }

  String get unknownError {
    return Intl.message(
      'Unknown error occurred',
      name: 'unknownError',
      desc: 'Login error message',
    );
  }

  String get accountControl {
    return Intl.message(
      'Account control',
      name: 'accountControl',
      desc: 'Settings item',
    );
  }

  String get leaveFeedback {
    return Intl.message(
      'Leave feedback',
      name: 'leaveFeedback',
      desc: 'Settings item',
    );
  }

  String leaveFeedbackBody(String emoji) {
    return Intl.message(
      'Snap a screenshot, doodle your feelings, and drop us a note. You can roam the app while you\'re at it.\n\n'
      'We love feedback. Every squiggle and comment helps us make the app better—for you and everyone else. '
      'So thanks. Seriously. $emoji',
      name: 'leaveFeedback',
      desc: 'Settings item',
    );
  }

  String get feedbackReceived {
    return Intl.message(
      'Your feedback was received, thank you!',
      name: 'feedbackReceived',
      desc: 'Confirmation snack message',
    );
  }

  String get toFeedback {
    return Intl.message(
      'To feedback!',
      name: 'toFeedback',
      desc: 'Action button on a dialog',
    );
  }

  String get dangerZone {
    return Intl.message(
      'Danger zone',
      name: 'dangerZone',
      desc: 'Settings header',
    );
  }

  String get deleteAccount {
    return Intl.message(
      'Delete account',
      name: 'deleteAccount',
      desc: 'Settings item',
    );
  }

  String get deleteAccountTitle {
    return Intl.message(
      'Are you sure you want to delete your account?',
      name: 'deleteAccountTitle',
      desc: 'Delete account dialog',
    );
  }

  String deleteAccountBody(String deadline) {
    return Intl.message(
      'Your account is scheduled for deletion in $deadline days. '
      'During this time, you can still sign in and reverse this decision. '
      'Once the deadline has passed, your account and personal data will be permanently deleted.',
      name: 'deleteAccountBody',
      desc: 'Delete account dialog',
      args: [deadline],
    );
  }

  String get deleteAccountCancelMessage {
    return Intl.message(
      'Oh no, I like it here!',
      name: 'deleteAccountCancelMessage',
      desc: 'Delete account dialog',
    );
  }

  String get deleteAccountConfirmMessage {
    return Intl.message(
      'Yep, go on without me!',
      name: 'deleteAccountConfirmMessage',
      desc: 'Delete account dialog',
    );
  }

  String get confirmDeleteAccountTitle {
    return Intl.message(
      'Confirm your account deletion',
      name: 'confirmDeleteAccountTitle',
      desc: 'Delete account dialog',
    );
  }

  String get confirmDeleteAccountCancelMessage {
    return Intl.message(
      'Changed my mind, cancel',
      name: 'confirmDeleteAccountCancelMessage',
      desc: 'Delete account dialog',
    );
  }

  String get confirmDeleteAccountOkMessage {
    return Intl.message(
      'Farewell!',
      name: 'confirmDeleteAccountOkMessage',
      desc: 'Delete account dialog',
    );
  }

  String get accountDeleted {
    return Intl.message(
      'Account deleted',
      name: 'accountDeleted',
      desc: 'Delete account page',
    );
  }

  String accountDeletedBody(String date) {
    return Intl.message(
      'Your account has been scheduled for deletion on $date.\n\n'
      'If you change your mind, you can restore your account anytime before this date.\n\n'
      'Simply click the button below to cancel the deletion and keep your account safe.',
      name: 'accountDeletedBody',
      desc: 'Delete account page',
      args: [date],
    );
  }

  String get accountDeletedAction {
    return Intl.message(
      '🔥🏆 Undo the Goodbye 🥇🔥',
      name: 'accountDeletedAction',
      desc: 'Delete account page',
    );
  }

  String get about {
    return Intl.message(
      'About',
      name: 'about',
      desc: 'Generic label',
    );
  }

  String get records {
    return Intl.message(
      'Records',
      name: 'records',
      desc: 'Generic label',
    );
  }

  String get charts {
    return Intl.message(
      'Charts',
      name: 'charts',
      desc: 'Generic label',
    );
  }

  String get emptyExerciseHistoryTitle {
    return Intl.message(
      'Ghost Reps Detected 👻',
      name: 'emptyExerciseHistoryTitle',
      desc: 'Exercise history empty state',
    );
  }

  String get emptyExerciseHistoryBody {
    return Intl.message(
      'Your exercise history is emptier than a gym on a Monday morning. Time to fill it up with some glorious PRs!',
      name: 'emptyExerciseHistoryBody',
      desc: 'Exercise history empty state',
    );
  }

  String get errorExerciseHistoryTitle {
    return Intl.message(
      'Oops! Someone Skipped the Data Day 🤷‍♀️',
      name: 'errorExerciseHistoryTitle',
      desc: 'Exercise history empty state',
    );
  }

  String get errorExerciseHistoryBody {
    return Intl.message(
      'Looks like the app tripped over its own shoelaces. Try again, and we promise to tie them tighter next time!',
      name: 'errorExerciseHistoryBody',
      desc: 'Exercise history empty state',
    );
  }

  String get personalRecords {
    return Intl.message(
      'Personal records',
      name: 'personalRecords',
      desc: 'Records screen, title',
    );
  }

  String get maxDuration {
    return Intl.message(
      'Max duration',
      name: 'maxDuration',
      desc: 'Records screen, metric name',
    );
  }

  String get maxDistance {
    return Intl.message(
      'Max distance',
      name: 'maxDistance',
      desc: 'Records screen, metric name',
    );
  }

  String get maxWeight {
    return Intl.message(
      'Max weight',
      name: 'maxWeight',
      desc: 'Records screen, metric name',
    );
  }

  String get maxReps {
    return Intl.message(
      'Max reps',
      name: 'maxReps',
      desc: 'Records screen, metric name',
    );
  }

  String get capturePhoto {
    return Intl.message(
      'Take a new photo',
      name: 'capturePhoto',
      desc: 'Image picker menu',
    );
  }

  String get chooseFromGallery {
    return Intl.message(
      'Choose from library',
      name: 'chooseFromGallery',
      desc: 'Image picker menu',
    );
  }

  String get removeCurrentPhoto {
    return Intl.message(
      'Remove current photo',
      name: 'removeCurrentPhoto',
      desc: 'Image picker menu',
    );
  }

  String get mine {
    return Intl.message(
      'Mine',
      name: 'mine',
      desc: 'Possessive pronoun, as in "My exercises"',
    );
  }
}

class LocsDelegate extends LocalizationsDelegate<L> {
  const LocsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr'].contains(locale.languageCode);
  }

  @override
  Future<L> load(Locale locale) => L.load(locale);

  @override
  bool shouldReload(LocalizationsDelegate<L> old) => false;
}

// generate arb files from string resources
// flutter pub pub run intl_translation:extract_to_arb --output-dir=lib/l10n lib/locale/locales.dart

// generate code for string lookup from arb files
// locale is inferred from @@locale in arb
// flutter pub pub run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/l10n/intl_en.arb lib/l10n/intl_fr.arb lib/locale/locales.dart
