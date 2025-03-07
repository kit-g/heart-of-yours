import 'dart:convert';

import 'exercise.dart';
import 'exercise_set.dart';
import 'misc.dart';
import 'workout.dart';

abstract interface class Template with Iterable<WorkoutExercise> implements Comparable<Template>, HasExercises, Model {
  abstract String? name;

  String get id;

  int get order;

  Workout toWorkout();

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
        final workoutExercise = WorkoutExercise(starter: sets.firstOrNull ?? ExerciseSet(exercise));
        for (var set in sets.skip(1)) {
          workoutExercise.add(set);
        }

        return workoutExercise;
      },
    ).toList();

    return _Template(
      id: first['templateId'].toString(),
      name: first['templateName'],
      order: first['orderInParent'] as int? ?? 0,
      exercises: exercises,
    );
  }

  factory Template.fromJson(Map json, ExerciseLookup lookForExercise) {
    return _Template(
      exercises: WorkoutExercise.fromCollection(json, lookForExercise),
      id: json['id'],
      order: json['order'],
      name: json['name'],
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

  @override
  Workout toWorkout() {
    final workout = Workout(name: name);

    for (final each in this) {
      if (each.isNotEmpty) {
        final exercise = WorkoutExercise(starter: each.first.copy());

        for (var (index, set) in each.skip(1).indexed) {
          final start = DateTime.timestamp().add(Duration(milliseconds: 2 * index));
          exercise.add(set.copy(start: start));
        }

        workout.append(exercise);
      }
    }

    return workout;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'exercises': {
        for (var exercise in this) exercise.id: exercise.toFullMap(),
      }
    };
  }
}

extension on WorkoutExercise {
  Map<String, dynamic> toFullMap() {
    return {
      'id': id,
      if (firstOrNull case ExerciseSet s) 'exercise': s.exercise.name,
      'sets': {
        for (var each in this) each.id: each.toMap(),
      }
    };
  }
}
