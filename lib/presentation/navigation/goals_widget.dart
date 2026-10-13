import 'dart:convert';

import 'package:heart/core/env/goals_widget.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the Home Screen's Goals widget (#368) told what it draws: the
/// signed-in user's active goals, worded and measured exactly as the profile's
/// goal rows are (`goalTitle`, `goalStatus`, `currentGoalValue`), closest to
/// done first. Told again when the goals, the training they are measured
/// against, the units or the language change, and only when what it would be
/// told changed.
///
/// Told whether or not a widget is on the Home Screen, as the training widget
/// is: adding the widget is the opt-in, and one just added draws the user's
/// goals at once.
class GoalsWidgetPresenter extends StatefulWidget {
  final Widget child;

  /// The platform's layer, or null where there is none (tests, the web).
  final GoalsWidget? widget;

  const new({super.key, required this.child, this.widget});

  @override
  State<GoalsWidgetPresenter> createState() => _GoalsWidgetPresenterState();
}

class _GoalsWidgetPresenterState extends State<GoalsWidgetPresenter> {
  Goals? _goals;
  Workouts? _workouts;
  Preferences? _preferences;
  Exercises? _exercises;
  Auth? _auth;

  /// What the last reading was taken for, so a set ticked mid-workout does
  /// not re-read every goal; null before the first.
  Object? _measured;

  /// What was last told, encoded; null before the first.
  String? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final goals = Goals.of(context);
    if (!identical(goals, _goals)) {
      _goals?.removeListener(_sync);
      _goals = goals..addListener(_sync);
    }
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final exercises = Exercises.of(context);
    if (!identical(exercises, _exercises)) {
      _exercises?.removeListener(_sync);
      _exercises = exercises..addListener(_sync);
    }
    final auth = Auth.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_sync);
      _auth = auth..addListener(_sync);
    }
    // the words follow the language
    L.of(context);
    _measured = null;
    _sync();
  }

  @override
  void dispose() {
    _goals?.removeListener(_sync);
    _workouts?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    _exercises?.removeListener(_sync);
    _auth?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _sync() async {
    final layer = widget.widget;
    final goals = _goals;
    final workouts = _workouts;
    final preferences = _preferences;
    final exercises = _exercises;
    if (layer == null || goals == null || workouts == null || preferences == null || exercises == null) return;

    if (_auth?.user == null) return _tell(layer, null);
    // before they are read a launch knows of no goal and no workout, and the
    // widget keeps the last snapshot rather than flashing an empty one; the
    // units are `late` until the preferences land
    if (!goals.initialized || !workouts.historyInitialized || !preferences.isInitialized) return;

    final measured = (
      Object.hashAll(goals.all.map((goal) => goal.toMap().toString())),
      workouts.history.length,
      preferences.weightUnit,
      preferences.distanceUnit,
    );
    if (measured == _measured) return;
    _measured = measured;

    final counter = workoutCounter(Stats.of(context));
    final readings = await Future.wait([
      for (final goal in goals.all) currentGoalValue(goal, exercises: exercises, workoutCount: counter),
    ]);
    if (!mounted || measured != _measured) return;

    final shown = [
      for (final (index, goal) in goals.all.indexed)
        WidgetGoal(
          id: goal.id ?? '',
          title: goalTitle(context, goal, goalExercise(goal, exercises)),
          status: goalStatus(
            context,
            goal,
            settings: preferences,
            scale: goalScale(goal, exercises),
            current: readings[index],
          ),
          progress: goalProgress(goal, readings[index]),
        ),
    ]..sort((a, b) => b.progress.compareTo(a.progress));
    _tell(layer, GoalsSnapshot(shown));
  }

  void _tell(GoalsWidget layer, GoalsSnapshot? snapshot) {
    final encoded = switch (snapshot) {
      GoalsSnapshot snapshot => jsonEncode(snapshot.toMap()),
      null => '',
    };
    if (encoded == _published) return;
    _published = encoded;
    layer.setGoals(snapshot);
  }
}

/// How far along [goal]'s current rung [current] is, 0 to 1, in the units both
/// are stored in: a finished ladder is 1, an unreadable value 0. Where lower
/// is better (pace) the target over the reading, so that closing in still
/// fills the bar.
double goalProgress(Goal goal, num? current) {
  final target = goal.currentStage?.target;
  return switch ((target, current)) {
    (null, _) => 1,
    (_, null) => 0,
    (final num target, final num value) when goal.metric.lowerIsBetter => switch (value) {
      <= 0 => 0,
      _ => (target / value).clamp(0, 1).toDouble(),
    },
    (final num target, final num value) => switch (target) {
      <= 0 => 1,
      _ => (value / target).clamp(0, 1).toDouble(),
    },
  };
}
