import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/utils.dart';
import 'package:provider/provider.dart';

class Templates with ChangeNotifier, Iterable<Template> implements SignOutStateSentry {
  final _templates = SplayTreeSet<Template>();
  final _samples = SplayTreeSet<Template>();
  final TemplateService _service;
  final _db = FirebaseFirestore.instance;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final ExerciseLookup lookForExercise;

  Templates({
    required TemplateService service,
    required this.lookForExercise,
    this.onError,
  }) : _service = service;

  Template? editable;

  String? userId;

  @override
  void onSignOut() {
    editable = null;
    userId = null;
    _templates.clear();
  }

  @override
  Iterator<Template> get iterator => _templates.iterator;

  List<Template> get samples => UnmodifiableListView<Template>(_samples);

  static Templates of(BuildContext context) {
    return Provider.of<Templates>(context, listen: false);
  }

  static Templates watch(BuildContext context) {
    return Provider.of<Templates>(context, listen: true);
  }

  Future<void> init() async {
    _initSampleTemplates(lookForExercise);
    if (userId == null) return;
    final local = await _service.getTemplates(userId!);

    if (local.isNotEmpty) {
      _templates.addAll(local);
      return notifyListeners();
    }

    final remote = await _getRemoteTemplates() ?? [];

    if (remote.isNotEmpty) {
      _templates.addAll(remote);
      notifyListeners();
      return _service.storeTemplates(remote, userId: userId);
    }
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

  void swap(WorkoutExercise toInsert, WorkoutExercise before) {
    editable?.swap(toInsert, before);
    notifyListeners();
  }

  Future<void> saveEditable() async {
    if (editable case Template template) {
      _templates.add(template);
      await _service.updateTemplate(template);
      await _saveRemoteTemplate(template);
    }
    editable = null;

    notifyListeners();
  }

  Future<void> _saveRemoteTemplate(Template template) async {
    if (userId case String userId) {
      final doc = {
        'templates.${template.id}': template.toMap(),
      };
      return _db.collection('users').doc(userId).update(doc);
    }
  }

  Future<void> _deleteRemoteTemplate(String templateId) async {
    if (userId case String userId) {
      final doc = {
        'templates.$templateId': FieldValue.delete(),
      };
      return _db.collection('users').doc(userId).update(doc);
    }
  }

  Future<Iterable<Template>?> _getRemoteTemplates() async {
    if (userId case String userId) {
      final snapshot = await _db //
          .collection('users')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        return switch (snapshot.data()?['templates']) {
          Map m => m.values.map((each) => Template.fromJson(fromFirestoreMap(each), lookForExercise)).toList(),
          _ => null,
        };
      }
    }
    return null;
  }

  Future<void> delete(Template template) {
    _templates.remove(template);
    notifyListeners();
    return Future.wait(
      [
        _service.deleteTemplate(template.id),
        _deleteRemoteTemplate(template.id),
      ],
    );
  }

  bool get allowsNewTemplate => length < _maxTemplates;

  Future<Iterable<Template>> _getRemoteSampleTemplates(ExerciseLookup lookForExercise) async {
    final all = await _db //
        .collection('templates')
        .withConverter<Template>(
          fromFirestore: (snapshot, _) => Template.fromJson(snapshot.data()!, lookForExercise),
          toFirestore: (template, _) => template.toMap(),
        )
        .get();
    return all.docs.map((each) => each.data());
  }

  Future<void> _initSampleTemplates(ExerciseLookup lookForExercise) async {
    final local = await _service.getTemplates(null);
    if (local.isNotEmpty) {
      return _samples.addAll(local);
    }

    final remote = await _getRemoteSampleTemplates(lookForExercise);
    _service.storeTemplates(remote);
    _samples.addAll(remote);
  }

  Future<void> workoutToTemplate(Workout workout) async {
    final raw = await _service.startTemplate(userId: userId);
    editable = Template.fromWorkout(raw.id, workout, raw.order);
    return notifyListeners();
  }
}

const _maxTemplates = 6;
