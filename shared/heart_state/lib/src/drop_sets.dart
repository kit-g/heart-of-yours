import 'package:heart_models/heart_models.dart';

/// Drop sets as one effort (#614): a set typed [SetType.drop] belongs to the
/// set before it, unless that set is a warm-up or there is none. A working
/// set and the drops after it are one effort, and the next set that is not a
/// drop starts the next. Read from the order of the sets alone, so every drop
/// set ever logged, imports included, groups with no change to the data.
///
/// An effort counts as one set wherever sets are counted; volume counts the
/// load of every drop; and no drop can hold a record (the decisions on #614).
extension DropEfforts on Iterable<ExerciseSet> {
  /// Each set, and whether it continues the effort before it: a drop after a
  /// set that is not a warm-up.
  Iterable<(ExerciseSet, {bool continues})> get efforts sync* {
    ExerciseSet? before;
    for (final set in this) {
      yield (set, continues: set.setType == .drop && before != null && before.setType != .warmup);
      before = set;
    }
  }

  /// The sets [counts] keeps, counted by effort: a drop that continues one
  /// adds nothing. By default the ticked working sets, the count History, the
  /// muscle map, the lenses, goals and recaps show; a template's "3×5" counts
  /// every working set it plans.
  int countEfforts([bool Function(ExerciseSet set) counts = _ticked]) {
    return efforts.where((each) => !each.continues && counts(each.$1)).length;
  }

  static bool _ticked(ExerciseSet set) => set.isCompleted && set.setType != .warmup;
}
