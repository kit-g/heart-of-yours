import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

/// Local persistence of the user's template folders.
///
/// Folders are remote-first — the server mints ids and settles name conflicts —
/// so this is a mirror of confirmed state, never a queue of pending writes.
///
/// Defined here rather than in `heart_models` because that package is the
/// server's, and this is local bookkeeping the server has no notion of; the app
/// adapts `heart_db` onto it, the same joining `LocalGoalService` needs.
abstract interface class LocalTemplateFolderService {
  Future<Iterable<TemplateFolder>> getFolders(String userId);

  /// Replaces the stored set wholesale — the write of a successful full sync.
  Future<void> storeFolders(Iterable<TemplateFolder> folders, String userId);

  /// Upserts one server-confirmed folder.
  Future<void> storeFolder(TemplateFolder folder, String userId);

  /// Unfiles — never deletes — the templates inside.
  Future<void> deleteFolder(String folderId, String userId);
}

/// The one template write [ApiTemplateFolderService] does not carry: filing is
/// a template `PUT` with an explicit `folderId`, not a folder operation.
/// `RemoteTemplateService.editTemplate` cannot express it — a round-tripped
/// `Template.toMap()` has no `folderId` key, which the server reads as "leave
/// the filing alone".
abstract interface class RemoteTemplateFilingService {
  Future<Template> moveTemplate(Template template, {required String? folderId});
}

class Templates with ChangeNotifier, Iterable<Template> implements SignOutStateSentry {
  final _templates = SplayTreeSet<Template>();
  final _samples = SplayTreeSet<Template>();
  final _folders = SplayTreeSet<TemplateFolder>();
  final TemplateService _service;
  final RemoteTemplateService _remoteService;
  final RemoteConfigService _configService;
  final LocalTemplateFolderService _folderService;
  final ApiTemplateFolderService _remoteFolderService;
  final RemoteTemplateFilingService _filingService;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final int? maxTemplates;

  new({
    required this._remoteService,
    required this._service,
    required this._configService,
    required this._folderService,
    required this._remoteFolderService,
    required this._filingService,
    this.onError,
    this.maxTemplates,
  });

  Template? editable;

  String? userId;

  @override
  void onSignOut() {
    editable = null;
    userId = null;
    _templates.clear();
    _folders.clear();
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
      final id = userId!;
      final local = await _service.getTemplates(id);

      if (local.isNotEmpty) {
        _templates.addAll(local);
        notifyListeners();
      }

      final localFolders = await _folderService.getFolders(id);
      if (localFolders.isNotEmpty) {
        _folders.addAll(localFolders);
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

      final remoteFolders = (await _remoteFolderService.getFolders(userId: id)).toList();
      if (remoteFolders.isNotEmpty || _folders.isNotEmpty) {
        _folders
          ..clear()
          ..addAll(remoteFolders);
        notifyListeners();
      }
      // After the templates above: this replace also unfiles whatever points at
      // a folder the server no longer has, so it must see the final template
      // rows, not race ahead of them.
      await _folderService.storeFolders(remoteFolders, id);
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

  /// Drops the template being edited, deleting it if it was never saved.
  ///
  /// [add] writes a row the moment the first exercise lands, because
  /// `updateTemplate` edits a row rather than creating one. Leaving the editor
  /// used to clear [editable] and abandon that row, which came back on the next
  /// launch as a nameless, exerciseless card in Templates — an entry the editor
  /// itself refuses to save, since Save wants both a name and an exercise.
  ///
  /// Only the draft is deleted. A template already in the list is a real one
  /// being edited, and quitting that editor discards the edits, not the
  /// template. Local-only either way, so there is nothing to tell the server:
  /// a draft has never been sent to it.
  Future<void> discardEditable() async {
    final draft = editable;
    editable = null;
    notifyListeners();

    if (draft == null || _templates.any((each) => each.id == draft.id)) return;

    await _service.deleteTemplate(draft.id);
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

  /// The owner's arrangement: by position, ties broken by name.
  List<TemplateFolder> get folders => UnmodifiableListView<TemplateFolder>(_folders);

  /// The user's templates filed under [folder], or the unfiled ones when null.
  Iterable<Template> templatesIn(TemplateFolder? folder) {
    return _templates.where((template) => template.folderId == folder?.id);
  }

  /// Remote-first: the server mints the id and settles name conflicts, so a
  /// duplicate name throws here — the caller owns the apology — and nothing is
  /// kept locally that the server has not confirmed.
  Future<TemplateFolder> createFolder(String name) async {
    final order = (_folders.lastOrNull?.order ?? -1) + 1;
    final created = await _remoteFolderService.createFolder(
      userId: userId!,
      folder: TemplateFolder(name: name, order: order),
    );
    _folders.add(created);
    notifyListeners();
    await _folderService.storeFolder(created, userId!);
    return created;
  }

  Future<TemplateFolder> renameFolder(TemplateFolder folder, String name) async {
    final updated = await _remoteFolderService.updateFolder(
      userId: userId!,
      folderId: folder.id!,
      folder: folder.copyWith(name: name),
    );
    _folders
      ..remove(folder)
      ..add(updated);
    // every filed template nests its own copy of the folder; refresh them
    _refileAll(folder.id, updated);
    notifyListeners();
    await _folderService.storeFolder(updated, userId!);
    return updated;
  }

  /// The templates inside come back unfiled, here and on the server alike.
  Future<void> deleteFolder(TemplateFolder folder) async {
    await _remoteFolderService.deleteFolder(userId: userId!, folderId: folder.id!);
    _folders.remove(folder);
    _refileAll(folder.id, null);
    notifyListeners();
    await _folderService.deleteFolder(folder.id!, userId!);
  }

  /// Files [template] under [folder], or unfiles it when null. Optimistic: the
  /// move shows immediately and is rolled back if the server rejects it.
  Future<void> moveToFolder(Template template, TemplateFolder? folder) async {
    if (template.folderId == folder?.id) return;

    _swap(template, _filed(template, folder));
    notifyListeners();

    try {
      final saved = await _filingService.moveTemplate(template, folderId: folder?.id);
      _swap(template, saved);
      if (userId case final String id) {
        await _service.storeTemplates([saved], userId: id);
      }
    } catch (e, s) {
      _swap(template, template);
      notifyListeners();
      onError?.call(e, stacktrace: s);
    }
  }

  /// Replaces the in-memory copy keyed like [template] — same id, same slot in
  /// the ordered set — with [replacement].
  void _swap(Template template, Template replacement) {
    _templates
      ..remove(template)
      ..add(replacement);
  }

  void _refileAll(String? folderId, TemplateFolder? folder) {
    final affected = _templates.where((template) => template.folderId == folderId).toList();
    for (final template in affected) {
      _swap(template, _filed(template, folder));
    }
  }

  /// A [Template] carries its folder as an immutable nested copy, so refiling
  /// one means rebuilding it around the new folder.
  static Template _filed(Template template, TemplateFolder? folder) {
    final map = template.toMap()..remove('folder');
    return Template.fromJson({
      ...map,
      'folder': ?folder?.toMap(),
    });
  }
}

const _maxTemplates = 6;
