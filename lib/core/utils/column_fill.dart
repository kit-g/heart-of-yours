import 'package:heart_models/heart_models.dart';

/// A value column of the set table, whose header fills it (#225).
///
/// [key] is the field's name in a previous set's row, as `PreviousExercises`
/// keeps it.
enum SetColumn {
  weight('weight'),
  reps('reps'),
  distance('distance'),
  duration('duration');

  final String key;

  new(this.key);

  /// The value columns an exercise of [category] shows, left to right.
  static List<SetColumn> of(Category category) {
    return switch (category) {
      .machine || .dumbbell || .barbell || .weightedBodyWeight || .assistedBodyWeight => const [.weight, .reps],
      .repsOnly => const [.reps],
      .cardio => const [.distance, .duration],
      .duration => const [.duration],
    };
  }

  num? _of(ExerciseSet set) {
    return switch (this) {
      .weight => set.weight,
      .reps => set.reps,
      .distance => set.distance,
      .duration => set.duration,
    };
  }
}

/// What tapping [column]'s header writes, set by set, into [exercise]: every
/// set not yet ticked takes its own value from last time ([previous], by the
/// set's index), or failing that the top set's. A set with neither is left
/// out, and so is every ticked one — a done set is a record, not a draft.
///
/// Values are as the model keeps them: weight and distance metric, duration
/// in seconds.
Map<ExerciseSet, num> columnFill(
  WorkoutExercise exercise,
  SetColumn column, {
  required Map<String, dynamic>? Function(int index) previous,
}) {
  final top = switch (exercise.firstOrNull) {
    ExerciseSet set => column._of(set),
    null => null,
  };
  return {
    for (final (index, set) in exercise.indexed)
      if (!set.isCompleted)
        if (previous(index)?[column.key] ?? top case num value) set: value,
  };
}
