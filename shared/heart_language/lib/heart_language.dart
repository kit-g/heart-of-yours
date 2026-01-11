library;

import 'package:intl/intl.dart' as intl;

import 'l10n/heart_language.dart';

export 'l10n/heart_language.dart';

extension MoreL on L {
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
