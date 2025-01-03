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

  String get lbs {
    return Intl.message(
      'lbs',
      name: 'lbs',
      desc: 'Generic label, pounds',
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

  String get removeExercise {
    return Intl.message(
      'Remove exercise',
      name: 'removeExercise',
      desc: 'Exercise set option, "Remove this exercise from workout"',
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
