import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Which kind of rest an exercise takes (#174): what it is loaded with first,
/// then its movement pattern, then — with no pattern — its equipment.
void main() {
  Exercise exercise(Category category, {List<String> patterns = const []}) {
    return Exercise(
      name: 'Muffin lift',
      category: category,
      target: .chest,
      movement: switch (patterns) {
        [] => null,
        _ => Movement.fromJson({'groups': patterns}),
      },
    );
  }

  test('a loaded lift of a compound pattern rests as compound', () {
    expect(restKindOf(exercise(.barbell, patterns: ['squat_bilateral'])), RestKind.compound);
    expect(restKindOf(exercise(.dumbbell, patterns: ['horizontal_press'])), RestKind.compound);
    expect(restKindOf(exercise(.weightedBodyWeight, patterns: ['vertical_pull'])), RestKind.compound);
  });

  test('a loaded lift of any other pattern rests as isolation', () {
    expect(restKindOf(exercise(.barbell, patterns: ['elbow_flexion'])), RestKind.isolation);
    expect(restKindOf(exercise(.machine, patterns: ['knee_extension'])), RestKind.isolation);
    // a pattern this build has no word for still names an exercise with one
    expect(restKindOf(exercise(.dumbbell, patterns: ['hip_thrust_new'])), RestKind.isolation);
  });

  test('the body as the load, or a clock, rests as conditioning whatever the pattern', () {
    expect(restKindOf(exercise(.repsOnly, patterns: ['horizontal_press'])), RestKind.conditioning);
    expect(restKindOf(exercise(.assistedBodyWeight, patterns: ['vertical_pull'])), RestKind.conditioning);
    expect(restKindOf(exercise(.cardio)), RestKind.conditioning);
    expect(restKindOf(exercise(.duration, patterns: ['core_bracing'])), RestKind.conditioning);
  });

  test('a conditioning pattern under a load rests as conditioning', () {
    expect(restKindOf(exercise(.dumbbell, patterns: ['full_body_conditioning'])), RestKind.conditioning);
  });

  test('a compound pattern outranks any other the exercise also trains', () {
    expect(restKindOf(exercise(.barbell, patterns: ['shrug', 'deadlift_floor'])), RestKind.compound);
  });

  test("without a pattern, the equipment's guess", () {
    expect(restKindOf(exercise(.barbell)), RestKind.compound);
    expect(restKindOf(exercise(.weightedBodyWeight)), RestKind.compound);
    expect(restKindOf(exercise(.dumbbell)), RestKind.isolation);
    expect(restKindOf(exercise(.machine)), RestKind.isolation);
    expect(restKindOf(exercise(.weightedDistance)), RestKind.conditioning);
    expect(restKindOf(exercise(.weightedDuration)), RestKind.conditioning);
  });
}
