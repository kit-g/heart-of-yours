import 'package:heart_models/heart_models.dart';

/// Supersets and circuits (#159): exercises of one session done back to back,
/// two a superset, three or more a circuit. [WorkoutExercise.superset] is the
/// label that holds them together — a number meaning nothing but "the same as
/// its neighbour's" (heart-api `docs/2026-10-15.supersets.md`).
///
/// On the sheet a group is a run of neighbours: dropping an exercise inside
/// one joins it, dragging one out leaves it, and a group left with a single
/// member is no group. Every change below returns the exercises whose label
/// it changed, for the caller to store.
extension Supersets on Iterable<WorkoutExercise> {
  /// [exercise]'s group in session order, or [exercise] alone: ungrouped, or
  /// the last of a group whose other members are gone.
  List<WorkoutExercise> groupOf(WorkoutExercise exercise) {
    final label = exercise.superset;
    if (label == null) return [exercise];
    final members = where((each) => each.superset == label).toList();
    return switch (members.length) {
      > 1 => members,
      _ => [exercise],
    };
  }

  /// The members of [exercise]'s group still to go this round: after it, with
  /// a set left to do. Empty for an exercise on its own, and for the round's
  /// last.
  Iterable<WorkoutExercise> restOfRound(WorkoutExercise exercise) {
    final group = groupOf(exercise);
    return group.skip(group.indexOf(exercise) + 1).where((each) => each.any((set) => !set.isCompleted));
  }

  /// Whose rest follows a set of [exercise]: null while its round goes on —
  /// a superset rests once, after the round — and otherwise the group's last
  /// member, which is where a round's rest is planned. An exercise on its own
  /// rests as itself.
  WorkoutExercise? restsAs(WorkoutExercise exercise) {
    if (restOfRound(exercise).isNotEmpty) return null;
    return groupOf(exercise).last;
  }

  /// The set that follows one of [exercise] by its group's order: the next
  /// member's open set this round, else the next round's first. Null for an
  /// exercise on its own, and once the whole group is done — what follows is
  /// then whatever follows the group.
  (WorkoutExercise, ExerciseSet)? nextInGroup(WorkoutExercise exercise) {
    final group = groupOf(exercise);
    if (group.length < 2) return null;
    (WorkoutExercise, ExerciseSet)? open(WorkoutExercise each) {
      return switch (each.where((set) => !set.isCompleted).firstOrNull) {
        ExerciseSet set => (each, set),
        null => null,
      };
    }

    return [...restOfRound(exercise), ...group].map(open).nonNulls.firstOrNull;
  }

  /// The lowest label no exercise here carries.
  int get freeSuperset {
    final taken = map((each) => each.superset).nonNulls.toSet();
    return Iterable.generate(taken.length + 1, (index) => index + 1).firstWhere((label) => !taken.contains(label));
  }

  /// Joins [exercise] and its [neighbour] — and so their groups, if either
  /// has one — into one group.
  Set<WorkoutExercise> group(WorkoutExercise exercise, WorkoutExercise neighbour) {
    final label = exercise.superset ?? neighbour.superset ?? freeSuperset;
    final joining = {...groupOf(exercise), ...groupOf(neighbour)};
    final changed = {
      for (final each in joining)
        if (each.superset != label) each,
    };
    for (final each in changed) {
      each.superset = label;
    }
    return {...changed, ...settle()};
  }

  /// Takes [exercise] out of its group. Leaving from the middle of a circuit
  /// splits it in two, each half a group if it still has two members.
  Set<WorkoutExercise> leave(WorkoutExercise exercise) {
    if (exercise.superset == null) return {};
    exercise.superset = null;
    return {exercise, ...settle()};
  }

  /// Makes the labels say what the sheet shows, after a move, a removal or a
  /// split. [moved], dropped between two members of one group, joins it.
  /// Then each run of neighbours sharing a label is a group: a run of one
  /// stands alone, and a label already used by an earlier run gives way to a
  /// free one, so two runs never read as one group.
  Set<WorkoutExercise> settle({WorkoutExercise? moved}) {
    final exercises = toList();
    final changed = <WorkoutExercise>{};
    void label(WorkoutExercise exercise, int? value) {
      if (exercise.superset == value) return;
      exercise.superset = value;
      changed.add(exercise);
    }

    if (moved != null) {
      final index = exercises.indexOf(moved);
      if (index > 0 && index < exercises.length - 1) {
        final (before, after) = (exercises[index - 1], exercises[index + 1]);
        if (before.superset case int shared when shared == after.superset) label(moved, shared);
      }
    }

    final runs = <List<WorkoutExercise>>[];
    for (final exercise in exercises) {
      switch ((exercise.superset, runs.lastOrNull?.last.superset)) {
        case (int mine, int theirs) when mine == theirs:
          runs.last.add(exercise);
        default:
          runs.add([exercise]);
      }
    }

    final used = <int>{};
    for (final run in runs) {
      switch ((run.first.superset, run.length)) {
        case (null, _):
          continue;
        case (_, 1):
          label(run.single, null);
        case (int mine, _) when used.contains(mine):
          final free = Iterable.generate(exercises.length + 1, (index) => index + 1).firstWhere(
            (each) => !used.contains(each) && !exercises.any((exercise) => exercise.superset == each),
          );
          used.add(free);
          for (final each in run) {
            label(each, free);
          }
        case (int mine, _):
          used.add(mine);
      }
    }
    return changed;
  }
}
