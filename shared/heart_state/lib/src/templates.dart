import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Templates with ChangeNotifier, Iterable<Template> implements SignOutStateSentry {
  final _templates = SplayTreeSet<Template>();
  final _samples = SplayTreeSet<Template>();
  final TemplateService _service;
  final RemoteTemplateService _remoteService;
  final RemoteConfigService _configService;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final ExerciseLookup lookForExercise;

  Templates({
    required RemoteTemplateService remoteService,
    required TemplateService service,
    required RemoteConfigService configService,
    required this.lookForExercise,
    this.onError,
  })  : _service = service,
        _configService = configService,
        _remoteService = remoteService;

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
    final local = await _service.getTemplates(userId!, lookForExercise);

    if (local.isNotEmpty) {
      _templates.addAll(local);
      return notifyListeners();
    }

    final remote = await _remoteService.getTemplates(lookForExercise) ?? [];
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

  void append(WorkoutExercise exercise) {
    editable?.append(exercise);
    notifyListeners();
  }

  Future<void> saveEditable() async {
    if (editable case Template template) {
      _templates.add(template);
      await _service.updateTemplate(template);
      await _remoteService.saveTemplate(template);
    }
    editable = null;

    notifyListeners();
  }

  Future<void> delete(Template template) {
    _templates.remove(template);
    notifyListeners();
    return Future.wait(
      [
        _service.deleteTemplate(template.id),
        _remoteService.deleteTemplate(template.id),
      ],
    );
  }

  bool get allowsNewTemplate => length < _maxTemplates;

  Future<void> _initSampleTemplates(ExerciseLookup lookForExercise) async {
    final local = await _service.getTemplates(null, lookForExercise);
    if (local.isNotEmpty) {
      return _samples.addAll(local);
    }

    final remote = await _configService.getSampleTemplates(lookForExercise);
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
