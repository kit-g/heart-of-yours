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
  /// set that is not a warm-up. How a workout shows its sets, ticked or not.
  Iterable<(ExerciseSet, {bool continues})> get efforts sync* {
    ExerciseSet? before;
    for (final set in this) {
      yield (set, continues: set.setType == .drop && before != null && before.setType != .warmup);
      before = set;
    }
  }

  /// The sets [counts] keeps (by default the ticked working sets: the count
  /// History, the muscle map, the lenses, goals and recaps show), counted by
  /// effort. A drop right after a set [counts] keeps adds nothing; one after a
  /// set it leaves out, one never ticked or a discarded entry, starts an
  /// effort of its own. That is also what the finished workout says once the
  /// unticked set is gone, and what the stored counts read.
  int countEfforts([bool Function(ExerciseSet set) counts = isTickedWorkingSet]) {
    var count = 0;
    var keptBefore = false;
    for (final set in this) {
      final kept = counts(set);
      if (kept && !(set.setType == .drop && keptBefore)) count++;
      keptBefore = kept && set.setType != .warmup;
    }
    return count;
  }
}

/// Ticked and not a warm-up: the sets every record, chart, lens count and
/// goal counts (#151).
bool isTickedWorkingSet(ExerciseSet set) => set.isCompleted && set.setType != .warmup;
