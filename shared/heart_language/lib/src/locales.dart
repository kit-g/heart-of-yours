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

  String get settings {
    return Intl.message(
      'Settings',
      name: 'settings',
      desc: 'Generic label',
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

  String get logInWithGoogle {
    return Intl.message(
      'Log in with Google',
      name: 'logInWithGoogle',
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

  String get pushExercise {
    return Intl.message(
      'Push exercise',
      name: 'pushExercise',
      desc: 'Indicates that the exercise is a push exercise',
    );
  }

  String get pullExercise {
    return Intl.message(
      'Pull exercise',
      name: 'pullExercise',
      desc: 'Indicates that the exercise is a pull exercise',
    );
  }

  String get staticExercise {
    return Intl.message(
      'Static exercise',
      name: 'staticExercise',
      desc: 'Indicates that the exercise is a static exercise',
    );
  }

  String get startNewWorkout {
    return Intl.message(
      'Start a new workout',
      name: 'startNewWorkout',
      desc: 'Button label',
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

  String get kg {
    return Intl.message(
      'kg',
      name: 'kg',
      desc: 'Generic label, kilograms',
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
      'Weight unit',
      name: 'weightUnit',
      desc: 'Exercise set option, "choose weight unit for this set"',
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

  String get resumeWorkout {
    return Intl.message(
      'No, resume workout',
      name: 'resumeWorkout',
      desc: 'Workout cancellation confirmation dialog',
    );
  }

  String get notReadyToFinish {
    return Intl.message(
      'No, one more set!',
      name: 'notReadyToFinish',
      desc: 'Workout completion confirmation dialog',
    );
  }

  String get notificationSettings {
    return Intl.message(
      'Notification settings',
      name: 'notificationSettings',
      desc: 'Settings item',
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
