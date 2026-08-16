import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/exercises/previous_exercise.dart';
import 'package:heart_models/heart_models.dart';

/// A set's "Previous" cell only earns its tappable pill when the previous
/// value actually shows something. Legacy rows (null weight, junk fields from
/// the old serializer) fall through to a bare dash — boxing a dash was the
/// "wrapped around by the box wrong" bug.
void main() {
  final bench = Exercise(name: 'Bench Press (Barbell)', category: .barbell, target: .chest);
  final dips = Exercise(name: 'Bench Dip', category: .weightedBodyWeight, target: .arms);
  final pullUps = Exercise(name: 'Pull Up', category: .repsOnly, target: .back);
  final plank = Exercise(name: 'Plank', category: .duration, target: .core);
  final run = Exercise(name: 'Running', category: .cardio, target: .cardio);

  group('PreviousSet.represents', () {
    test('weight categories need both reps and weight', () {
      expect(PreviousSet.represents(bench, {'reps': 5, 'weight': 100.0}), isTrue);
      expect(PreviousSet.represents(bench, {'reps': 5, 'weight': 100}), isTrue);
      expect(PreviousSet.represents(bench, {'reps': 5}), isFalse);
      expect(PreviousSet.represents(bench, {'reps': 5, 'weight': null}), isFalse);
      expect(PreviousSet.represents(dips, {'weight': 10.0}), isFalse);
    });

    test('legacy junk with the right fields still counts', () {
      // the old serializer wrote zeros for foreign fields; reps+weight are real
      expect(
        PreviousSet.represents(bench, {'completed': true, 'reps': 12, 'duration': 0, 'distance': 0.0, 'weight': 60.0}),
        isTrue,
      );
    });

    test('reps-only needs reps', () {
      expect(PreviousSet.represents(pullUps, {'reps': 12}), isTrue);
      expect(PreviousSet.represents(pullUps, {'weight': 60.0}), isFalse);
    });

    test('duration needs duration', () {
      expect(PreviousSet.represents(plank, {'duration': 90}), isTrue);
      expect(PreviousSet.represents(plank, {'reps': 12}), isFalse);
    });

    test('cardio needs duration and distance', () {
      expect(PreviousSet.represents(run, {'duration': 600, 'distance': 2.5}), isTrue);
      expect(PreviousSet.represents(run, {'duration': 600}), isFalse);
      expect(PreviousSet.represents(run, {'distance': 2.5}), isFalse);
    });
  });
}
