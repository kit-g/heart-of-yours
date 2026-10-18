part of 'workout_detail.dart';

class WorkoutDetailKeys {
  new _();

  static const cancelWorkout = Key('WorkoutDetail.cancelWorkout');
  static const options = Key('WorkoutDetail.options');
  static const sessionNote = Key('WorkoutDetail.sessionNote');
  static const supplementalExplained = Key('WorkoutDetail.supplementalExplained');
  static const programBaseEditor = Key('WorkoutDetail.programBase');
  static Key recordPill(String kind) => Key('WorkoutDetail.recordPill.$kind');
  static const recordCount = Key('WorkoutDetail.recordCount');
  static Key openSlotFor(String exerciseId) => Key('WorkoutDetail.openSlot.$exerciseId');
  static const programBaseField = Key('WorkoutDetail.programBase.field');
  static const programBaseSave = Key('WorkoutDetail.programBase.save');
  static Key programBaseEdit(String key) => Key('WorkoutDetail.programBase.edit.$key');
  static const addExercises = Key('WorkoutDetail.addExercises');
  static const platesOffer = Key('WorkoutDetail.platesOffer');
  static const platesAccept = Key('WorkoutDetail.platesAccept');
  static const platesDecline = Key('WorkoutDetail.platesDecline');
  static const platesButton = Key('WorkoutDetail.platesButton');
  static const plateCalculator = Key('WorkoutDetail.plateCalculator');
  static const plateBar = Key('WorkoutDetail.plateBar');
  static const customBarField = Key('WorkoutDetail.customBarField');
  static const customBarSave = Key('WorkoutDetail.customBarSave');
  static Key plateChip(String plate) => Key('WorkoutDetail.plateChip.$plate');
  static Key plateNearest(String total) => Key('WorkoutDetail.plateNearest.$total');
  static Key barOption(String bar) => Key('WorkoutDetail.barOption.$bar');
  static const startNewWorkout = Key('WorkoutDetail.startNewWorkout');
  static const finishWorkout = Key('WorkoutDetail.finishWorkout');
  static const timer = Key('WorkoutDetail.timer');
  static const resume = Key('WorkoutDetail.resume');
  static const keepGoing = Key('WorkoutDetail.keepGoing');
  static const finishAtLastSet = Key('WorkoutDetail.finishAtLastSet');
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

  /// The ⋯ menu's swap for an open slot (#349).
  static Key swapExerciseFor(String exerciseId) => Key('WorkoutDetail.swapExercise.$exerciseId');

  /// The ⋯ menu's replace, with suggestions (#354).
  static Key replaceExerciseFor(String exerciseId) => Key('WorkoutDetail.replaceExercise.$exerciseId');

  /// The answers to whether a replace in a program's workout reaches the
  /// program (#354).
  static const replaceInProgram = Key('WorkoutDetail.replaceInProgram');
  static const replaceJustToday = Key('WorkoutDetail.replaceJustToday');

  /// The ⋯ menu's superset options (#159), by the exercise and its neighbour.
  static Key groupWith(String exerciseId, String neighbourId) =>
      Key('WorkoutDetail.groupWith.$exerciseId.$neighbourId');
  static Key leaveGroup(String exerciseId) => Key('WorkoutDetail.leaveGroup.$exerciseId');

  /// The rail beside a superset's members.
  static Key groupRailFor(String exerciseId) => Key('WorkoutDetail.groupRail.$exerciseId');

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

  /// The set-number popup's row that opens the set's target (#173).
  static const setTarget = Key('WorkoutDetail.setTarget');

  /// The target dialog's from and to fields for [column] (#173).
  static Key targetFrom(SetColumn column) => Key('WorkoutDetail.targetFrom.${column.key}');

  static Key targetTo(SetColumn column) => Key('WorkoutDetail.targetTo.${column.key}');

  /// A rating in the open set-number popup (#234).
  static Key rpeValue(double value) => Key('WorkoutDetail.rpeValue.$value');

  static Key weightFor(String exerciseId, int index) => Key('WorkoutDetail.weight.$exerciseId.$index');

  static Key repsFor(String exerciseId, int index) => Key('WorkoutDetail.reps.$exerciseId.$index');

  static Key distanceFor(String exerciseId, int index) => Key('WorkoutDetail.distance.$exerciseId.$index');

  static Key durationFor(String exerciseId, int index) => Key('WorkoutDetail.duration.$exerciseId.$index');
}
