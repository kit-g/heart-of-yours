import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Templates with ChangeNotifier, Iterable<Template> implements SignOutStateSentry {
  final _templates = SplayTreeSet<Template>();
  final TemplateService _service;

  Templates({required TemplateService service}) : _service = service;

  Template? editable;

  String? userId;

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

  Future<void> init() async {
    if (userId == null) return;
    return _service.getTemplates(userId!).then<void>(
      (templates) {
        _templates.addAll(templates);
        notifyListeners();
      },
    );
  }

  Future<void> add(Exercise exercise) async {
    editable ??= await _service.startTemplate(
      userId: userId,
      order: (_templates.lastOrNull?.order ?? 0) + 1,
    );
    editable?.add(exercise);
    notifyListeners();
  }

  void remove(WorkoutExercise exercise) {
    editable?.remove(exercise);
  }

  void addSet(WorkoutExercise exercise) {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    exercise.add(set);
    notifyListeners();
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    exercise.remove(set);
    notifyListeners();
  }

  void removeExercise(WorkoutExercise exercise) {
    editable?.remove(exercise);
    notifyListeners();
  }

  Future<void> saveEditable() async {
    if (editable case Template template) {
      _templates.add(template);
      await _service.updateTemplate(template);
    }
    editable = null;

    notifyListeners();
  }

  Future<void> delete(Template template) {
    _templates.remove(template);
    notifyListeners();
    return _service.deleteTemplate(template.id);
  }

  bool get allowsNewTemplate => length < _maxTemplates;
}

const _maxTemplates = 6;
