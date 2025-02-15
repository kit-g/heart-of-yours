import 'package:heart_models/src/models/exercise.dart';

import 'exercise_set.dart';
import 'workout.dart';

abstract interface class Template with Iterable<WorkoutExercise> implements HasExercises {
  String? get name;

  factory Template({
    required List<WorkoutExercise> exercises,
    String? name,
  }) {
    return _Template(
      name: name,
      exercises: exercises,
    );
  }

  factory Template.empty() {
    return _Template(exercises: []);
  }
}

class _Template with Iterable<WorkoutExercise> implements Template {
  @override
  final String? name;
  final List<WorkoutExercise> _exercises;

  _Template({
    required List<WorkoutExercise> exercises,
    this.name,
  }) : _exercises = exercises;

  @override
  Iterator<WorkoutExercise> get iterator => _exercises.iterator;

  @override
  WorkoutExercise add(Exercise exercise) {
    final ex = WorkoutExercise(starter: ExerciseSet(exercise));
    _exercises.add(ex);
    return ex;
  }

  @override
  bool remove(WorkoutExercise exercise) {
    return _exercises.remove(exercise);
  }

  @override
  bool operator ==(Object other) {
    return other is Template && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}
