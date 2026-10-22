import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/commands.dart';
import 'package:heart_models/heart_models.dart';

/// What a second actor — a watch, a voice command — may fill in on a set, by
/// the exercise's category: a load is a weight, and only lifts take a count.
void main() {
  (bool, bool) measures(Category category) {
    final exercise = Exercise(name: 'X', category: category, target: .arms);
    return measuresOf(WorkoutExercise(starter: ExerciseSet(exercise)));
  }

  test('lifts take a weight and a count', () {
    for (final Category category in [.barbell, .dumbbell, .machine, .assistedBodyWeight, .weightedBodyWeight]) {
      expect(measures(category), (true, true), reason: '$category');
    }
  });

  test('a load held for a time or carried for a distance takes a weight and no count (#483)', () {
    expect(measures(.weightedDuration), (true, false), reason: 'Dead Hang (Weighted)');
    expect(measures(.weightedDistance), (true, false), reason: "Farmer's Carry");
  });

  test('reps only take a count; time and distance alone take neither', () {
    expect(measures(.repsOnly), (false, true));
    expect(measures(.duration), (false, false), reason: 'Dead Hang');
    expect(measures(.cardio), (false, false));
  });
}
