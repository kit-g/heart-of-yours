part of 'workout_detail.dart';

/// Adds warm-up sets before an exercise's others (#158).
typedef AddWarmups = void Function(WorkoutExercise, Iterable<WarmupSet>);

/// The warm-ups [exercise] would get from its first working set, in the unit
/// its weights are read in. Empty when it gets none: not a bar or a stack,
/// warm-ups already there, no weight yet, or one too light to need them.
List<WarmupSet> _warmupsFor(WorkoutExercise exercise, Preferences prefs, Exercises exercises) {
  return switch (exercise.firstOrNull?.weight) {
    final double weight when !exercise.any((set) => set.setType == .warmup) => warmupSets(
      working: weight,
      category: exercise.exercise.category,
      unit: exercises.unitFor(exercise.exercise.id) ?? prefs.weightUnit,
      scheme: prefs.warmupScheme,
    ),
    _ => const [],
  };
}

/// The exercise the warm-ups' one offer sits under, by id: the first on the
/// sheet that would get warm-ups and whose first set is not done yet — warming
/// up to a set already lifted is no way to meet the feature. Null while there
/// is nothing to offer, or nothing owed after a no.
String? _warmupsAnchor(Iterable<WorkoutExercise> sheet, Preferences prefs, Exercises exercises) {
  const feature = Feature.warmups;
  if (!prefs.shouldOffer(feature) && !prefs.owesDeclineNotice(feature)) return null;
  return sheet
      .where((each) => each.firstOrNull?.isCompleted == false && _warmupsFor(each, prefs, exercises).isNotEmpty)
      .firstOrNull
      ?.id;
}

/// [sets] in a line, as the offer previews them: "20 kg × 5, 25 kg × 3".
String _warmupsLine(L l, Preferences prefs, MeasurementUnit? override, Iterable<WarmupSet> sets) {
  final unit = switch (override ?? prefs.weightUnit) {
    .imperial => l.lbs,
    .metric => l.kg,
  };
  return sets
      .map((set) => l.warmupSetSummary('${prefs.weight(set.weight, unit: override)} $unit', set.reps))
      .join(', ');
}

/// The one ask for warm-up sets (#158), under the exercise that first has a
/// weight to warm up to, and the one notice a no earns. Not in the way: it
/// sits below the sets, so nothing being typed into moves.
///
/// A yes is the whole feature, and the warm-ups this exercise was offered.
class const _WarmupsPrompt({
  required final WorkoutExercise exercise,
  required final AddWarmups onAdd,
}) extends StatelessWidget {
  static const _feature = Feature.warmups;

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    final l = L.of(context);

    return switch (preferences) {
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when preferences.shouldOffer(_feature) => FeatureOffer(
        key: WorkoutDetailKeys.warmupsOffer,
        acceptKey: WorkoutDetailKeys.warmupsAccept,
        declineKey: WorkoutDetailKeys.warmupsDecline,
        icon: _feature.icon,
        title: l.warmupsOfferTitle,
        body: l.warmupsOfferBody(
          _warmupsLine(
            l,
            preferences,
            exercises.unitFor(exercise.exercise.id),
            _warmupsFor(exercise, preferences, exercises),
          ),
        ),
        onAnswer: (yes) {
          // read before the answer: on, the offer is gone and so is its anchor
          final sets = _warmupsFor(exercise, preferences, exercises);
          preferences.answerOffer(_feature, yes: yes);
          if (yes) onAdd(exercise, sets);
        },
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
