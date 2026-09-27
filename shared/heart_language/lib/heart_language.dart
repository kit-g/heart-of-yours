library;

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations, LocalizationsDelegate;

import 'l10n/heart_language.dart';

export 'l10n/heart_language.dart';

/// What an app passes as `localizationsDelegates`, in place of
/// [L.localizationsDelegates].
///
/// gen-l10n writes that list against flutter_localizations, whose Material and
/// Cupertino strings are flutter/material.dart's and flutter/cupertino.dart's
/// types. material_ui and cupertino_ui look theirs up by their own types, and
/// MaterialApp's built-in fallback speaks English only: in any other language
/// they find nothing, and every back button, dialog and date picker that asks
/// throws (test/material_localizations_test.dart). Theirs are added here; the
/// generated ones stay for the dependencies still on the framework's copies.
const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  ...L.localizationsDelegates,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

extension MoreL on L {
  /// Full date with weekday, e.g. "Friday, 8 Aug 2026", in the user's language.
  ///
  /// [when] is converted to local time first, and that is not a courtesy to the
  /// caller — it is the correctness of the date itself. Timestamps arrive here
  /// as UTC (`workout.start` is parsed from an ISO string ending in `Z`), and
  /// `DateFormat` renders a `DateTime` in whatever zone it carries. So a
  /// workout logged at 23:41 in Toronto was labelled *Wednesday, 16 Sep* while
  /// its own name said *Tue, Sep 15* — the name comes from `DateTime.now()`,
  /// which is local, and the two disagreed on the same card.
  ///
  /// `toLocal()` on an already-local `DateTime` returns it unchanged, so this
  /// is safe for callers that had already converted, and it closes the whole
  /// class of bug rather than the three call sites that had it.
  String fullDate(DateTime when) {
    return intl.DateFormat('EEEE, d MMM y', localeName).format(when.toLocal());
  }

  /// Day and month in locale order — "8/8" in en, "08.08" in ru; chart axis labels.
  ///
  /// Local for the same reason as [fullDate]: a chart bucket rendered in UTC
  /// puts an evening workout on the following day's column.
  String dayAndMonth(DateTime when) {
    return intl.DateFormat.Md(localeName).format(when.toLocal());
  }

  String defaultWorkoutName() {
    final now = DateTime.now();
    final when = intl.DateFormat('EEE, MMM d', localeName).format(now);

    return switch (now.hour) {
      >= 5 && < 12 => morningWorkout(when),
      >= 12 && < 17 => afternoonWorkout(when),
      >= 17 && < 21 => eveningWorkout(when),
      _ => nightWorkout(when),
    };
  }
}
