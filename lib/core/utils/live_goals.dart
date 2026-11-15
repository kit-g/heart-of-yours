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
  final _asked = <_Shape>{};
  final _prior = <_Shape, GoalPrior?>{};

  /// [goal]'s prior: null for one still being read, or one that cannot be
  /// measured.
  GoalPrior? priorOf(Goal goal) => _prior[_shapeOf(goal)];

  /// Whether [goal]'s read has landed, measurable or not.
  bool hasRead(Goal goal) => _prior.containsKey(_shapeOf(goal));

  /// Reads what [goals] have not been read for yet, with [read]. Idempotent
  /// and silent until a read lands, so a build may call it.
  void prime(Workout workout, Iterable<Goal> goals, Future<GoalPrior?> Function(Goal goal) read) {
    if (workout.id != _workoutId) {
      _workoutId = workout.id;
      _asked.clear();
      _prior.clear();
    }
    for (final goal in goals) {
      final shape = _shapeOf(goal);
      if (!_asked.add(shape)) continue;
      read(goal).then(
        (prior) {
          if (_workoutId != workout.id) return;
          _prior[shape] = prior;
          notifyListeners();
        },
        onError: (error, stacktrace) {
          // asked again by the next build, rather than never
          _asked.remove(shape);
          onError?.call(error, stacktrace: stacktrace);
        },
      );
    }
  }
}

/// What a goal's prior depends on: a goal edited into a different measure
/// mid-workout is read again, while a rung added or retargeted is not.
typedef _Shape = (String?, GoalMetric, GoalCadence?, String?, GoalSubject?);

_Shape _shapeOf(Goal goal) => (goal.id, goal.metric, goal.cadence, goal.exerciseId, goal.subject);
