import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'muscle_family.dart';

/// What History is narrowed to: muscle groups (#610), templates and a stretch
/// of days (#740). Within each, any of what is picked lets a workout through;
/// across them, all of them have to. Empty is no filter, and History as it
/// always was.
///
/// Kept for the app's run and nowhere else: a launch, or a session changing
/// hands, starts with the whole history again.
class HistoryFilter with ChangeNotifier implements SignOutStateSentry {
  final _groups = <MuscleGroupKey>{};
  final _templates = <String>{};
  DateTime? _from;
  DateTime? _until;

  static HistoryFilter of(BuildContext context) => Provider.of<HistoryFilter>(context, listen: false);

  static HistoryFilter watch(BuildContext context) => Provider.of<HistoryFilter>(context, listen: true);

  Set<MuscleGroupKey> get groups => UnmodifiableSetView(_groups);

  /// The templates, by id: those workouts name as what they were started from.
  Set<String> get templates => UnmodifiableSetView(_templates);

  /// The first and the last day that show, local calendar days at midnight,
  /// each open without one.
  DateTime? get from => _from;

  DateTime? get until => _until;

  /// [until], before [from], would let nothing through, and so would [from]
  /// past [until]: the other end is dropped then.
  set from(DateTime? day) {
    final from = _dayOf(day);
    if (from == _from) return;
    _from = from;
    if ((from, _until) case (final DateTime from, final DateTime until) when until.isBefore(from)) _until = null;
    notifyListeners();
  }

  set until(DateTime? day) {
    final until = _dayOf(day);
    if (until == _until) return;
    _until = until;
    if ((_from, until) case (final DateTime from, final DateTime until) when until.isBefore(from)) _from = null;
    notifyListeners();
  }

  bool get isOn => _groups.isNotEmpty || _templates.isNotEmpty || _from != null || _until != null;

  /// Adds [group] to the filter, or takes it out if it is in.
  void toggle(MuscleGroupKey group) {
    if (!_groups.remove(group)) _groups.add(group);
    notifyListeners();
  }

  void remove(MuscleGroupKey group) {
    if (_groups.remove(group)) notifyListeners();
  }

  /// Adds the template [id] to the filter, or takes it out if it is in.
  void toggleTemplate(String id) {
    if (!_templates.remove(id)) _templates.add(id);
    notifyListeners();
  }

  void removeTemplate(String id) {
    if (_templates.remove(id)) notifyListeners();
  }

  void clear() {
    if (!isOn) return;
    _groups.clear();
    _templates.clear();
    _from = null;
    _until = null;
    notifyListeners();
  }

  /// Whether [workout] shows under the filter: always, with none set. One
  /// started from no template, or from before that was kept, matches no
  /// template, whatever its name.
  bool shows(Workout workout, WorkoutGroups trained) {
    return _inStretch(workout.start) &&
        (_templates.isEmpty || _templates.contains(workout.templateId)) &&
        (_groups.isEmpty || trained.of(workout).any(_groups.contains));
  }

  /// Whether [skip] shows under the filter: a day set aside is no workout of
  /// any group or template, but it is a day.
  bool showsSkip(TrainingSkip skip) => _groups.isEmpty && _templates.isEmpty && _inStretch(skip.at);

  /// By the day [at] is here, as the list and the calendar place it.
  bool _inStretch(DateTime at) {
    final (from, until) = (_from, _until);
    if (from == null && until == null) return true;
    final day = _dayOf(at.toLocal())!;
    return !(from != null && day.isBefore(from)) && !(until != null && day.isAfter(until));
  }

  static DateTime? _dayOf(DateTime? at) {
    return switch (at) {
      DateTime(:final year, :final month, :final day) => DateTime(year, month, day),
      null => null,
    };
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
