import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'remote.dart';
import 'upsync.dart' show Replayed;
import 'workouts.dart';

/// The mirror's half of programs (#346): `LocalDatabase` behind an adapter in
/// the app, as [LocalTemplateFolderService] is. Defined here rather than in
/// heart_models because it is local bookkeeping the server has no notion of.
abstract interface class LocalProgramService {
  Future<List<Program>> getPrograms(String userId);

  /// Replaces the stored programs wholesale: the write of a full read.
  Future<void> storePrograms(Iterable<Program> programs, String userId);

  Future<void> storeProgram(Program program, String userId);

  Future<void> deleteProgram(String programId, {required bool keepTemplates});

  /// The program's finished workouts, as what its position is folded from.
  Future<List<ProgramMark>> getProgramMarks(String userId, String programId);

  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId});

  Future<void> storeProgramActions(String programId, Iterable<ProgramAction> actions);

  Future<void> storeProgramAction(ProgramAction action);

  Future<void> deleteProgramAction(String actionId);

  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId});

  Future<void> storeProgramBases(String programId, Iterable<ProgramBase> bases);

  Future<void> storeProgramBase(ProgramBase base);

  Future<void> deleteProgramBase(String baseId);
}

/// The server's half: `Api` behind an adapter in the app. Each create is safe
/// to repeat on its id (heart-api#66), which is what lets the upsync replay
/// use the same calls.
abstract interface class RemoteProgramService {
  /// Whole or not at all: the caller replaces its programs with these.
  Future<List<Program>> getPrograms();

  Future<Replayed<Program>> replayProgram(Program program, {required Iterable<Template> sessions});

  Future<Program> editProgram(Program program);

  Future<void> deleteProgram(String programId, {required bool keepTemplates});

  Future<List<ProgramAction>> getProgramActions(String programId);

  Future<Replayed<ProgramAction>> replayProgramAction(ProgramAction action);

  Future<void> deleteProgramAction(String programId, String actionId);

  Future<List<ProgramBase>> getProgramBases(String programId);

  Future<Replayed<ProgramBase>> replayProgramBase(ProgramBase base);

  Future<void> deleteProgramBase(String programId, String baseId);
}

/// The user's programs (#346, `docs/2026-10-11.programs.md`): templates on a
/// schedule, the steps the user took in them, and the bases their rules grow.
///
/// Local-first, like [Templates]: every write lands in the mirror, then goes to
/// the server while the remote leg is open, whose copy then replaces it.
///
/// Position is never held. [position] folds it on request from the program's
/// finished workouts and its actions, with heart_models' `ProgramPosition.of`,
/// the function `/me` and MCP run too.
///
/// Data, whatever the feature switch says (`docs/opt-in.md`): this reads,
/// stores and syncs programs for an account that has turned Programs off, so
/// another device that has it on finds them whole. Only presentation asks the
/// switch.
class Programs with ChangeNotifier implements SignOutStateSentry {
  final LocalProgramService _service;
  final RemoteProgramService _remoteService;

  /// Where a program's session templates are written: the same mirror the
  /// template list reads.
  final TemplateService _templates;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// The session templates changed under the template list: a program made
  /// with new sessions, or deleted with its own. The app re-reads the list.
  final Future<void> Function()? onSessionsChanged;

  /// Listened to for finished and deleted workouts, which move a position.
  final Workouts? _workouts;

  new({
    required this._service,
    required this._remoteService,
    required this._templates,
    this.onError,
    this.onSessionsChanged,
    this._workouts,
    RemoteAccess? remote,
  }) : _remote = remote ?? RemoteAccess() {
    _workouts?.addListener(_onWorkouts);
  }

  static Programs of(BuildContext context) => Provider.of<Programs>(context, listen: false);

  static Programs watch(BuildContext context) => Provider.of<Programs>(context, listen: true);

  String? userId;

  final _programs = <String, Program>{};
  final _actions = <String, List<ProgramAction>>{};
  final _bases = <String, List<ProgramBase>>{};
  final _marks = <String, List<ProgramMark>>{};

  bool _loaded = false;

  /// Whether the mirror's programs have been read.
  bool get hasLoaded => _loaded;

  /// Every program, archived ones included, oldest first.
  List<Program> get all => UnmodifiableListView(_programs.values);

  /// The programs the user is following: not archived. A finished one is
  /// still among them until it is archived; whether it is finished is its
  /// [position]'s to say.
  Iterable<Program> get following => _programs.values.where((program) => !program.archived);

  Program? lookup(String programId) => _programs[programId];

  List<ProgramAction> actionsOf(String programId) => UnmodifiableListView(_actions[programId] ?? const []);

  /// Every value [programId]'s rules have given its exercises, oldest first:
  /// the "100 → 102.5 → 105" view.
  List<ProgramBase> basesOf(String programId) => UnmodifiableListView(_bases[programId] ?? const []);

  /// Each exercise's base in [programId] as it stands: the latest value.
  Map<String, ProgramBase> currentBasesOf(String programId) => currentBases(basesOf(programId));

  /// Where the user stands in [program]: computed, never stored. [now] sets the
  /// calendar week the weekly count reads, in its zone; [firstWeekday] is ISO,
  /// the user's own first day of the week.
  ProgramPosition position(Program program, {required DateTime now, int firstWeekday = DateTime.monday}) {
    final id = program.id;
    return ProgramPosition.of(
      program,
      marks: _marks[id] ?? const [],
      actions: _actions[id] ?? const [],
      now: now,
      firstWeekday: firstWeekday,
    );
  }

  @override
  void onSignOut() {
    userId = null;
    _loaded = false;
    _programs.clear();
    _actions.clear();
    _bases.clear();
    _marks.clear();
    _heldHistory = null;
  }

  @override
  void dispose() {
    _workouts?.removeListener(_onWorkouts);
    super.dispose();
  }

  /// Reads the mirror, then, with the remote leg open, the server's programs
  /// and each one's history, which replace the mirror's. Nobody awaits this,
  /// so each step reports what it throws and the next still runs.
  Future<void> init() async {
    final id = userId;
    if (id == null) {
      _loaded = true;
      return;
    }

    await _step(() async {
      final programs = await _service.getPrograms(id);
      final actions = await _service.getProgramActions(id);
      final bases = await _service.getProgramBases(id);
      if (userId != id) return;
      _replace(programs);
      _group(_actions, actions, (action) => action.programId);
      _group(_bases, bases, (base) => base.programId);
      await _readMarks(id);
      notifyListeners();
    });
    _loaded = true;

    if (!_remote.allowed) return;

    await _step(() async {
      final programs = await _remoteService.getPrograms();
      if (userId != id) return;
      await _service.storePrograms(programs, id);
      _replace(programs);
      notifyListeners();
    });

    for (final program in [..._programs.values]) {
      final programId = program.id!;
      await _step(() async {
        final (actions, bases) = await (
          _remoteService.getProgramActions(programId),
          _remoteService.getProgramBases(programId),
        ).wait;
        if (userId != id) return;
        await _service.storeProgramActions(programId, actions);
        await _service.storeProgramBases(programId, bases);
        _actions[programId] = [...actions]..sort((a, b) => a.at.compareTo(b.at));
        _bases[programId] = [...bases]..sort((a, b) => a.at.compareTo(b.at));
        notifyListeners();
      });
    }
  }

  /// Starts a program with [sessions] as its templates, in their order.
  ///
  /// The sessions are the user's own copies from here on: a library program's
  /// or a shared one's, made by the caller under fresh ids, and filed under the
  /// program here. [program] takes an id and its creation time when it has
  /// none.
  Future<Program> create(Program program, {required List<Template> sessions}) async {
    final uid = userId;
    if (uid == null) throw StateError('a program belongs to an account or a session');

    final id = program.id ?? uuidV7();
    final filed = [
      for (final session in sessions) Template.fromJson({...session.toMap(), 'programId': id}),
    ];
    final local = Program.fromJson({
      ...program.toMap(),
      'id': id,
      'sessions': [for (final session in filed) session.id],
      'createdAt': (program.createdAt ?? DateTime.timestamp()).toUtc().toIso8601String(),
    });

    await _templates.storeTemplates(filed, userId: uid);
    await _service.storeProgram(local, uid);
    _programs[id] = local;
    notifyListeners();
    await onSessionsChanged?.call();

    if (!_remote.allowed) return local;

    try {
      final (:row, created: _) = await _remoteService.replayProgram(local, sessions: filed);
      return await _keep(row, uid);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return local;
    }
  }

  /// Saves [program]'s own fields and rules. Sessions change through their
  /// templates.
  Future<Program> update(Program program) async {
    final uid = userId;
    final id = program.id;
    if (uid == null || id == null) return program;

    await _service.storeProgram(program, uid);
    _programs[id] = program;
    notifyListeners();

    if (!_remote.allowed) return program;

    try {
      return await _keep(await _remoteService.editProgram(program), uid);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return program;
    }
  }

  /// Stops following [program], or follows it again. Its history is kept.
  Future<Program> archive(Program program, {bool archived = true}) {
    return update(program.copyWith(archived: archived));
  }

  /// Deletes [program] and its history. Its sessions go with it, or with
  /// [keepTemplates] stay as plain templates; its workouts stay either way.
  Future<void> delete(Program program, {required bool keepTemplates}) async {
    final id = program.id;
    if (id == null) return;

    _programs.remove(id);
    _actions.remove(id);
    _bases.remove(id);
    _marks.remove(id);
    notifyListeners();

    await _service.deleteProgram(id, keepTemplates: keepTemplates);
    await onSessionsChanged?.call();

    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgram(id, keepTemplates: keepTemplates);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Takes a step in [program]: repeat, pause, resume, or replay from [week].
  /// History, not state: undoing it is [undo].
  Future<ProgramAction> act(Program program, ProgramActionKind kind, {int? week, DateTime? at}) {
    final action = ProgramAction(
      id: uuidV7(),
      programId: program.id,
      kind: kind,
      week: switch (kind) {
        .replay => week,
        _ => null,
      },
      at: at ?? DateTime.timestamp(),
    );
    return _record(
      action,
      into: _actions,
      idOf: (action) => action.id,
      store: _service.storeProgramAction,
      forget: _service.deleteProgramAction,
      replay: _remoteService.replayProgramAction,
      programId: action.programId,
    );
  }

  /// Undoes [action], and the bases it moved with it.
  Future<void> undo(ProgramAction action) async {
    final programId = action.programId;
    final actionId = action.id;
    if (programId == null || actionId == null) return;

    _actions[programId]?.removeWhere((each) => each.id == actionId);
    _bases[programId]?.removeWhere((each) => each.actionId == actionId);
    notifyListeners();

    await _service.deleteProgramAction(actionId);
    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgramAction(programId, actionId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Sets [exerciseId]'s base in [program] to [value], with its cause: the
  /// workout that moved it, the action that did, or neither when the user set
  /// it ("Keep 57.5 kg").
  Future<ProgramBase> setBase(
    Program program, {
    required String exerciseId,
    required num value,
    String? workoutId,
    String? actionId,
    DateTime? at,
  }) {
    assert(workoutId == null || actionId == null, 'a base has one cause');
    final base = ProgramBase(
      id: uuidV7(),
      programId: program.id,
      exerciseId: exerciseId,
      value: value,
      workoutId: workoutId,
      actionId: actionId,
      at: at ?? DateTime.timestamp(),
    );
    return _record(
      base,
      into: _bases,
      idOf: (base) => base.id,
      store: _service.storeProgramBase,
      forget: _service.deleteProgramBase,
      replay: _remoteService.replayProgramBase,
      programId: base.programId,
    );
  }

  /// Deletes one value of a base: an edit taken back.
  Future<void> deleteBase(ProgramBase base) async {
    final programId = base.programId;
    final baseId = base.id;
    if (programId == null || baseId == null) return;

    _bases[programId]?.removeWhere((each) => each.id == baseId);
    notifyListeners();

    await _service.deleteProgramBase(baseId);
    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgramBase(programId, baseId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Reads every program's marks from the mirror again: a workout of one was
  /// finished, deleted, or arrived from another device.
  Future<void> refreshMarks() async {
    final id = userId;
    if (id == null) return;
    await _step(() async {
      await _readMarks(id);
      if (userId == id) notifyListeners();
    });
  }

  /// How many finished workouts [_workouts] held when last looked at. A change
  /// is a workout finished, deleted, or paged down: each may move a position.
  int? _heldHistory;

  void _onWorkouts() {
    final held = _workouts?.history.length;
    if (held == _heldHistory) return;
    _heldHistory = held;
    if (_programs.isNotEmpty) refreshMarks();
  }

  Future<void> _readMarks(String uid) async {
    final marks = {
      for (final programId in [..._programs.keys]) programId: await _service.getProgramMarks(uid, programId),
    };
    _marks
      ..clear()
      ..addAll(marks);
  }

  /// Keeps the server's [row] in place of the local copy.
  Future<Program> _keep(Program row, String uid) async {
    await _service.storeProgram(row, uid);
    if (row.id case final String id) _programs[id] = row;
    notifyListeners();
    return row;
  }

  /// Writes [row] locally and, with the remote leg open, to the server, whose
  /// copy then replaces it. The server's can be another row: a bump a second
  /// device already wrote for the same workout comes back as the first one,
  /// and this device's copy goes ([forget]).
  Future<T> _record<T>(
    T row, {
    required Map<String, List<T>> into,
    required String? Function(T) idOf,
    required Future<void> Function(T) store,
    required Future<void> Function(String id) forget,
    required Future<Replayed<T>> Function(T) replay,
    required String? programId,
  }) async {
    if (programId == null) throw ArgumentError.notNull('programId');
    final rows = into.putIfAbsent(programId, () => [])..add(row);
    notifyListeners();
    await store(row);

    if (!_remote.allowed) return row;

    try {
      final (row: saved, created: _) = await replay(row);
      final (mine, theirs) = (idOf(row), idOf(saved));
      if (mine != null && mine != theirs) await forget(mine);
      await store(saved);
      rows
        ..removeWhere((each) => idOf(each) == mine || idOf(each) == theirs)
        ..add(saved);
      notifyListeners();
      return saved;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return row;
    }
  }

  void _replace(Iterable<Program> programs) {
    _programs
      ..clear()
      ..addEntries([
        for (final program in programs)
          if (program.id case final String id) MapEntry(id, program),
      ]);
  }

  static void _group<T>(Map<String, List<T>> into, Iterable<T> rows, String? Function(T) programOf) {
    into.clear();
    for (final row in rows) {
      if (programOf(row) case final String programId) into.putIfAbsent(programId, () => []).add(row);
    }
  }

  Future<void> _step(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }
}
