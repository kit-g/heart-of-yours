import 'package:heart/core/utils/column_fill.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// What "Replace exercise" on the sheet suggests for [exercise] (#354): the
/// exercise page's "also try" — the same movement pattern first, nearest in
/// load after — kept to those whose sets can take [exercise]'s, the first
/// [limit] of them.
///
/// The one place a suggestion is ranked or left out. A program's constraint
/// (#355) and the exercises the user goes easy on (#396) narrow or reorder
/// here, and every picker that suggests a replacement follows.
List<Exercise> replacementsFor(Exercises exercises, Exercise exercise, {int limit = 5}) {
  return exercises.alternativesTo(exercise).where((each) => logsAlike(each, exercise)).take(limit).toList();
}
