library;

import 'package:intl/intl.dart' as intl;

import 'l10n/heart_language.dart';

export 'l10n/heart_language.dart';

extension MoreL on L {
  /// Full date with weekday, e.g. "Friday, 8 Aug 2026", in the user's language.
  String fullDate(DateTime when) {
    return intl.DateFormat('EEEE, d MMM y', localeName).format(when);
  }

  /// Day and month in locale order — "8/8" in en, "08.08" in ru; chart axis labels.
  String dayAndMonth(DateTime when) {
    return intl.DateFormat.Md(localeName).format(when);
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
