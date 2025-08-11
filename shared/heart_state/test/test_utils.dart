import 'package:flutter/foundation.dart';
import 'package:heart_models/heart_models.dart';

// Increments and returns a function to attach as a listener for ChangeNotifier
int addCounterListener(ChangeNotifier notifier) {
  var count = 0;
  notifier.addListener(() => count++);
  // store count in a closure variable by returning getter? Simpler: caller captures reference.
  // Since Dart passes primitives by value, return the count initial value and rely on external closure not possible.
  // Provide a small wrapper type instead.
  return count; // Not used directly; prefer ListenerProbe below.
}

class ListenerProbe {
  int notifications = 0;
  void attach(ChangeNotifier notifier) {
    notifier.addListener(() => notifications++);
  }
}

// Builds a simple ExerciseLookup from a map of name->Exercise
ExerciseLookup buildLookup(Map<String, Exercise> registry) {
  return (id) => registry[id];
}

// Convenience builders for real domain models used in tests
Exercise ex(String name) {
  return Exercise.fromJson({
    'name': name,
    'category': 'Weighted Body Weight',
    'target': 'Chest',
    'asset': null,
    'thumbnail': null,
    'instructions': null,
  });
}

Template tmpl({required String id, int order = 0, String? name, List<WorkoutExercise> exercises = const []}) {
  final t = Template.empty(id: id, order: order);
  t.name = name;
  for (final we in exercises) {
    t.append(we);
  }
  return t;
}

WorkoutExercise wEx(Exercise exercise, {int sets = 1}) {
  final starter = ExerciseSet(exercise);
  final we = WorkoutExercise(starter: starter);
  for (var i = 1; i < sets; i++) {
    we.add(starter.copy());
  }
  return we;
}
