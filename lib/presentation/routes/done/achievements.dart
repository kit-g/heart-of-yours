part of 'done.dart';

/// The goal rungs the session just finished earned.
///
/// Renders nothing at all when there are none, which is most sessions — a
/// heading reading "0 goals reached" would turn a congratulation into a report
/// card. It also renders nothing while it waits: the observation has to read
/// the workout back out of the database, and a spinner here would sit in the
/// middle of the confetti for no reason.
class _Achievements extends StatefulWidget {
  final Future<List<GoalAchievement>> Function() callback;

  const new({required this.callback});

  @override
  State<_Achievements> createState() => _AchievementsState();
}

class _AchievementsState extends State<_Achievements> {
  /// Resolved once, not per build.
  ///
  /// The observation *stamps* what it finds, so it only ever reports a rung the
  /// first time. This widget watches [Preferences] and [Exercises] for its
  /// copy, so it rebuilds on any of their notifications — asking again from
  /// `build` meant the second answer was empty and the congratulation vanished
  /// as fast as it appeared.
  late final Future<List<GoalAchievement>> _earned = widget.callback();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final settings = Preferences.watch(context);
    final exercises = Exercises.watch(context);

    return FutureBuilder<List<GoalAchievement>>(
      future: _earned,
      builder: (_, snapshot) {
        final earned = snapshot.data;

        // It arrives late by nature — the observation waits on the workout
        // being written — so it lands into a screen that has already settled.
        // Appearing instantly reads as a glitch rather than a result; it rises
        // and fades in, and the column grows with it instead of shoving the
        // summary and the button down a frame.
        return AnimatedSize(
          duration: _revealDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _revealDuration,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: switch (earned) {
              null || [] => const SizedBox(width: double.infinity),
              _ => _earnedBlock(earned, textTheme, colorScheme, l, settings, exercises),
            },
          ),
        );
      },
    );
  }

  /// How long the block takes to arrive. Slower than a state change, because
  /// this is the screen's one piece of news.
  static const _revealDuration = Duration(milliseconds: 450);

  Widget _earnedBlock(
    List<GoalAchievement> earned,
    TextTheme textTheme,
    ColorScheme colorScheme,
    L l,
    Preferences settings,
    Exercises exercises,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
      child: Column(
        spacing: 8,
        children: [
          Text(
            l.goalsAchievedHeading(earned.length),
            style: textTheme.titleMedium,
          ),
          for (final (goal: goal, stage: stage) in earned)
            Text(
              l.goalAchievedTarget(
                goalTitle(context, goal, goalExercise(goal, exercises)),
                _target(context, goal, stage, settings),
              ),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  /// The rung's target in the user's own units, the way the goals card states
  /// it. Falls back to the bare number before [Preferences] has loaded, since
  /// its unit fields are `late`.
  String _target(BuildContext context, Goal goal, GoalStage stage, Preferences settings) {
    if (!settings.isInitialized) return stage.target.toString();
    return goalTargetLabel(context, goal, stage.target, settings: settings);
  }
}
