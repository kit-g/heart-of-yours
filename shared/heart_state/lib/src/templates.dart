import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Templates with ChangeNotifier, Iterable<Template> implements SignOutStateSentry {
  final _templates = <Template>{};
  final TemplateService _service;

  Templates({required TemplateService service}) : _service = service;

  Template? editable;

  @override
  void onSignOut() {
    _templates.clear();
  }

  @override
  Iterator<Template> get iterator => _templates.iterator;

  static Templates of(BuildContext context) {
    return Provider.of<Templates>(context, listen: false);
  }

  static Templates watch(BuildContext context) {
    return Provider.of<Templates>(context, listen: true);
  }

  void add(Exercise exercise) {
    editable ??= Template.empty();
    editable?.add(exercise);
    notifyListeners();
  }

  void remove(WorkoutExercise exercise) {
    editable?.remove(exercise);
  }

  Future<void> addSet(WorkoutExercise exercise) async {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    exercise.add(set);
    notifyListeners();
  }

  Future<void> saveEditable() async {
    if (editable != null) {
      _templates.add(editable!);
    }
    editable = null;

    notifyListeners();
  }
}
