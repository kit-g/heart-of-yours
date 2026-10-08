import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'analytics.dart';
import 'remote.dart';

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
  final RemoteAccess _remote;
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
    this.analytics,
    RemoteAccess? remote,
  }) : _remote = remote ?? RemoteAccess();

  /// Whether templates are a feature or a graveyard, and which of the two ways
  /// of making one people actually use. Absent in tests.
  final Analytics? analytics;

  Template? editable;

  String? userId;

  bool _ownLoaded = false;
  bool _samplesLoaded = false;

  /// Whether the device's templates have been read: the user's own from the
  /// mirror and the samples. What a caller that arrived before [init] finished
  /// — a link naming a template (#284) — waits for; the server's copies may
  /// still be on their way.
  bool get hasLoaded => _ownLoaded && _samplesLoaded;

  /// A template by its id, the user's own or a sample, or null for one this
  /// device does not have.
  Template? lookup(String id) {
    return _templates.where((template) => template.id == id).firstOrNull ??
        _samples.where((template) => template.id == id).firstOrNull;
  }

  @override
  void onSignOut() {
    editable = null;
    userId = null;
    _ownLoaded = false;
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
    if (userId == null) {
      _ownLoaded = true;
      return;
    }

    // Nobody awaits this — it is started from app init and left to run — so an
    // escaping error becomes an unhandled async one and is reported as a fatal
    // crash. Each step routes it through [onError] instead, and the next still
    // runs: local templates that fail to read must not keep the folders, or
    // the server's copies, from loading.
    final id = userId!;
    await _step(() async {
      final local = await _service.getTemplates(id);
      if (local.isNotEmpty) {
        _templates.addAll(local);
        notifyListeners();
      }
      // The user's own, never the samples: every account has those, so
      // counting them would put everyone in the same bucket.
      analytics?.setTemplatesBucket(_templates.length);
    });
    // read, whether or not anything was there — or the read failed, which
    // [_step] has reported; nothing is still to come from this device
    _ownLoaded = true;

    await _step(() async {
      final localFolders = await _folderService.getFolders(id);
      if (localFolders.isNotEmpty) {
        _folders.addAll(localFolders);
        notifyListeners();
      }
    });

    // the mirror is the whole story until there is a server to reconcile with
    if (!_remote.allowed) return;

    await _step(() async {
      final remote = await _remoteService.getTemplates() ?? [];
      if (remote.isNotEmpty) {
        _templates
          ..removeWhere(remote.contains)
          ..addAll(remote);
        notifyListeners();
        await _service.storeTemplates(remote, userId: userId);
      }
    });

    // After the templates above: this replace also unfiles whatever points at
    // a folder the server no longer has, so it must see the final template
    // rows, not race ahead of them. The server's list is read whole or not at
    // all, so a failure leaves the local folders as they are.
    await _step(() async {
      final remoteFolders = (await _remoteFolderService.getFolders(userId: id)).toList();
      if (remoteFolders.isNotEmpty || _folders.isNotEmpty) {
        _folders
          ..clear()
          ..addAll(remoteFolders);
        notifyListeners();
      }
      await _folderService.storeFolders(remoteFolders, id);
    });
  }

  /// Runs one step of [init], reporting what it throws instead of letting it
  /// cost the steps after it.
  Future<void> _step(Future<void> Function() body) async {
    try {
      await body();
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
    // a plain set, whatever the last one was: a warm-up is not what comes
    // after a warm-up (Strong and Hevy agree)
    final set = switch (exercise.lastOrNull) {
      ExerciseSet last => last.copy()..setType = .normal,
      null => ExerciseSet(exercise.exercise),
    };
    exercise.add(set);
    notifyListeners();
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    exercise.remove(set);
    notifyListeners();
  }

  /// Retypes [set] in the template being edited; saved with the rest of it.
  void setSetType(ExerciseSet set, SetType type) {
    set.setType = type;
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
      // `local` is the server-id-not-yet-assigned mark, which is exactly what
      // separates a new template from an edit to an existing one.
      if (template.local) analytics?.templateCreated(source: .editor);
      await _save(template);
    }
    editable = null;

    notifyListeners();
  }

  /// A new template of the user's own holding [template]'s exercises, sets
  /// and notes, named [name] — the caller's, since "(copy)" is copy — and
  /// filed where the original is. Saved outright rather than opened in the
  /// editor: the point is week 2 out of week 1 without rebuilding it set by
  /// set, and the editor is a tap away. It sorts last, like any new template.
  ///
  /// A sample is nobody's to edit, so its copy is how one gets edited; it
  /// comes out unfiled, as the sample was.
  ///
  /// Notifies as soon as the copy is in the list, and again once the server
  /// has had its say — its row replaces the copy, as with any save.
  Future<Template> duplicate(Template template, {required String name}) async {
    analytics?.templateCreated(source: .duplicate);
    final raw = await _service.startTemplate(
      userId: userId,
      order: (_templates.lastOrNull?.order ?? 0) + 1,
    );
    final copy = Template.fromWorkout(raw.id, _copyOf(template), raw.order, folder: template.folder)..name = name;
    _templates.add(copy);
    notifyListeners();
    final saved = await _save(copy);
    notifyListeners();
    return saved;
  }

  /// [template]'s exercises as fresh objects under fresh ids, with the sets'
  /// values and types and each exercise's note — which [Template.toWorkout]
  /// leaves behind, so this is not that. An exercise without sets is not
  /// carried, as there.
  static Workout _copyOf(Template template) {
    WorkoutExercise exerciseCopy(WorkoutExercise exercise) {
      final copy = WorkoutExercise(starter: exercise.first.copy())..note = exercise.note;
      exercise.skip(1).map((set) => set.copy()).forEach(copy.add);
      return copy;
    }

    return Workout.fromExercises([
      for (final exercise in template)
        if (exercise.isNotEmpty) exerciseCopy(exercise),
    ]);
  }

  /// Keeps [template] here and in the mirror and, with the remote leg open,
  /// sends it to the server, whose row then replaces it in both. Returns
  /// whichever of the two stayed.
  ///
  /// With the remote leg closed the template stays [Template.local] under its
  /// client-minted id — the state a template made offline is in until a save
  /// reaches the server.
  Future<Template> _save(Template template) async {
    _templates.add(template);
    await _service.updateTemplate(template);

    if (!_remote.allowed) return template;

    try {
      final save = template.local ? _remoteService.saveTemplate : _remoteService.editTemplate;

      final saved = await save(template);
      _swap(template, saved);
      if (userId case String id) {
        // A locally-created template is persisted under a client-generated
        // id, but the server assigns its own id on save. Drop the stale local
        // row first, otherwise storing the server copy leaves a duplicate.
        if (saved.id != template.id) {
          await _service.deleteTemplate(template.id);
        }
        await _service.storeTemplates([saved], userId: id);
      }
      return saved;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return template;
    }
  }

  Future<void> delete(Template template) {
    _templates.remove(template);
    notifyListeners();
    return Future.wait(
      [
        _service.deleteTemplate(template.id),
        if (_remote.allowed) _remoteService.deleteTemplate(template.id),
      ],
    );
  }

  /// Folders are remote-first — the server mints their ids — so there are none
  /// to be had while the remote leg is closed. The pages hide the affordances;
  /// this is the tripwire behind them.
  void _requireRemote() {
    if (!_remote.allowed) throw StateError('template folders need the remote leg');
  }

  bool get allowsNewTemplate => length < (maxTemplates ?? _maxTemplates);

  /// The device locale changed. Sample templates carry localized names picked
  /// at fetch time, so the cached batch is stale in the new language —
  /// re-fetch, which repaints.
  Future<void> onLocaleChanged() => _initSampleTemplates();

  /// Nobody awaits this either (see [init]) — an escaping error would surface
  /// as an unhandled async exception on every launch. Samples are decoration:
  /// failing to fetch them must cost nothing but the samples.
  ///
  /// Notifies once they are in. It used not to, and a signed-in user never
  /// noticed: their own templates load right after and notify for both. An
  /// anonymous one with no templates of their own has nothing else to repaint
  /// the page, and saw "Example templates" over an empty space until something
  /// unrelated rebuilt it.
  Future<void> _initSampleTemplates() async {
    try {
      final local = await _service.getTemplates(null);
      if (local.isNotEmpty) {
        _samples.addAll(local);
      }

      final remote = await _configService.getSampleTemplates();
      _samples
        ..removeWhere(remote.contains)
        ..addAll(remote);
      _service.storeTemplates(remote);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
    _samplesLoaded = true;
    // whatever arrived, local or remote, before a failure or after
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> workoutToTemplate(Workout workout) async {
    analytics?.templateCreated(source: .fromWorkout);
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
    analytics?.templateFolderCreated();
    _requireRemote();
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
    _requireRemote();
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
    _requireRemote();
    await _remoteFolderService.deleteFolder(userId: userId!, folderId: folder.id!);
    _folders.remove(folder);
    _refileAll(folder.id, null);
    notifyListeners();
    await _folderService.deleteFolder(folder.id!, userId!);
  }

  /// Files [template] under [folder], or unfiles it when null. Optimistic: the
  /// move shows immediately and is rolled back if the server rejects it.
  Future<void> moveToFolder(Template template, TemplateFolder? folder) async {
    analytics?.templateMoved(filed: folder != null);
    if (template.folderId == folder?.id) return;
    _requireRemote();

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
