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
  /// too — [exerciseOptionsFor] scopes it by name.
  static Key exerciseOptionsFor(String exerciseName) => Key('WorkoutDetail.exerciseOptions.$exerciseName');

  /// Per-set controls, scoped by exercise name and the set's position —
  /// the two coordinates a driver test can know up front.
  static Key doneFor(String exerciseName, int index) => Key('WorkoutDetail.done.$exerciseName.$index');

  static Key weightFor(String exerciseName, int index) => Key('WorkoutDetail.weight.$exerciseName.$index');

  static Key repsFor(String exerciseName, int index) => Key('WorkoutDetail.reps.$exerciseName.$index');
}
