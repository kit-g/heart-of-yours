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
  /// The sets [counts] keeps (by default the ticked working sets: the count
  /// History, the muscle map, the lenses, goals and recaps show), counted by
  /// effort. A drop adds nothing when the nearest set before it that [counts]
  /// keeps is not a warm-up. A set [counts] leaves out, one never ticked or a
  /// discarded entry, is passed over: finishing removes an unticked set, so
  /// the workout in progress and the finished one count alike, and discarding
  /// a bad entry never adds a set. A ticked warm-up ends the effort before it
  /// whether or not it is counted. The stored counts read the same rule.
  int countEfforts([bool Function(ExerciseSet set) counts = isTickedWorkingSet]) {
    var count = 0;
    var open = false;
    for (final set in this) {
      final kept = counts(set);
      if (set.setType == .warmup) {
        if (kept) count++;
        if (kept || set.isCompleted) open = false;
        continue;
      }
      if (!kept) continue;
      if (!(set.setType == .drop && open)) count++;
      open = true;
    }
    return count;
  }
}

/// Ticked and not a warm-up: the sets every record, chart, lens count and
/// goal counts (#151).
bool isTickedWorkingSet(ExerciseSet set) => set.isCompleted && set.setType != .warmup;
