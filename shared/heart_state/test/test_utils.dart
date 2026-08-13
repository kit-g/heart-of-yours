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

// Convenience builders for real domain models used in tests
Exercise ex(String name, {Map<String, dynamic>? movement, bool archived = false}) {
  return Exercise.fromJson({
    'name': name,
    'category': 'Weighted Body Weight',
    'target': 'Chest',
    'asset': null,
    'thumbnail': null,
    'instructions': null,
    'archived': archived,
    'movement': ?movement,
  });
}

/// A movement annotation in wire shape. Defaults describe an unloaded, free,
/// bilateral, low-skill movement, so a test only states the attributes it is
/// actually about.
Map<String, dynamic> movement(
  List<String> groups, {
  String axialLoad = 'none',
  String stability = 'free',
  bool unilateral = false,
  String impact = 'none',
  String skill = 'low',
}) {
  return {
    'groups': groups,
    'axialLoad': axialLoad,
    'stability': stability,
    'unilateral': unilateral,
    'impact': impact,
    'skill': skill,
  };
}

Template tmpl({
  required String id,
  int order = 0,
  String? name,
  List<WorkoutExercise> exercises = const [],
  TemplateFolder? folder,
}) {
  final t = Template.empty(id: id, order: order, folder: folder);
  t.name = name;
  for (final we in exercises) {
    t.append(we);
  }
  return t;
}

TemplateFolder fldr({String id = 'f1', String name = 'Push', int order = 0}) {
  return TemplateFolder(id: id, name: name, order: order);
}

WorkoutExercise wEx(Exercise exercise, {int sets = 1}) {
  final starter = ExerciseSet(exercise);
  final we = WorkoutExercise(starter: starter);
  for (var i = 1; i < sets; i++) {
    we.add(starter.copy());
  }
  return we;
}
