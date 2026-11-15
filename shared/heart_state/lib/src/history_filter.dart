import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// The muscle groups History is narrowed to (#610): a workout shows while it
/// trained any of them, by [workoutGroupsOf]. Empty is no filter, and History
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
  bool shows(Workout workout, {required Exercise? Function(ExerciseId) lookup}) {
    return _groups.isEmpty || workoutGroupsOf(workout, lookup: lookup).any(_groups.contains);
  }

  @override
  void onSignOut() => clear();
}

/// What [workoutGroupsOf] has already worked out, per workout as held. Every
/// copy the store hands over is a new object, so an edited or refetched
/// workout is read afresh, while History's every-second rebuilds during an
/// active workout read the cache.
final _cache = Expando<Set<MuscleGroupKey>>('workoutGroups');

/// The muscle groups [workout] trained, as History's filter reads them
/// (#610): each exercise with a set done counts toward its *primary* groups
/// only, so a bench session is no arm day. The library's tagging wins over
/// the copy the workout carries, which may have been synced without it; an
/// exercise with no primary tags — one the user made — counts toward the
/// group its target names, and a target no group answers to (cardio, the
/// whole body) toward none.
Set<MuscleGroupKey> workoutGroupsOf(Workout workout, {required Exercise? Function(ExerciseId) lookup}) {
  if (_cache[workout] case final groups?) return groups;
  final done = workout.where((each) => each.any((set) => set.isCompleted)).map((each) => each.exercise);
  final groups = {for (final exercise in done) ...exerciseGroupsOf(exercise, lookup: lookup)};
  // kept only once the library had its say on every exercise: read before
  // it loads, a workout would keep the copy's tagging for the whole run
  if (done.every((exercise) => lookup(exercise.id) != null)) _cache[workout] = groups;
  return groups;
}

/// [exercise]'s primary muscle groups, by [workoutGroupsOf]'s rule.
Set<MuscleGroupKey> exerciseGroupsOf(Exercise exercise, {required Exercise? Function(ExerciseId) lookup}) {
  final tagging = switch (lookup(exercise.id)?.muscles) {
    final MuscleTagging muscles when !muscles.isEmpty => muscles,
    _ => exercise.muscles,
  };
  return switch (tagging.primaryGroups) {
    final groups when groups.isNotEmpty => groups,
    _ => {?exercise.target.muscleGroup},
  };
}
