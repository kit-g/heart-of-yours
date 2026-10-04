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
  static const discardAndStart = Key('WorkoutDetail.discardAndStart');

  /// The workout's own note under its title (#235), which opens its editor.
  static const workoutNote = Key('WorkoutDetail.workoutNote');

  /// The per-exercise overflow menu inside a workout.
  ///
  /// Every exercise in a workout renders one, so a finder needs the exercise
  /// too — [exerciseOptionsFor] scopes it by the exercise id: names are
  /// localized display copy and change with the device language, ids don't.
  static Key exerciseOptionsFor(String exerciseId) => Key('WorkoutDetail.exerciseOptions.$exerciseId');

  /// Per-set controls, scoped by exercise id and the set's position —
  /// the two coordinates a driver test can know up front.
  static Key doneFor(String exerciseId, int index) => Key('WorkoutDetail.done.$exerciseId.$index');

  /// A value column's header in an exercise's set table (#225); [column] is
  /// `SetColumn.key`.
  static Key fillFor(String exerciseId, String column) => Key('WorkoutDetail.fill.$exerciseId.$column');

  /// The ✓ column's header in an exercise's set table (#225).
  static Key tickAllFor(String exerciseId) => Key('WorkoutDetail.tickAll.$exerciseId');

  /// A set's number, which opens its type menu (#151).
  static Key setTypeFor(String exerciseId, int index) => Key('WorkoutDetail.setType.$exerciseId.$index');

  /// A row of the open set type menu; only one menu is open at a time.
  static Key setTypeOption(SetType type) => Key('WorkoutDetail.setTypeOption.${type.value}');

  /// The button that takes a set's rating away, in its open popup (#234).
  static const clearRpe = Key('WorkoutDetail.clearRpe');

  /// A rating in the open set-number popup (#234).
  static Key rpeValue(double value) => Key('WorkoutDetail.rpeValue.$value');

  static Key weightFor(String exerciseId, int index) => Key('WorkoutDetail.weight.$exerciseId.$index');

  static Key repsFor(String exerciseId, int index) => Key('WorkoutDetail.reps.$exerciseId.$index');

  static Key distanceFor(String exerciseId, int index) => Key('WorkoutDetail.distance.$exerciseId.$index');

  static Key durationFor(String exerciseId, int index) => Key('WorkoutDetail.duration.$exerciseId.$index');
}
