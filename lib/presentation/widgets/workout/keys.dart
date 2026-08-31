part of 'workout_detail.dart';

class WorkoutDetailKeys {
  new _();

  static const cancelWorkout = Key('WorkoutDetail.cancelWorkout');
  static const options = Key('WorkoutDetail.options');
  static const addExercises = Key('WorkoutDetail.addExercises');
  static const startNewWorkout = Key('WorkoutDetail.startNewWorkout');
  static const finishWorkout = Key('WorkoutDetail.finishWorkout');
  static const timer = Key('WorkoutDetail.timer');
  static const addSet = Key('WorkoutDetail.addSet');
  static const addExerciseButton = Key('WorkoutDetail.addExerciseButton');

  /// The per-exercise overflow menu inside a workout.
  ///
  /// Every exercise in a workout renders one, so a finder needs the exercise
  /// too — [exerciseOptionsFor] scopes it by the exercise id: names are
  /// localized display copy and change with the device language, ids don't.
  static Key exerciseOptionsFor(String exerciseId) => Key('WorkoutDetail.exerciseOptions.$exerciseId');

  /// Per-set controls, scoped by exercise id and the set's position —
  /// the two coordinates a driver test can know up front.
  static Key doneFor(String exerciseId, int index) => Key('WorkoutDetail.done.$exerciseId.$index');

  static Key weightFor(String exerciseId, int index) => Key('WorkoutDetail.weight.$exerciseId.$index');

  static Key repsFor(String exerciseId, int index) => Key('WorkoutDetail.reps.$exerciseId.$index');
}
