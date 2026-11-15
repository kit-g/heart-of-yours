import 'package:heart/core/utils/goal_crossings.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What the active workout's goals are measured against while its sets are
/// ticked (#625): each goal's [GoalPrior], read once, when the goal first
/// meets the workout. Ticking a set then folds in memory ([goalCrossings])
/// and never asks the database — `LiveRecords`' arrangement, for goals.
class LiveGoals with ChangeNotifier {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({this.onError});

  static LiveGoals of(BuildContext context) => Provider.of<LiveGoals>(context, listen: false);

  static LiveGoals watch(BuildContext context) => Provider.of<LiveGoals>(context, listen: true);

  /// The workout [_prior] is for: another one starts the cache over.
  String? _workoutId;

  /// What the store looked like when [_prior] was read: another revision —
  /// a workout logged or synced meanwhile, a moved start, another first
  /// weekday — reads every goal again. What was read stays meanwhile, so a
  /// note does not blink out while the new reads land.
  Object? _revision;
  final _asked = <_Shape>{};
  final _prior = <_Shape, GoalPrior?>{};

  /// [goal]'s prior: null for one still being read, or one that cannot be
  /// measured or read.
  GoalPrior? priorOf(Goal goal) => _prior[_shapeOf(goal)];

  /// Whether [goal]'s read has landed, measurable or not.
  bool hasRead(Goal goal) => _prior.containsKey(_shapeOf(goal));

  /// Reads what [goals] have not been read for yet at [revision], with
  /// [read]. Each goal is asked once per workout and revision, whatever the
  /// answer — a read that failed is remembered as unmeasurable rather than
  /// asked again by every rebuild. Idempotent and silent until a read lands,
  /// so a build may call it.
  void prime(
    Workout workout,
    Iterable<Goal> goals,
    Future<GoalPrior?> Function(Goal goal) read, {
    required Object revision,
  }) {
    if (workout.id != _workoutId) {
      _workoutId = workout.id;
      _prior.clear();
      _asked.clear();
    }
    if (revision != _revision) {
      _revision = revision;
      _asked.clear();
    }
    for (final goal in goals) {
      final shape = _shapeOf(goal);
      if (!_asked.add(shape)) continue;
      void land(GoalPrior? prior) {
        if (_workoutId != workout.id || _revision != revision) return;
        _prior[shape] = prior;
        notifyListeners();
      }

      read(goal).then(
        land,
        onError: (error, stacktrace) {
          onError?.call(error, stacktrace: stacktrace);
          land(null);
        },
      );
    }
  }
}

/// What a goal's prior depends on: a goal edited into a different measure
/// mid-workout is read again, while a rung added or retargeted is not.
typedef _Shape = (String?, GoalMetric, GoalCadence?, String?, GoalSubject?);

_Shape _shapeOf(Goal goal) => (goal.id, goal.metric, goal.cadence, goal.exerciseId, goal.subject);
