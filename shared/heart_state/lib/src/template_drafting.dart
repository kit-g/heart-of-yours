import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';

import 'supersets.dart';

/// A template being edited, and every change the template editor makes to
/// it, whoever keeps the template: [Templates] for the user's own, a coach's
/// library for a session of one of its programs (#557).
///
/// The changes happen to [editable] in memory, and nothing is kept until
/// [saveEditable]. Where a draft begins and where a save goes is the keeper's.
mixin TemplateDrafting on ChangeNotifier {
  /// The template the editor is on, or null before its first exercise.
  Template? editable;

  /// A blank template for [add] to put the first exercise in.
  Future<Template> startDraft();

  /// Keeps [editable], and closes it.
  Future<void> saveEditable();

  /// Drops [editable] and what was done to it.
  Future<void> discardEditable();

  Future<void> add(Exercise exercise) async {
    editable ??= await startDraft();
    editable?.add(exercise);
    notifyListeners();
  }

  void remove(WorkoutExercise exercise) {
    editable?.remove(exercise);
  }

  void addSet(WorkoutExercise exercise) {
    // a plain set, whatever the last one was: a warm-up is not what comes
    // after a warm-up (Strong and Hevy agree)
    final set = switch (exercise.lastOrNull) {
      ExerciseSet last => last.copy()..setType = .normal,
      null => ExerciseSet(exercise.exercise),
    };
    exercise.add(set);
    notifyListeners();
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    exercise.remove(set);
    notifyListeners();
  }

  /// Retypes [set] in the template being edited; saved with the rest of it.
  void setSetType(ExerciseSet set, SetType type) {
    set.setType = type;
    notifyListeners();
  }

  /// Aims [set] in the template being edited at [target], or at nothing when
  /// it is null (#173); saved with the rest of it. A set added after it copies
  /// it, as it copies the values.
  ///
  /// A measure the target now aims at gives up the fixed value it held: a cell
  /// shows one or the other, and "5 reps" left under "6–10" would be the one
  /// the sheet prefills. The set is rebuilt in its place, under its id.
  void setSetTarget(ExerciseSet set, SetTarget? target) {
    set.target = target ?? SetTarget.none;
    final aimed = {...?set.target?.ranges.keys.map((measure) => measure.value)};
    final map = set.toMap();
    final exercise = editable?.where((each) => each.contains(set)).firstOrNull;
    if (exercise != null && aimed.any((key) => map[key] != null)) {
      final rebuilt = ExerciseSet.fromJson(exercise.exercise, {...map}..removeWhere((key, _) => aimed.contains(key)));
      final sets = exercise.toList();
      sets.forEach(exercise.remove);
      for (final each in sets) {
        exercise.add(identical(each, set) ? rebuilt : each);
      }
    }
    notifyListeners();
  }

  void removeExercise(WorkoutExercise exercise) {
    editable
      ?..remove(exercise)
      // a superset left with one member is no superset (#159)
      ..settle();
    notifyListeners();
  }

  void swap(WorkoutExercise toInsert, WorkoutExercise before) {
    editable
      ?..swap(toInsert, before)
      ..settle(moved: toInsert);
    notifyListeners();
  }

  void append(WorkoutExercise exercise) {
    editable
      ?..append(exercise)
      ..settle(moved: exercise);
    notifyListeners();
  }

  /// Joins [exercise] and [neighbour] of the template being edited in a
  /// superset (#159), or [exercise] into the one [neighbour] is in.
  void group(WorkoutExercise exercise, WorkoutExercise neighbour) {
    editable?.group(exercise, neighbour);
    notifyListeners();
  }

  /// Takes [exercise] of the template being edited out of its superset.
  void leaveGroup(WorkoutExercise exercise) {
    editable?.leave(exercise);
    notifyListeners();
  }
}
