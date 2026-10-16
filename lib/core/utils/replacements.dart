import 'package:flutter/widgets.dart';
import 'package:heart/core/utils/column_fill.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// What "Replace exercise" on the sheet suggests for [exercise] (#354): the
/// exercise page's "also try" — the same movement pattern first, nearest in
/// load after — kept to those whose sets can take [exercise]'s, the first
/// [limit] of them.
///
/// The one place a suggestion is ranked or left out:
/// - a program's [constraint] (#355) leaves out what is harder on it, and
///   only inside that program — outside it the caller passes none;
/// - what the user goes easy on, [goEasy] (#396), leaves out what is harder
///   on anything listed, and puts what the map calls kinder to the source's
///   concerns first, the "also try" order kept within each.
List<Exercise> replacementsFor(
  Exercises exercises,
  Exercise exercise, {
  GoEasyEntry? constraint,
  List<GoEasyEntry> goEasy = const [],
  int limit = 5,
}) {
  final avoided = [?constraint, ...goEasy];
  final concerns = avoided.where((entry) => entry.isHarderOn(exercise)).toList();
  int kindness(Exercise candidate) => concerns.where((entry) => entry.isKinderTo(candidate)).length;

  final candidates = exercises
      .alternativesTo(exercise)
      .where((each) => logsAlike(each, exercise) && !avoided.any((entry) => entry.isHarderOn(each)))
      .toList();
  // List.sort isn't stable: the "also try" rank breaks ties
  final rank = {for (final (index, each) in candidates.indexed) each.id: index};
  candidates.sort((a, b) {
    final byKindness = kindness(b).compareTo(kindness(a));
    if (byKindness != 0) return byKindness;
    return rank[a.id]!.compareTo(rank[b.id]!);
  });
  return candidates.take(limit).toList();
}

/// [replacementsFor] as the active workout asks it: with its program's
/// constraint while Programs is on and the workout is one of its sessions,
/// and with what the user goes easy on while Programs is on.
List<Exercise> replacementsInWorkout(BuildContext context, Exercise exercise) {
  final programsOn = Preferences.of(context).isOn(.programs);
  if (!programsOn) return replacementsFor(Exercises.of(context), exercise);

  final easy = GoEasy.of(context);
  final constraint = switch (Workouts.of(context).activeWorkout?.programId) {
    final String id => easy.entryFor(Programs.of(context).lookup(id)?.constraint),
    null => null,
  };
  return replacementsFor(Exercises.of(context), exercise, constraint: constraint, goEasy: easy.listed);
}
