import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'muscle_family.dart';

/// The muscle groups History is narrowed to (#610): a workout shows while it
/// trained any of them, by [WorkoutGroups]. Empty is no filter, and History
/// as it always was.
///
/// Kept for the app's run and nowhere else: a launch, or a session changing
/// hands, starts with the whole history again.
class HistoryFilter with ChangeNotifier implements SignOutStateSentry {
  final _groups = <MuscleGroupKey>{};

  static HistoryFilter of(BuildContext context) => Provider.of<HistoryFilter>(context, listen: false);

  static HistoryFilter watch(BuildContext context) => Provider.of<HistoryFilter>(context, listen: true);

  Set<MuscleGroupKey> get groups => UnmodifiableSetView(_groups);

  bool get isOn => _groups.isNotEmpty;

  /// Adds [group] to the filter, or takes it out if it is in.
  void toggle(MuscleGroupKey group) {
    if (!_groups.remove(group)) _groups.add(group);
    notifyListeners();
  }

  void remove(MuscleGroupKey group) {
    if (_groups.remove(group)) notifyListeners();
  }

  void clear() {
    if (_groups.isEmpty) return;
    _groups.clear();
    notifyListeners();
  }

  /// Whether [workout] shows under the filter: always, with none set.
  bool shows(Workout workout, WorkoutGroups trained) {
    return _groups.isEmpty || trained.of(workout).any(_groups.contains);
  }

  @override
  void onSignOut() => clear();
}

/// The muscle groups workouts trained, as History's filter reads them
/// (#610), against the library as it stands now.
///
/// Each exercise with a working set done counts toward its *primary* groups
/// only, so a bench session is no arm day; warm-ups count for nothing, as on
/// the muscle map (#236). The library's copy of an exercise wins over the one
/// the workout carries, which may have been synced without its tags. An
/// exercise nobody tagged — one the user made — counts toward the group its
/// target names, and a target no group answers to (cardio, the whole body)
/// toward none.
///
/// Meant to live for one read of the history: each exercise is resolved once
/// however many workouts hold it, and a library that changes (a re-tag, an
/// edit to the user's own exercise) is read afresh by the next one.
class WorkoutGroups {
  final Exercise? Function(ExerciseId) _lookup;
  final _byExercise = <ExerciseId, Set<MuscleGroupKey>>{};

  new(this._lookup);

  Set<MuscleGroupKey> of(Workout workout) {
    return {for (final each in done(workout)) ...ofExercise(each.exercise)};
  }

  /// The working sets [workouts] gave each [MuscleFamily] they trained, by
  /// the same rule: what orders a calendar day's colours, busiest first
  /// (#617). A set counts once toward each family its exercise reaches.
  Map<MuscleFamily, int> setsByFamily(Iterable<Workout> workouts) {
    return workouts.expand(done).fold(<MuscleFamily, int>{}, (sets, each) {
      final count = each.where(_counts).length;
      final families = {for (final group in ofExercise(each.exercise)) MuscleFamily.of(group)};
      return {
        ...sets,
        for (final family in families) family: (sets[family] ?? 0) + count,
      };
    });
  }

  /// The exercises of [workout] that count: those with a working set done.
  static Iterable<WorkoutExercise> done(Workout workout) => workout.where((each) => each.any(_counts));

  /// The groups one exercise counts toward, by the rule above.
  Set<MuscleGroupKey> ofExercise(Exercise exercise) {
    return _byExercise[exercise.id] ??= _groupsOf(exercise);
  }

  Set<MuscleGroupKey> _groupsOf(Exercise copy) {
    final known = _lookup(copy.id);
    final muscles = switch (known?.muscles) {
      final MuscleTagging muscles when !muscles.isEmpty => muscles,
      _ => copy.muscles,
    };
    return muscles.isEmpty ? {?(known ?? copy).target.muscleGroup} : muscles.primaryGroups;
  }

  static bool _counts(ExerciseSet set) => set.isCompleted && set.setType != .warmup;
}
