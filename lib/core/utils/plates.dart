import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The nearest weight the user's plates make: 2.5 kg, or 5 lb, in the unit
/// they count that exercise in. What a program's worked-out weight is shown
/// as (#349), on the user's own sheet or a coach's for a client (#560).
RoundWeight roundToPlates(BuildContext context) {
  final preferences = Preferences.of(context);
  final exercises = Exercises.of(context);
  return (exercise, kilograms) => switch (exercises.unitFor(exercise.id) ?? preferences.weightUnit) {
    .metric => (kilograms / 2.5).round() * 2.5,
    .imperial => ((kilograms.asPounds / 5).round() * 5).asKilograms,
  };
}
