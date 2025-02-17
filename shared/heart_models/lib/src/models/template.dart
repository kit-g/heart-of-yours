import 'dart:convert';

import 'exercise.dart';
import 'exercise_set.dart';
import 'workout.dart';

abstract interface class Template with Iterable<WorkoutExercise> implements Comparable<Template>, HasExercises {
  abstract String? name;

  String get id;

  int get order;

  factory Template.empty({required String id, required int order}) {
    return _Template(
      exercises: [],
      id: id,
      order: order,
    );
  }

  factory Template.fromRows(List<Map<String, dynamic>> rows) {
    assert(rows.isNotEmpty, 'Cannot create a Template from an empty row list.');

    final first = rows.first;

    final exercises = rows.map<WorkoutExercise>(
      (row) {
        final exercise = Exercise.fromJson(row);
        final desc = jsonDecode(row['description'] as String) as List;
        final sets = desc.map<ExerciseSet>(
          (json) {
            return ExerciseSet.fromJson(exercise, json);
          },
        ).toList();
        final workoutExercise = WorkoutExercise(starter: sets.first);

        for (var set in sets.skip(1)) {
          workoutExercise.add(set);
        }

        return workoutExercise;
      },
    ).toList();

    return _Template(
      id: first['templateId'].toString(),
      name: first['name'],
      order: first['orderInParent'] as int? ?? 0,
      exercises: exercises,
    );
  }
}

class _Template with Iterable<WorkoutExercise> implements Template {
  @override
  final String id;
  @override
  String? name;
  @override
  int order;
  final List<WorkoutExercise> _exercises;

  _Template({
    required List<WorkoutExercise> exercises,
    this.name,
    required this.id,
    required this.order,
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
    return other is Template && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  int compareTo(Template other) {
    return order.compareTo(other.order);
  }
}
