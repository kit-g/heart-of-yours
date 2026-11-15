part of 'goals.dart';

/// Judging goals against one workout (#625): which goals, how each one's
/// [GoalPrior] is read, and how the workout's sets are folded in. One
/// arrangement for live goal notes and the workout summary, so the two cannot
/// drift apart.
///
/// [read] guards each goal on its own: one that cannot be read is reported and
/// reads as unmeasurable, and the rest are still judged.
typedef GoalJudge = ({
  List<Goal> goals,
  Future<GoalPrior?> Function(Goal goal, Workout workout) read,
  GoalFold fold,
});

/// [GoalJudge] as of now: every goal but the ones a running program's cadence
/// sets aside ([pausedByPrograms]), read from the store, and folded with the
/// catalogue's tagging and the sets discarded under suspicious entries (#428)
/// left out, as the store-side counts leave them.
GoalJudge goalJudge(BuildContext context) {
  final goals = Goals.of(context);
  final running = runningPrograms(context);
  final exercises = Exercises.of(context);
  final stats = Stats.of(context);
  final preferences = Preferences.of(context);
  final firstWeekday = preferences.firstWeekday;
  final anomalies = Anomalies.of(context);
  final lensSets = sharedLensSets(stats.getLensSets);

  Future<GoalPrior?> read(Goal goal, Workout workout) async {
    try {
      return await readGoalPrior(
        goal,
        workout,
        exercises: exercises,
        firstWeekday: firstWeekday,
        workoutCount: workoutCounter(stats, firstWeekday: firstWeekday, asOf: workout.start),
        lensSets: lensSets,
      );
    } catch (error, stacktrace) {
      goals.onError?.call(error, stacktrace: stacktrace);
      return null;
    }
  }

  return (
    goals: [
      for (final goal in goals)
        if (!pausedByPrograms(goal, running)) goal,
    ],
    read: read,
    fold: (
      exerciseOf: (embedded) => exercises.lookup(embedded.id) ?? embedded,
      leftOut: preferences.isOn(.entryReview) ? anomalies.discardedSets : const {},
    ),
  );
}
