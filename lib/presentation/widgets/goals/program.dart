part of 'goals.dart';

/// A running program as goals read it (#353): where it stands, the bases its
/// rules grew and how many of its sessions were trained — what a forecast is
/// made of.
typedef ProgramFeed = ({Program program, ProgramPosition position, List<ProgramBase> bases, int sessionsDone});

/// The programs the user follows that are still running, or none while
/// Programs is off: with the switch off, goals look as they did before.
List<ProgramFeed> programFeeds(BuildContext context) {
  if (!Preferences.watch(context).isOn(.programs)) return const [];
  final programs = Programs.watch(context);
  final firstWeekday = firstWeekdayOf(context, listen: true);
  final now = DateTime.now();
  return [
    for (final program in programs.following)
      if (program.id case final String id)
        if (programs.position(program, now: now, firstWeekday: firstWeekday) case final position
            when !position.finished)
          (program: program, position: position, bases: programs.basesOf(id), sessionsDone: programs.sessionsDone(id)),
  ];
}

/// The goals [feeds] imply that [held] does not already hold.
List<ImpliedGoal> impliedBy(List<ProgramFeed> feeds, Iterable<Goal> held) {
  return [
    for (final (:program, :bases, position: _, sessionsDone: _) in feeds)
      ...impliedGoals(program, bases: bases, held: held),
  ];
}

/// Where [goal] heads under the first of [feeds] whose rules grow it.
GoalForecast? forecastFrom(List<ProgramFeed> feeds, Goal goal, num? current) {
  return feeds
      .map(
        (feed) => forecastOf(
          goal,
          current: current,
          program: feed.program,
          position: feed.position,
          bases: feed.bases,
          sessionsDone: feed.sessionsDone,
        ),
      )
      .nonNulls
      .firstOrNull;
}

/// A forecast as the user reads it: "On track for week 11".
String forecastLabel(L l, GoalForecast forecast) {
  return switch (forecast) {
    ForecastReached() => l.goalForecastReached,
    ForecastOnTrack(:final week) => l.goalForecastOnTrack(week),
    ForecastPastEnd(:final week) => l.goalForecastPastEnd(week),
    ForecastTooEarly() => l.goalForecastTooEarly,
  };
}
