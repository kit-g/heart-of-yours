import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'analytics.dart';
import 'client_programs.dart' show isProgramChanged;
import 'remote.dart';
import 'template_drafting.dart';

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

  /// One template by its id: a session of the program a push named (#567).
  /// Here rather than on `RemoteTemplateService`, which is the server's
  /// contract and has no such call.
  Future<Template> getTemplate(String templateId);

  /// A session of a coach's copy (#558), from the revision it was read at
  /// ([baseRevision]), under [changeId] so a retry writes once. Throws
  /// the `ServerRefusal` `program_changed` when the coach changed it since.
  Future<Template> editSharedTemplate(Template template, {required int baseRevision, required String changeId});
}

/// What the account's templates owe the server (#448): a change made while
/// it could not be reached, and the server's copy that change started from.
///
/// Here for the reason [LocalTemplateFolderService] is: bookkeeping the
/// server has no notion of, which the app adapts `heart_db` onto.
abstract interface class UnsentTemplateService {
  /// Every template of [userId] with a change owed, and the copy the change
  /// started from; null where that copy cannot be read.
  Future<Map<String, Template?>> getUnsent(String userId);

  /// [templateId] was changed and the server has not had it. [base] is the
  /// copy it started from; a template already marked keeps the base it has.
  Future<void> markUnsent(String templateId, Template base);

  /// The change was sent, or let go.
  Future<void> clearUnsent(String templateId);
}

/// The sessions of copies two people edit (#558), which [Templates] sends from
/// the revision they were read at. The programs know which those are.
abstract interface class SharedSessions {
  /// The revision [session] was last read at, when it is a session of a
  /// coach's copy; null for any other template.
  int? baseRevisionOf(Template session);

  /// The coach changed [mine]'s session first: nothing was saved, and the
  /// user's version waits to be chosen or let go.
  Future<void> beaten(Template mine);
}

class Templates with ChangeNotifier, Iterable<Template>, TemplateDrafting implements SignOutStateSentry {
  final _templates = SplayTreeSet<Template>();
  final _samples = SplayTreeSet<Template>();
  final _folders = SplayTreeSet<TemplateFolder>();
  final TemplateService _service;
  final RemoteTemplateService _remoteService;
  final RemoteConfigService _configService;
  final LocalTemplateFolderService _folderService;
  final ApiTemplateFolderService _remoteFolderService;
  final RemoteTemplateFilingService _filingService;
  final UnsentTemplateService? _unsent;
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
    this._unsent,
    this.onError,
    this.maxTemplates,
    this.analytics,
    RemoteAccess? remote,
  }) : _remote = remote ?? RemoteAccess();

  /// Whether templates are a feature or a graveyard, and which of the two ways
  /// of making one people actually use. Absent in tests.
  final Analytics? analytics;

  String? userId;

  /// Set once the programs exist, which come after the templates.
  SharedSessions? shared;

  /// What to call the user's version of a template, by the template's name,
  /// when it is kept beside the one that replaced it on the server (#448).
  /// Copy, so the app's to say; until it has, such a template waits as it is.
  String Function(String? name)? keptName;

  /// The read of the server in flight and whose it is, the launch's or a
  /// later one: a second asker for the same account joins it.
  (String, Future<void>)? _reading;

  /// The templates saved, moved or deleted here since the read in flight
  /// began; null with none in flight. Its answer was made before those, so it
  /// says nothing about them.
  Set<String>? _changedMeanwhile;

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
    notifyListeners();
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
    // A session that ends mid-read (#671) has had its state cleared for the
    // next one: what lands after that is the last one's and stays out. Every
    // step checks the uid again once it has awaited.
    await _step(() async {
      final local = await _service.getTemplates(id);
      if (userId != id) return;
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
    if (userId != id) return;
    _ownLoaded = true;

    await _step(() async {
      final localFolders = await _folderService.getFolders(id);
      if (userId != id) return;
      if (localFolders.isNotEmpty) {
        _folders.addAll(localFolders);
        notifyListeners();
      }
    });

    // the mirror is the whole story until there is a server to reconcile with
    if (userId != id || !_remote.allowed) return;

    await _read(id, launch: true);
  }

  /// Reads the account's templates and folders from the server again, over
  /// the ones held: what was made or replaced elsewhere, by an assistant
  /// (#448) or another device, shows without a relaunch. For when the user
  /// comes back to the app, and for a pull on the templates' page.
  ///
  /// Nothing before the launch's own reads are in, and nothing without an
  /// account. A read already in flight is joined, not repeated.
  Future<void> refresh() async {
    final id = userId;
    if (id == null || !_ownLoaded || !_remote.allowed) return;
    await _read(id);
  }

  Future<void> _read(String id, {bool launch = false}) {
    if (_reading case (final String uid, final Future<void> read) when uid == id) return read;
    final changed = _changedMeanwhile = {};
    late final Future<void> read;
    read = _readServer(id, launch: launch).whenComplete(() {
      if (identical(_reading?.$2, read)) _reading = null;
      if (identical(_changedMeanwhile, changed)) _changedMeanwhile = null;
    });
    _reading = (id, read);
    return read;
  }

  /// The server's templates, then its folders, over what is held and into
  /// the mirror. Each step reports what it throws ([_step]) and the next
  /// still runs.
  Future<void> _readServer(String id, {required bool launch}) async {
    await _step(() async {
      final remote = (await _remoteService.getTemplates() ?? []).toList();
      if (userId != id || remote.isEmpty) return;
      await _take(remote, id, whole: launch);
    });
    if (userId != id) return;

    // After the templates above: this replace also unfiles whatever points at
    // a folder the server no longer has, so it must see the final template
    // rows, not race ahead of them. The server's list is read whole or not at
    // all, so a failure leaves the local folders as they are.
    await _step(() async {
      final remoteFolders = (await _remoteFolderService.getFolders(userId: id)).toList();
      if (userId != id) return;
      if (remoteFolders.isNotEmpty || _folders.isNotEmpty) {
        _folders
          ..clear()
          ..addAll(remoteFolders);
        notifyListeners();
      }
      await _folderService.storeFolders(remoteFolders, id);
    });
  }

  /// Takes the server's copies in [remote] over the ones held and into the
  /// mirror, once what the device owes the server is settled against them
  /// ([_settled]).
  ///
  /// A read made while the app runs leaves three kinds alone, which the next
  /// one takes: a template changed here since the read began, the one open in
  /// the editor, whose held copy the editor is changing in place, and one
  /// whose program differs from the held copy's, because filing a session
  /// while the server is out of reach is the programs' to send, at launch.
  /// [whole], the launch's read or one that names its templates, takes all.
  Future<void> _take(List<Template> remote, String id, {required bool whole}) async {
    final owed = await _unsent?.getUnsent(id) ?? const <String, Template?>{};
    final taken = <Template>[];
    for (final theirs in remote) {
      if (userId != id) return;
      final held = _own(theirs.id);
      final apart =
          !whole &&
          held != null &&
          (theirs.id == editable?.id ||
              held.programId != theirs.programId ||
              (_changedMeanwhile?.contains(theirs.id) ?? false));
      if (apart) continue;
      if (held == null || !owed.containsKey(theirs.id)) {
        taken.add(theirs);
        continue;
      }
      try {
        if (await _settled(held, theirs, base: owed[theirs.id])) taken.add(theirs);
      } catch (e, s) {
        onError?.call(e, stacktrace: s);
      }
    }
    // settling awaits: what changed here during it stands
    final fresh = [
      for (final theirs in taken)
        if (whole || !(_changedMeanwhile?.contains(theirs.id) ?? false)) theirs,
    ];
    if (userId != id || fresh.isEmpty) return;
    _templates
      ..removeWhere(fresh.contains)
      ..addAll(fresh);
    notifyListeners();
    await _service.storeTemplates(fresh, userId: id);
    // the server's copy is in: whatever these owed is settled
    for (final theirs in fresh) {
      if (owed.containsKey(theirs.id)) await _unsent?.clearUnsent(theirs.id);
    }
  }

  /// Settles what [mine] owes against [theirs], the server's copy of it now,
  /// and says whether [theirs] takes its place (#448):
  ///
  /// - the server already has the change (the answer was lost, not the
  ///   request): its copy is taken;
  /// - the server's copy is still the one the change started from ([base]):
  ///   the change is sent now, and the held one stays until the server
  ///   answers. A change the server refuses is kept as below, since sending
  ///   it again would only be refused again;
  /// - the server's copy was replaced meanwhile, by an assistant or another
  ///   device: both are kept. The server's takes the template's place. The
  ///   user's becomes a template of their own beside it, under [keptName].
  ///   A session of a coach's copy waits to be chosen instead, by that rule
  ///   ([SharedSessions.beaten]), which holds it for as long as the app runs.
  ///
  /// Throwing leaves the template as it is, still owing.
  Future<bool> _settled(Template mine, Template theirs, {required Template? base}) async {
    final theirsNow = _contentOf(theirs);
    if (_contentOf(mine) == theirsNow) return true;

    if (base != null && _contentOf(base) == theirsNow) {
      // nobody else touched it: the change goes up as it would have
      RemoteFailure? failure;
      final changedBefore = _changedMeanwhile?.contains(mine.id) ?? false;
      await _save(mine, onFailure: (error) => failure = _remote.failureOf(error));
      notifyListeners();
      switch (failure) {
        case .answered || .gone:
          // that save was this read's own, not a change made during it
          if (!changedBefore) _changedMeanwhile?.remove(mine.id);
        case .unanswered || .transient || null:
          return false;
      }
    }

    if (shared?.baseRevisionOf(mine) != null) {
      await shared?.beaten(mine);
      return true;
    }

    final name = keptName;
    final id = userId;
    if (name == null || id == null) return false;
    await _keepBeside(mine, theirs, name: name(mine.name), userId: id);
    return true;
  }

  /// Keeps [mine] as a template of the user's own, named [name], beside
  /// [theirs], which takes its place in the mirror here. All of it: the
  /// exercises with their plans and notes, the template's note, and what this
  /// build could not read. Nothing of where it came from: not who assigned
  /// the original, nor its place in a program.
  ///
  /// The original is settled as soon as the copy is on the device, before the
  /// copy goes to the server: a read cut short after that makes no second
  /// copy. One the server will not take stays on the device.
  Future<void> _keepBeside(Template mine, Template theirs, {required String name, required String userId}) async {
    Object? renewed(Object? each) {
      return switch (each) {
        final Map map => {
          ...map,
          'id': uuidV7(),
          if (map['sets'] case final List sets) 'sets': sets.map(renewed).toList(),
        },
        _ => each,
      };
    }

    final map = mine.toMap();
    for (final key in const ['sourceTemplateId', 'assignedBy', 'syncEnabled', 'programId', 'joined']) {
      map.remove(key);
    }
    final kept = Template.fromJson({
      ...map,
      'id': uuidV7(),
      'order': (_templates.lastOrNull?.order ?? 0) + 1,
      'name': name,
      'exercises': (map['exercises'] as List).map(renewed).toList(),
    });
    _templates.add(kept);
    _changedMeanwhile?.add(kept.id);
    await _service.storeTemplates([kept], userId: userId);
    await _service.storeTemplates([theirs], userId: userId);
    await _unsent?.clearUnsent(theirs.id);

    try {
      final saved = await _remoteService.saveTemplate(kept);
      _swap(kept, saved);
      _changedMeanwhile?.add(saved.id);
      if (saved.id != kept.id) await _service.deleteTemplate(kept.id);
      await _service.storeTemplates([saved], userId: userId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// The user's own template by [id], never a sample.
  Template? _own(String id) => _templates.where((template) => template.id == id).firstOrNull;

  /// What [template] says, for telling two copies of one apart: its name, its
  /// note and each exercise's plan and sets. Not the ids and stamps, which
  /// the mirror mints anew on every store, nor an exercise's own note, which
  /// the mirror does not keep.
  static String _contentOf(Template template) {
    Map<String, dynamic> said(Map<String, dynamic> map, Set<String> keys) {
      return {
        for (final key in keys)
          if (map[key] != null) key: map[key],
      };
    }

    return jsonEncode({
      'name': template.name,
      'note': template.note,
      'exercises': [
        for (final exercise in template)
          {
            'exercise': exercise.exercise.id,
            ...said(exercise.toMap(), const {'rest', 'superset', 'pattern', 'totalReps'}),
            'sets': [
              for (final set in exercise)
                said(set.toMap(), const {'reps', 'duration', 'distance', 'weight', 'set_type', 'rpe', 'target'}),
            ],
            'unread': exercise.unread,
          },
      ],
      'unread': template.unread,
    });
  }

  /// Reads the templates [ids] from the server over the ones held, and no
  /// others: a program's sessions, when a push named the program (#567). One
  /// that fails to read keeps what was held, and the rest still land.
  Future<void> pull(Iterable<String> ids) async {
    final id = userId;
    if (id == null || !_remote.allowed) return;
    final answers = await Future.wait(
      ids.map((each) async {
        try {
          return await _filingService.getTemplate(each);
        } catch (e, s) {
          onError?.call(e, stacktrace: s);
          return null;
        }
      }),
    );
    final read = answers.nonNulls.toList();
    if (read.isEmpty || userId != id) return;
    // through the same settling as any read: a session changed here while the
    // server was out of reach is not written over unseen (#448)
    await _step(() => _take(read, id, whole: true));
  }

  /// Reads the user's own templates from the mirror again, replacing what is
  /// held: the rows changed under them (an exercise's history moved, #338),
  /// and the held copies still name the old exercise.
  Future<void> reread() async {
    if (userId case String id) {
      await _step(() async {
        final local = await _service.getTemplates(id);
        if (userId != id) return;
        _templates
          ..clear()
          ..addAll(local);
        notifyListeners();
      });
    }
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

  @override
  Future<Template> startDraft() {
    return _service.startTemplate(userId: userId, order: (_templates.lastOrNull?.order ?? 0) + 1);
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
  @override
  Future<void> discardEditable() async {
    final draft = editable;
    editable = null;
    notifyListeners();

    if (draft == null || _templates.any((each) => each.id == draft.id)) return;

    await _service.deleteTemplate(draft.id);
  }

  @override
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
      final copy = WorkoutExercise(starter: exercise.first.copy())
        ..note = exercise.note
        // what the exercise plans beyond its sets goes with it
        ..rest = exercise.rest
        ..superset = exercise.superset
        ..pattern = exercise.pattern
        ..totalReps = exercise.totalReps;
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
  Future<Template> _save(Template template, {void Function(Object error)? onFailure}) async {
    // over the copy held, whichever object that is: a read of the server may
    // have swapped it since the editor opened this one
    _templates
      ..removeWhere((each) => each.id == template.id)
      ..add(template);
    _changedMeanwhile?.add(template.id);
    // read before the mirror takes the change: afterwards it is gone
    final base = await _baseOf(template);
    await _service.updateTemplate(template);

    if (!_remote.allowed) {
      // an account whose server is closed to it for now (a replay running, a
      // token on its way): the change is owed. An anonymous session owes
      // nothing: its whole store goes up when an account arrives.
      if (_remote.account) await _owe(template, base);
      return template;
    }

    try {
      final saved = await switch ((template.local, shared?.baseRevisionOf(template))) {
        (true, _) => _remoteService.saveTemplate(template),
        (false, final int base) => _filingService.editSharedTemplate(template, baseRevision: base, changeId: uuidV7()),
        (false, null) => _remoteService.editTemplate(template),
      };
      _swap(template, saved);
      _changedMeanwhile?.add(saved.id);
      if (userId case String id) {
        // A locally-created template is persisted under a client-generated
        // id, but the server assigns its own id on save. Drop the stale local
        // row first, otherwise storing the server copy leaves a duplicate.
        if (saved.id != template.id) {
          await _service.deleteTemplate(template.id);
        }
        await _service.storeTemplates([saved], userId: id);
        // the server has it: nothing is owed any more
        await _unsent?.clearUnsent(saved.id);
      }
      return saved;
    } catch (error, stacktrace) {
      if (isProgramChanged(error)) {
        // the coach's version comes back here, and the user's waits to be chosen
        await shared?.beaten(template);
        await pull([template.id]);
        return lookup(template.id) ?? template;
      }
      // no answer, or one that may differ next time: the change waits on the
      // device, and the next read of the server settles it (#448). A refusal
      // would only be repeated.
      if (_remote.failureOf(error) case .unanswered || .transient) await _owe(template, base);
      onFailure?.call(error);
      onError?.call(error, stacktrace: stacktrace);
      return template;
    }
  }

  /// The server's copy of [template] as the mirror holds it, before a change
  /// to it lands there; null for one the server has never had, and where
  /// nothing keeps what is owed.
  Future<Template?> _baseOf(Template template) async {
    final id = userId;
    if (_unsent == null || id == null || template.local) return null;
    try {
      return (await _service.getTemplates(id)).where((each) => each.id == template.id).firstOrNull;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return null;
    }
  }

  /// Marks [template]'s change as owed to the server, from [base].
  Future<void> _owe(Template template, Template? base) async {
    if (base == null) return;
    try {
      await _unsent?.markUnsent(template.id, base);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Sends [template] as it is, over the one held: the user's version of a
  /// shared session, chosen over the coach's (#558).
  Future<Template> keep(Template template) async {
    _templates.removeWhere((each) => each.id == template.id);
    final saved = await _save(template);
    notifyListeners();
    return saved;
  }

  Future<void> delete(Template template) {
    _templates.remove(template);
    _changedMeanwhile?.add(template.id);
    notifyListeners();
    return Future.wait(
      [
        _service.deleteTemplate(template.id),
        if (_remote.allowed) _deleteRemote(template.id),
      ],
    );
  }

  /// One the server no longer has is gone either way; any other failure is
  /// reported rather than thrown at the screen that deleted it.
  Future<void> _deleteRemote(String templateId) async {
    try {
      await _remoteService.deleteTemplate(templateId);
    } catch (error, stacktrace) {
      if (!_remote.isGone(error)) onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Folders are remote-first — the server mints their ids — so there are none
  /// to be had while the remote leg is closed. The pages hide the affordances;
  /// this is the tripwire behind them.
  void _requireRemote() {
    if (!_remote.allowed) throw StateError('template folders need the remote leg');
  }

  bool get allowsNewTemplate => length < (maxTemplates ?? _maxTemplates);

  /// Whether [count] more templates fit under the allowance: a ready-made
  /// program's sessions all arrive at once (#352).
  bool allowsNewTemplates(int count) => count <= templateRoom;

  /// How many more templates fit under the allowance.
  int get templateRoom => max(0, (maxTemplates ?? _maxTemplates) - length);

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
    _changedMeanwhile?.add(template.id);
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

  /// Swaps [from] for [to] in each of the user's templates among [ids] that
  /// holds it: a ladder's step up, or back down (#350). Each set keeps its
  /// type, target and values, and the exercise its rest, group and totals,
  /// as an open slot's swap on the sheet keeps them.
  Future<void> replaceExercise(Iterable<String> ids, {required String from, required Exercise to}) async {
    final wanted = ids.toSet();
    final changed = <Template>[];
    for (final template in _templates.where((template) => wanted.contains(template.id)).toList()) {
      final held = template.where((exercise) => exercise.exercise.id == from && exercise.isNotEmpty).toList();
      for (final exercise in held) {
        final sets = [
          for (final set in exercise)
            ExerciseSet(to, setType: set.setType, target: set.target)..setMeasurements(
              weight: set.weight,
              reps: set.reps,
              duration: set.duration,
              distance: set.distance,
            ),
        ];
        final replacement = WorkoutExercise(starter: sets.first)
          ..rest = exercise.rest
          ..superset = exercise.superset
          ..pattern = exercise.pattern
          ..totalReps = exercise.totalReps;
        for (final set in sets.skip(1)) {
          replacement.add(set);
        }
        template
          ..append(replacement)
          ..swap(replacement, exercise)
          ..remove(exercise);
      }
      if (held.isNotEmpty) changed.add(template);
    }
    if (changed.isEmpty) return;
    notifyListeners();
    await Future.wait(changed.map(_save));
    notifyListeners();
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
