import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// What a rule's numbers measure on [exercise], and how they read: a weight
/// in the user's unit, a time in seconds, or a distance in theirs — a carry's
/// in metres or yards, as its sets show it.
class GrowthMeasure {
  final String Function(num) format;

  const new(this.format);

  factory of(BuildContext context, Exercise exercise, GrowthRule? rule) {
    final copy = L.of(context);
    final preferences = Preferences.of(context);
    final override = Exercises.of(context).unitFor(exercise.id);
    final unit = override ?? preferences.weightUnit;

    String weight(num value) {
      final label = switch (unit) {
        .imperial => copy.lbs,
        .metric => copy.kg,
      };
      return '${preferences.weight(value, unit: unit)} $label';
    }

    String distance(num value) {
      final label = switch (override ?? preferences.distanceUnit) {
        .imperial => copy.milesPlural,
        .metric => copy.km,
      };
      return '${preferences.distance(value, unit: override)} $label';
    }

    String carried(num value) {
      final label = switch (override ?? preferences.distanceUnit) {
        .imperial => copy.yardsShort,
        .metric => copy.metresShort,
      };
      return '${preferences.shortDistance(value, unit: override)} $label';
    }

    String seconds(num value) => '${value.round()} ${copy.sec}';

    return switch (rule) {
      Longer() => switch (exercise.category) {
        .cardio => GrowthMeasure(distance),
        .weightedDistance => GrowthMeasure(carried),
        .duration ||
        .weightedDuration ||
        .barbell ||
        .dumbbell ||
        .machine ||
        .weightedBodyWeight ||
        .assistedBodyWeight ||
        .repsOnly => GrowthMeasure(seconds),
      },
      // a ladder keeps no base: there is nothing of its to measure
      null || NoGrowth() || AddWeight() || RangeThenWeight() || ShareOfMax() || Ladder() => GrowthMeasure(weight),
    };
  }
}
