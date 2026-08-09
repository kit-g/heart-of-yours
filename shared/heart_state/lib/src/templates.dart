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
  final int? maxTemplates;

  Templates({
    required RemoteTemplateService remoteService,
    required TemplateService service,
    required RemoteConfigService configService,
    this.onError,
    this.maxTemplates,
  }) : _service = service,
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
    _initSampleTemplates();
    if (userId == null) return;

    // Nobody awaits this — it is started from app init and left to run — so an
    // escaping error becomes an unhandled async one and is reported as a fatal
    // crash. Route it through [onError] like every other initializer instead:
    // the samples above are already in place and the app stays usable.
    try {
      final local = await _service.getTemplates(userId!);

      if (local.isNotEmpty) {
        _templates.addAll(local);
        notifyListeners();
      }

      final remote = await _remoteService.getTemplates() ?? [];
      if (remote.isNotEmpty) {
        _templates
          ..removeWhere(remote.contains)
          ..addAll(remote);
        notifyListeners();
        await _service.storeTemplates(remote, userId: userId);
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
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

      try {
        final save = template.local ? _remoteService.saveTemplate : _remoteService.editTemplate;

        final saved = await save(template);
        _templates
          ..remove(template)
          ..add(saved);
        if (userId case String id) {
          // A locally-created template is persisted under a client-generated
          // id, but the server assigns its own id on save. Drop the stale local
          // row first, otherwise storing the server copy leaves a duplicate.
          if (saved.id != template.id) {
            await _service.deleteTemplate(template.id);
          }
          await _service.storeTemplates([saved], userId: id);
        }
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
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

  bool get allowsNewTemplate => length < (maxTemplates ?? _maxTemplates);

  Future<void> _initSampleTemplates() async {
    final local = await _service.getTemplates(null);
    if (local.isNotEmpty) {
      _samples.addAll(local);
    }

    final remote = await _configService.getSampleTemplates();
    _samples
      ..removeWhere(remote.contains)
      ..addAll(remote);
    _service.storeTemplates(remote);
  }

  Future<void> workoutToTemplate(Workout workout) async {
    final raw = await _service.startTemplate(userId: userId);
    editable = Template.fromWorkout(raw.id, workout, raw.order);
    return notifyListeners();
  }
}

const _maxTemplates = 6;
