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
