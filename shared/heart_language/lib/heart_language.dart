library;

import 'l10n/heart_language.dart';

export 'l10n/heart_language.dart';

extension MoreL on L {
  String defaultWorkoutName() {
    return switch (DateTime.now().hour) {
      >= 5 && < 12 => morningWorkout,
      >= 12 && < 17 => afternoonWorkout,
      >= 17 && < 21 => eveningWorkout,
      _ => nightWorkout,
    };
  }
}
