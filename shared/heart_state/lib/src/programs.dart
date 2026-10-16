import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'program_calendar.dart';
import 'program_growth.dart';
import 'program_plan.dart';
import 'remote.dart';
import 'upsync.dart' show Replayed;
import 'workouts.dart';

/// A program's rows, as what [Programs] owes the server names them. A
/// session is a template the account already held, filed under a program by
/// its own edit (#348). A skip is "Not today" (#312): it names its program,
/// and outlives it.
enum ProgramRow { program, action, base, session, skip }

/// What was done to a row on this device.
enum ProgramChange { created, edited, deleted, deletedKeepingTemplates }

/// A write the server has not confirmed: its remote leg failed, or was never
/// reached (a dead network, a killed app, a token still on its way). Kept in
/// the mirror until [Programs.init] sends it again, as `synced` keeps a
/// finished workout owed.
typedef ProgramOwed = ({ProgramRow row, String id, String programId, ProgramChange change});

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

  /// The program's finished workouts, whole and oldest first: what a growth
  /// rule's miss streak is read from (#350).
  Future<List<Workout>> getProgramWorkouts(String userId, String programId);

  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId});

  Future<void> storeProgramActions(String programId, Iterable<ProgramAction> actions);

  Future<void> storeProgramAction(ProgramAction action);

  Future<void> deleteProgramAction(String actionId);

  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId});

  Future<void> storeProgramBases(String programId, Iterable<ProgramBase> bases);

  Future<void> storeProgramBase(ProgramBase base);

  Future<void> deleteProgramBase(String baseId);

  /// What [userId]'s server has not confirmed, in the order it was written.
  Future<List<ProgramOwed>> getProgramsOwed(String userId);

  /// Records [owed], in place of whatever was owed for the same row.
  Future<void> owePrograms(String userId, ProgramOwed owed);

  /// The server confirmed [row] [id], or will never take it.
  Future<void> settleProgram(ProgramRow row, String id);

  /// [userId]'s skips ("Not today", #312), of every program and of none,
  /// oldest first.
  Future<List<TrainingSkip>> getSkips(String userId);

  /// Replaces [userId]'s skips wholesale: the write of a full read.
  Future<void> storeSkips(Iterable<TrainingSkip> skips, String userId);

  Future<void> storeSkip(TrainingSkip skip, String userId);

  Future<void> deleteSkip(String skipId);
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

  /// Files [template] under [programId] as a session, or takes it out of its
  /// program when null.
  Future<Template> setTemplateProgram(Template template, {required String? programId});

  /// Every skip the account holds, whole or not at all.
  Future<List<TrainingSkip>> getSkips();

  Future<Replayed<TrainingSkip>> replaySkip(TrainingSkip skip);

  Future<void> deleteSkip(String skipId);
}

/// The user's programs (#346, `docs/2026-10-11.programs.md`): templates on a
/// schedule, the steps the user took in them, and the bases their rules grow.
///
/// Local-first, like [Templates]: every write lands in the mirror, then goes to
/// the server while the remote leg is open, whose copy then replaces it. A
/// write the server did not confirm stays owed ([ProgramOwed]) and is sent
/// again by the next [init], before the server's copy is read over it.
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

  /// Swaps [from] for [to] in the [sessions] that hold it: a ladder's advance
  /// (#350), or its "Keep". Templates are the template list's to edit.
  final Future<void> Function(Iterable<String> sessions, {required String from, required String to})? onAdvance;

  new({
    required this._service,
    required this._remoteService,
    required this._templates,
    this.onError,
    this.onSessionsChanged,
    this.onAdvance,
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
  final _skips = <String, List<TrainingSkip>>{};
  // the skips whose program was deleted: they outlive it, as on the server
  final _orphanSkips = <TrainingSkip>[];
  final _owed = <(ProgramRow, String), ProgramOwed>{};

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

  /// The sessions of [programId] the user set aside ("Not today", #312),
  /// oldest first.
  List<TrainingSkip> skipsOf(String programId) => UnmodifiableListView(_skips[programId] ?? const []);

  /// Every program's skips, oldest first: what History lists beside the
  /// workouts.
  List<TrainingSkip> get skips {
    return [
      for (final skips in _skips.values) ...skips,
      ..._orphanSkips,
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  /// The sessions [position]'s open cycle counts done by a skip rather than
  /// a workout: the last thing each one had was "Not today".
  Set<String> skippedIn(Program program, ProgramPosition position) {
    final last = <String, ProgramMark>{};
    for (final mark in [...?_marks[program.id]]..sort((a, b) => a.at.compareTo(b.at))) {
      if (mark.templateId case final String id) last[id] = mark;
    }
    return {
      for (final id in position.done)
        if (last[id] case ProgramMark(isWorkout: false)) id,
    };
  }

  /// Whether [programId] had a workout or a skip on [day]'s calendar day, in
  /// [day]'s zone: a day whose session is behind it (#391).
  bool markedOn(String programId, DateTime day) {
    return (_marks[programId] ?? const <ProgramMark>[]).any((mark) {
      final at = day.isUtc ? mark.at.toUtc() : mark.at.toLocal();
      return at.year == day.year && at.month == day.month && at.day == day.day;
    });
  }

  /// What became of [session] in [program]'s week [week] (#391): the workout or
  /// the skip that did it, still ahead, or passed with nothing to show for it.
  /// Read from the mirror, whose workouts carry their ids where marks do not.
  Future<OccurrenceState> occurrence(
    Program program, {
    required String session,
    required int week,
    required DateTime now,
    int firstWeekday = DateTime.monday,
  }) async {
    final (uid, id) = (userId, program.id);
    if (uid == null || id == null) return const OccurrencePassed();
    return occurrenceOf(
      program,
      session: session,
      week: week,
      workouts: await _service.getProgramWorkouts(uid, id),
      skips: skipsOf(id),
      actions: actionsOf(id),
      now: now,
      firstWeekday: firstWeekday,
    );
  }

  /// Every value [programId]'s rules have given its exercises, oldest first:
  /// the "100 → 102.5 → 105" view.
  List<ProgramBase> basesOf(String programId) => UnmodifiableListView(_bases[programId] ?? const []);

  /// How many of [programId]'s sessions were trained, skips not counted: how
  /// far a goal's forecast trusts the program's pace (#353).
  int sessionsDone(String programId) => (_marks[programId] ?? const []).where((mark) => mark.isWorkout).length;

  /// Each exercise's base in [programId] as it stands: the latest value.
  Map<String, ProgramBase> currentBasesOf(String programId) => currentBases(basesOf(programId));

  /// The stage each stages rule of [programId] is on, keyed like
  /// [currentBasesOf] (#350): the latest stage step for it.
  Map<String, int> currentStagesOf(String programId) => currentStages(_actions[programId] ?? const []);

  /// Where the user stands in [program]: computed, never stored. [now] sets the
  /// calendar week the weekly count reads, in its zone; [firstWeekday] is ISO,
  /// the user's own first day of the week.
  ProgramPosition position(Program program, {required DateTime now, required int firstWeekday}) {
    final id = program.id;
    return ProgramPosition.of(
      program,
      marks: _marks[id] ?? const [],
      actions: _actions[id] ?? const [],
      now: now,
      firstWeekday: firstWeekday,
    );
  }

  /// [session] as the workout to start (#349): [planSession] with its
  /// program's position, bases and stages. A template no
  /// followed program holds starts as [Template.toWorkout] does.
  Workout plan(
    Template session, {
    required DateTime now,
    required int firstWeekday,
    required RoundWeight round,
  }) {
    final id = session.programId;
    final program = switch (id) {
      final String id => _programs[id],
      null => null,
    };
    if (id == null || program == null || program.archived) return session.toWorkout();
    return planSession(
      session,
      program: program,
      position: position(program, now: now, firstWeekday: firstWeekday),
      bases: currentBasesOf(id),
      stages: currentStagesOf(id),
      round: round,
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
    _skips.clear();
    _orphanSkips.clear();
    _owed.clear();
    _grown.clear();
    _heldRevision = null;
  }

  @override
  void dispose() {
    _workouts?.removeListener(_onWorkouts);
    super.dispose();
  }

  /// Reads the mirror, then, with the remote leg open, sends what the server
  /// is still owed, and reads the server's programs and each followed one's
  /// history over the mirror's: whole, but for what is still owed. Nobody
  /// awaits this, so each step reports what it throws and the next still runs.
  Future<void> init() async {
    final id = userId;
    if (id == null) {
      _loaded = true;
      return;
    }

    await _step(() => _readMirror(id));
    _loaded = true;
    // for whoever waits on it: a link from a calendar (#391)
    notifyListeners();

    if (!_remote.allowed) return;

    await _step(() => _flush(id));

    await _step(() async {
      final programs = _merged(await _remoteService.getPrograms());
      if (userId != id) return;
      await _service.storePrograms(programs, id);
      _replace(programs);
      // one only the server had has marks in the mirror all the same: its
      // workouts arrive with the history, not with it
      await _readMarks(id);
      notifyListeners();
    });

    await _step(() => _pullSkips(id));

    // an archived program's history is read once; nothing moves it after
    await Future.wait([
      for (final MapEntry<String, Program>(key: programId, value: program) in [..._programs.entries])
        if (!program.archived || !_actions.containsKey(programId)) _step(() => _pull(id, programId)),
    ]);
  }

  /// Reads the mirror again, and nothing else: it was re-keyed under the
  /// programs, by a history move (#338) that re-keyed the server's the same.
  Future<void> reread() async {
    if (userId case final String id) await _step(() => _readMirror(id));
  }

  Future<void> _readMirror(String id) async {
    final programs = await _service.getPrograms(id);
    final actions = await _service.getProgramActions(id);
    final bases = await _service.getProgramBases(id);
    final owed = await _service.getProgramsOwed(id);
    final skips = await _service.getSkips(id);
    if (userId != id) return;
    _replace(programs);
    _group(_actions, actions, (action) => action.programId);
    _group(_bases, bases, (base) => base.programId);
    _groupSkips(skips);
    _owed
      ..clear()
      ..addEntries([for (final each in owed) MapEntry((each.row, each.id), each)]);
    await _readMarks(id);
    notifyListeners();
  }

  /// Reads [programId]'s actions and bases from the server over the mirror's.
  Future<void> _pull(String uid, String programId) async {
    final (actions, bases) = await (
      _remoteService.getProgramActions(programId),
      _remoteService.getProgramBases(programId),
    ).wait;
    if (userId != uid) return;
    final ownActions = _rowsOwed<ProgramAction>(
      actions,
      .action,
      _actions[programId] ?? const [],
      (action) => action.id,
    );
    final ownBases = _rowsOwed<ProgramBase>(bases, .base, _bases[programId] ?? const [], (base) => base.id);
    await _service.storeProgramActions(programId, ownActions);
    await _service.storeProgramBases(programId, ownBases);
    _actions[programId] = ownActions..sort((a, b) => a.at.compareTo(b.at));
    _bases[programId] = ownBases..sort((a, b) => a.at.compareTo(b.at));
    notifyListeners();
  }

  /// Reads the account's skips from the server over the mirror's, but for
  /// what this device still owes it. They are read whole: a program's
  /// position folds every one of them.
  Future<void> _pullSkips(String uid) async {
    final theirs = await _remoteService.getSkips();
    if (userId != uid) return;
    final skips = _rowsOwed<TrainingSkip>(theirs, .skip, await _service.getSkips(uid), (skip) => skip.id)
      ..sort((a, b) => a.at.compareTo(b.at));
    await _service.storeSkips(skips, uid);
    _groupSkips(skips);
    await _readMarks(uid);
    notifyListeners();
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
    // when each joined, as this device saw it: one filed offline joins the
    // program then, not when it syncs (heart-api#227)
    final joined = DateTime.timestamp().toIso8601String();
    final filed = [
      for (final session in sessions) Template.fromJson({...session.toMap(), 'programId': id, 'joined': joined}),
    ];
    final local = Program.fromJson({
      ...program.toMap(),
      'id': id,
      'sessions': [for (final session in filed) session.id],
      'createdAt': (program.createdAt ?? DateTime.timestamp()).toUtc().toIso8601String(),
    });

    await _templates.storeTemplates(filed, userId: uid);
    await _service.storeProgram(local, uid);
    await _owe(.program, id, .created, programId: id);
    // each session owed its filing until the server has it under the program:
    // the server's copy of a template read over the mirror's would otherwise
    // take it back out
    for (final Template(id: sessionId) in filed) {
      await _owe(.session, sessionId, .edited, programId: id);
    }
    _programs[id] = local;
    notifyListeners();
    await onSessionsChanged?.call();

    if (!_remote.allowed) return local;

    try {
      final row = await _push(local, uid, sessions: filed);
      await _settle(.program, id);
      return row;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return local;
    }
  }

  /// Creates [program] on the server with [sessions], and keeps its copy.
  ///
  /// The server's create files only the templates it makes. One the account
  /// already holds, a folder made into a program (#348), comes back left out
  /// and joins through its own filing, all of them at once. One that fails
  /// stays owed, and the next [init] files it.
  Future<Program> _push(Program program, String uid, {required List<Template> sessions}) async {
    final (:row, created: _) = await _remoteService.replayProgram(program, sessions: sessions);
    for (final Template(:id) in sessions.where((session) => row.sessions.contains(session.id))) {
      await _settle(.session, id);
    }
    final left = [
      for (final session in sessions)
        if (!row.sessions.contains(session.id)) session,
    ];
    if (left.isEmpty) return _keep(row, uid);

    final programId = row.id ?? program.id;
    if (programId == null) return _keep(row, uid);
    await Future.wait(left.map((session) => _step(() => _file(session, programId, uid))));
    return _keep(Program.fromJson({...row.toMap(), 'sessions': program.sessions}), uid);
  }

  /// Files [session] under [programId] on the server, and keeps its copy.
  Future<void> _file(Template session, String programId, String uid) async {
    final filed = await _remoteService.setTemplateProgram(session, programId: programId);
    await _templates.storeTemplates([filed], userId: uid);
    await _settle(.session, session.id);
  }

  /// Saves [program]'s own fields and rules. Sessions change through their
  /// templates.
  Future<Program> update(Program program) async {
    final uid = userId;
    final id = program.id;
    if (uid == null || id == null) return program;

    await _service.storeProgram(program, uid);
    await _owe(.program, id, .edited, programId: id);
    _programs[id] = program;
    notifyListeners();

    if (!_remote.allowed) return program;

    try {
      final row = await _keep(await _remoteService.editProgram(program), uid);
      await _settle(.program, id);
      return row;
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
    // its skips stay in History, as the mirror keeps their rows
    _orphanSkips.addAll([
      for (final skip in _skips.remove(id) ?? const <TrainingSkip>[])
        TrainingSkip(id: skip.id, at: skip.at, reason: skip.reason, weather: skip.weather, templateId: skip.templateId),
    ]);
    notifyListeners();

    await _service.deleteProgram(id, keepTemplates: keepTemplates);
    // its history goes with it on the server too; and one the server never
    // had is owed nothing at all
    final reached = _owed[(ProgramRow.program, id)]?.change != .created;
    // a skip outlives its program, as on the server: it still goes up
    for (final owed in [..._owed.values.where((each) => each.programId == id && each.row != .skip)]) {
      await _settle(owed.row, owed.id);
    }
    if (reached) {
      final change = switch (keepTemplates) {
        true => ProgramChange.deletedKeepingTemplates,
        false => ProgramChange.deleted,
      };
      await _owe(.program, id, change, programId: id);
    }
    await onSessionsChanged?.call();

    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgram(id, keepTemplates: keepTemplates);
      await _settle(.program, id);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Takes a step in [program]: repeat, pause, resume, replay from [week], or
  /// a lighter cycle now. History, not state: undoing it is [undo]. A ladder's
  /// advance is [advance].
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
      .action,
      into: _actions,
      idOf: (action) => action.id,
      store: _service.storeProgramAction,
      confirm: _confirmAction,
      programId: action.programId,
    );
  }

  /// Records that [program]'s ladder moved an exercise [from] one rung [to]
  /// the next, caused by [workoutId] (heart-api#231): deleting that workout
  /// takes it back, as [undo] does. The session template and the rule's key
  /// are the caller's to move.
  Future<ProgramAction> advance(
    Program program, {
    required String from,
    required String to,
    required String workoutId,
    DateTime? at,
  }) {
    final action = ProgramAction(
      id: uuidV7(),
      programId: program.id,
      kind: .advance,
      from: from,
      to: to,
      workoutId: workoutId,
      at: at ?? DateTime.timestamp(),
    );
    return _record(
      action,
      .action,
      into: _actions,
      idOf: (action) => action.id,
      store: _service.storeProgramAction,
      confirm: _confirmAction,
      programId: action.programId,
    );
  }

  /// Records that [program]'s stages rule moved [exerciseId] — or its
  /// occurrence [slot], when the rule is that occurrence's own — to [stage],
  /// caused by [workoutId] (heart-api#256): deleting that workout takes it
  /// back, as [undo] does.
  Future<ProgramAction> moveStage(
    Program program, {
    required String exerciseId,
    String? slot,
    required int stage,
    required String workoutId,
    DateTime? at,
  }) {
    final action = ProgramAction(
      id: uuidV7(),
      programId: program.id,
      kind: .stage,
      exercise: exerciseId,
      slot: slot,
      stage: stage,
      workoutId: workoutId,
      at: at ?? DateTime.timestamp(),
    );
    return _record(
      action,
      .action,
      into: _actions,
      idOf: (action) => action.id,
      store: _service.storeProgramAction,
      confirm: _confirmAction,
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
    await _unowe(.action, actionId, programId: programId);
    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgramAction(programId, actionId);
      await _settle(.action, actionId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// "Not today" (#312): sets [session] of [program] aside. The session counts
  /// as done in the open cycle and nothing grows
  /// (`docs/2026-10-11.programs.md`): the position moves on, and a growth
  /// rule never reads a skip. History, not state: taking it back is [unskip].
  Future<TrainingSkip> skip(Program program, {required String session, DateTime? at}) {
    final uid = userId;
    if (uid == null) throw StateError('a skip belongs to an account or a session');
    final skip = TrainingSkip(
      id: uuidV7(),
      at: at ?? DateTime.timestamp(),
      templateId: session,
      programId: program.id,
    );
    if (program.id case final String id) _marks.putIfAbsent(id, () => []).add(ProgramMark.skip(skip));
    return _record(
      skip,
      .skip,
      into: _skips,
      idOf: (skip) => skip.id,
      store: (skip) => _service.storeSkip(skip, uid),
      confirm: _confirmSkip,
      programId: skip.programId,
    );
  }

  /// Takes [skip] back: its session is due again.
  Future<void> unskip(TrainingSkip skip) async {
    final programId = skip.programId;
    final skipId = skip.id;
    if (programId == null || skipId == null) return;

    _skips[programId]?.removeWhere((each) => each.id == skipId);
    _marks[programId]?.removeWhere(
      (mark) => !mark.isWorkout && mark.templateId == skip.templateId && mark.at.isAtSameMomentAs(skip.at),
    );
    notifyListeners();

    await _service.deleteSkip(skipId);
    await _unowe(.skip, skipId, programId: programId);
    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteSkip(skipId);
      await _settle(.skip, skipId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Sets [exerciseId]'s base in [program] to [value], with its cause: the
  /// workout that moved it, the action that did, or neither when the user set
  /// it ("Keep 57.5 kg").
  ///
  /// [slot] is the template exercise the base belongs to, when the program
  /// keeps one per occurrence of a lift used twice (heart-api#232).
  Future<ProgramBase> setBase(
    Program program, {
    required String exerciseId,
    required num value,
    String? slot,
    String? workoutId,
    String? actionId,
    DateTime? at,
  }) {
    assert(workoutId == null || actionId == null, 'a base has one cause');
    final base = ProgramBase(
      id: uuidV7(),
      programId: program.id,
      exerciseId: exerciseId,
      slot: slot,
      value: value,
      workoutId: workoutId,
      actionId: actionId,
      at: at ?? DateTime.timestamp(),
    );
    return _record(
      base,
      .base,
      into: _bases,
      idOf: (base) => base.id,
      store: _service.storeProgramBase,
      confirm: _confirmBase,
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
    await _unowe(.base, baseId, programId: programId);
    if (!_remote.allowed) return;

    try {
      await _remoteService.deleteProgramBase(programId, baseId);
      await _settle(.base, baseId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// What finished workouts did to their programs, by workout id: written
  /// once per workout, and read back by the Done page (#351).
  final _grown = <String, Future<List<GrowthMove>>>{};

  /// Runs [workout]'s program's growth rules over it (#350) and writes what
  /// they say: a base grown or cut, a ladder's advance with its session
  /// swapped and its rule moved along, a test session's training maxes.
  /// Once per workout: a second call has the first's answer, and a workout
  /// something was already written for (a finish another device ran) moves
  /// nothing again.
  ///
  /// [session] is the template it was started from, which tells apart the
  /// two occurrences of a lift the program keeps a base for each of. [after]
  /// is the finish still writing it: the rules read the program's history
  /// from the mirror, so they wait for it, and a caller can ask the moment
  /// the finish starts.
  ///
  /// Editing the workout later runs nothing again: what moved stays moved,
  /// and the program page's bases are where it is changed by hand.
  ///
  /// [slots] are [slotsOf] the workout as it stood before the finish dropped
  /// the exercises nobody ticked.
  Future<List<GrowthMove>> grow(
    Workout workout, {
    Template? session,
    Map<String, String>? slots,
    Future<void>? after,
  }) {
    return _grown[workout.id] ??= _grow(workout, session: session, slots: slots, after: after);
  }

  /// What [grow] answered for [workoutId], while it is remembered; null when
  /// it never ran on this launch.
  Future<List<GrowthMove>>? grownBy(String workoutId) => _grown[workoutId];

  Future<List<GrowthMove>> _grow(
    Workout workout, {
    Template? session,
    Map<String, String>? slots,
    Future<void>? after,
  }) async {
    try {
      await after;
    } catch (_) {
      // the finish reports its own failure; the workout is in the mirror
      // whatever the server said
    }
    final uid = userId;
    final program = switch (workout.programId) {
      final String id => _programs[id],
      null => null,
    };
    final id = program?.id;
    if (uid == null || program == null || id == null || program.archived) return const [];
    bool causedBy(String? cause) => cause == workout.id;
    if (basesOf(id).any((base) => causedBy(base.workoutId))) return const [];
    if (actionsOf(id).any((action) => causedBy(action.workoutId))) return const [];

    try {
      final (marks, workouts) = await (
        _service.getProgramMarks(uid, id),
        _service.getProgramWorkouts(uid, id),
      ).wait;
      final start = workout.start;

      // the position as it stood at [moment], and with [plus] marked in it
      ProgramPosition at(DateTime moment, {ProgramMark? plus}) {
        return ProgramPosition.of(
          program,
          marks: [...marks.where((mark) => mark.at.isBefore(moment)), ?plus],
          actions: actionsOf(id).where((action) => action.at.isBefore(moment)),
          now: moment,
        );
      }

      final before = at(start);
      final after = at(start, plus: ProgramMark.workout(workout));
      final moves = growthOf(
        program,
        workout,
        bases: currentBasesOf(id),
        actions: _actions[id] ?? const [],
        earlier: [
          for (final each in workouts)
            if (each.id != workout.id && each.start.isBefore(start)) (workout: each, lighter: at(each.start).lighter),
        ],
        before: before,
        closesCycle: after.week > before.week,
        session: session,
        slots: slots,
      );

      // each move on its own: one that fails is reported and left out, and
      // the ones written before and after it still reach Done with their Keep
      final written = <GrowthMove>[];
      for (final move in moves) {
        try {
          written.add(await _write(move, programId: id, workoutId: workout.id));
        } catch (e, s) {
          onError?.call(e, stacktrace: s);
        }
      }
      return written;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      // nothing was written: forget the answer, so asking again runs it again
      _grown.remove(workout.id);
      return const [];
    }
  }

  Future<GrowthMove> _write(GrowthMove move, {required String programId, required String workoutId}) async {
    final program = _programs[programId];
    if (program == null) return move;
    switch (move.step) {
      case Grow(:final value) || Cut(:final value):
        final base = await setBase(
          program,
          exerciseId: move.exerciseId,
          value: value,
          slot: move.slot,
          workoutId: workoutId,
        );
        return move.written(base: base);
      case Advance(:final to):
        final action = await advance(program, from: move.exerciseId, to: to, workoutId: workoutId);
        await _climb(program, from: move.exerciseId, to: to);
        return move.written(action: action);
      case ToStage(:final stage, :final base):
        final action = await moveStage(
          program,
          exerciseId: move.exerciseId,
          slot: move.slot,
          stage: stage,
          workoutId: workoutId,
        );
        // the last stage's miss starts over lighter: a base of its own
        final cut = switch (base) {
          final num value => await setBase(
            program,
            exerciseId: move.exerciseId,
            value: value,
            slot: move.slot,
            workoutId: workoutId,
          ),
          null => null,
        };
        return move.written(base: cut, action: action);
      case Hold() || Missed():
        return move;
    }
  }

  /// "Keep" (#351): takes back what [move] wrote, and nothing else. A base
  /// goes back to the one before it; a stage to the one before; an advance
  /// goes back down its ladder, sessions and rule with it.
  Future<void> keep(GrowthMove move) async {
    if (move.base case final ProgramBase base) await deleteBase(base);
    if (move.action case final ProgramAction action) {
      await undo(action);
      if (action case ProgramAction(kind: .advance, :final programId?, :final from?, :final to?)) {
        if (lookup(programId) case final Program program) await _climb(program, from: to, to: from);
      }
    }
  }

  /// "In the program" on a replace from the sheet (#354): [to] takes [from]'s
  /// place in every session of [program] that holds it, and [from]'s growth
  /// rule moves across with it. Bases stay with [from]: a different exercise's
  /// load is its own to find, and a replace taken back finds them again.
  Future<void> replaceExercise(Program program, {required String from, required String to}) {
    return _climb(program, from: from, to: to);
  }

  /// Moves [program]'s ladder rule from [from] to [to], and its sessions'
  /// [from] to [to] with it (heart-api#231): the rule is keyed by the rung the
  /// sessions hold.
  ///
  /// When [to] already has a rule of its own, the rules stay as they are: [to]
  /// keeps its own, which its other sessions grow by, and the moved one stays
  /// under [from], where moving back finds it again. Re-keying would put two
  /// rules on one key and silently lose one of them.
  Future<void> _climb(Program program, {required String from, required String to}) async {
    final current = _programs[program.id] ?? program;
    if (!current.rules.containsKey(to)) {
      await update(
        current.copyWith(
          rules: {
            for (final MapEntry(:key, :value) in current.rules.entries) key == from ? to : key: value,
          },
        ),
      );
    }
    await onAdvance?.call(current.sessions, from: from, to: to);
  }

  /// Reads every program's marks from the mirror again: a workout of one was
  /// finished, deleted, or arrived from another device. Its steps and bases
  /// too: a deleted workout takes the bases and the advance it caused.
  Future<void> refreshMarks() async {
    final id = userId;
    if (id == null) return;
    await _step(() async {
      final (actions, bases) = await (_service.getProgramActions(id), _service.getProgramBases(id)).wait;
      await _readMarks(id);
      if (userId != id) return;
      _group(_actions, actions, (action) => action.programId);
      _group(_bases, bases, (base) => base.programId);
      notifyListeners();
    });
  }

  /// [Workouts.historyRevision] when last looked at. A change is a workout
  /// finished, edited, deleted or paged down, already in the mirror: each may
  /// move a position.
  int? _heldRevision;

  void _onWorkouts() {
    final revision = _workouts?.historyRevision;
    if (revision == _heldRevision) return;
    _heldRevision = revision;
    if (_programs.isNotEmpty) refreshMarks();
  }

  Future<void> _readMarks(String uid) async {
    final ids = [..._programs.keys];
    final marks = await Future.wait(ids.map((programId) => _service.getProgramMarks(uid, programId)));
    _marks
      ..clear()
      ..addAll(Map.fromIterables(ids, marks));
  }

  /// Keeps the server's [row] in place of the local copy.
  Future<Program> _keep(Program row, String uid) async {
    await _service.storeProgram(row, uid);
    if (row.id case final String id) _programs[id] = row;
    notifyListeners();
    return row;
  }

  /// Writes [row] locally and, with the remote leg open, to the server, whose
  /// copy then replaces it ([confirm]).
  Future<T> _record<T>(
    T row,
    ProgramRow kind, {
    required Map<String, List<T>> into,
    required String? Function(T) idOf,
    required Future<void> Function(T) store,
    required Future<T> Function(T) confirm,
    required String? programId,
  }) async {
    final id = idOf(row);
    if (programId == null || id == null) throw ArgumentError.notNull('programId');
    into.putIfAbsent(programId, () => []).add(row);
    notifyListeners();
    await store(row);
    await _owe(kind, id, .created, programId: programId);

    if (!_remote.allowed) return row;

    try {
      final saved = await confirm(row);
      await _settle(kind, id);
      return saved;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return row;
    }
  }

  Future<ProgramAction> _confirmAction(ProgramAction action) {
    return _confirm(
      action,
      into: _actions,
      idOf: (action) => action.id,
      store: _service.storeProgramAction,
      forget: _service.deleteProgramAction,
      replay: _remoteService.replayProgramAction,
    );
  }

  Future<TrainingSkip> _confirmSkip(TrainingSkip skip) {
    return _confirm(
      skip,
      into: _skips,
      idOf: (skip) => skip.id,
      store: (skip) async {
        if (userId case final String uid) await _service.storeSkip(skip, uid);
      },
      forget: _service.deleteSkip,
      replay: _remoteService.replaySkip,
    );
  }

  Future<ProgramBase> _confirmBase(ProgramBase base) {
    return _confirm(
      base,
      into: _bases,
      idOf: (base) => base.id,
      store: _service.storeProgramBase,
      forget: _service.deleteProgramBase,
      replay: _remoteService.replayProgramBase,
    );
  }

  /// Sends [row] to the server and keeps its copy. The server's can be another
  /// row: a bump a second device already wrote for the same workout comes back
  /// as the first one, and this device's copy goes ([forget]).
  Future<T> _confirm<T>(
    T row, {
    required Map<String, List<T>> into,
    required String? Function(T) idOf,
    required Future<void> Function(T) store,
    required Future<void> Function(String id) forget,
    required Future<Replayed<T>> Function(T) replay,
  }) async {
    final (row: saved, created: _) = await replay(row);
    final (mine, theirs) = (idOf(row), idOf(saved));
    if (mine != null && mine != theirs) await forget(mine);
    await store(saved);
    for (final rows in into.values) {
      if (rows.any((each) => idOf(each) == mine)) {
        rows
          ..removeWhere((each) => idOf(each) == mine || idOf(each) == theirs)
          ..add(saved);
      }
    }
    notifyListeners();
    return saved;
  }

  /// Records that the server has not confirmed [change] to [row] [id] yet.
  /// Only with an account: an anonymous session's store goes up whole, with
  /// the upsync, when one arrives.
  Future<void> _owe(ProgramRow row, String id, ProgramChange change, {required String programId}) async {
    final uid = userId;
    if (uid == null || !_remote.account) return;
    final key = (row, id);
    final owed = (
      row: row,
      id: id,
      programId: programId,
      // an edit to a row the server has never had is still its create
      change: switch ((_owed[key]?.change, change)) {
        (.created, .edited) => ProgramChange.created,
        _ => change,
      },
    );
    _owed[key] = owed;
    await _service.owePrograms(uid, owed);
  }

  /// Records a deletion: a row the server never had is owed nothing.
  Future<void> _unowe(ProgramRow row, String id, {required String programId}) async {
    switch (_owed[(row, id)]?.change) {
      case .created:
        await _settle(row, id);
      case _:
        await _owe(row, id, .deleted, programId: programId);
    }
  }

  Future<void> _settle(ProgramRow row, String id) async {
    if (_owed.remove((row, id)) == null) return;
    await _service.settleProgram(row, id);
  }

  /// Sends what the server is owed: programs before what names them, and a
  /// program's deletion after the rows it takes with it. Stops at the first
  /// failure that is not a refusal: the network is down, and the rest would
  /// only fail the same way.
  Future<void> _flush(String uid) async {
    final owed = [..._owed.values]..sort((a, b) => _turn(a).compareTo(_turn(b)));
    for (final each in owed) {
      if (userId != uid) return;
      // settled on the way: a program's create files its sessions
      if (!_owed.containsKey((each.row, each.id))) continue;
      try {
        await _send(each, uid);
        await _settle(each.row, each.id);
      } catch (e, s) {
        onError?.call(e, stacktrace: s);
        // asking again gets the same answer: the row stays as it is here,
        // and the server's copy decides what the next read keeps
        if (!_isRefusal(e)) return;
        await _settle(each.row, each.id);
      }
    }
  }

  static int _turn(ProgramOwed owed) {
    return switch (owed) {
      (row: .program, change: .created || .edited, id: _, programId: _) => 0,
      (row: .action || .base || .session || .skip, change: .created || .edited, id: _, programId: _) => 1,
      (row: .action || .base || .session || .skip, change: _, id: _, programId: _) => 2,
      (row: .program, change: _, id: _, programId: _) => 3,
    };
  }

  Future<void> _send(ProgramOwed owed, String uid) async {
    final (:row, :id, :programId, :change) = owed;
    switch ((row, change)) {
      case (.program, .created):
        if (_programs[id] case final Program program) {
          final sessions = [
            for (final template in await _templates.getTemplates(uid))
              if (template.programId == id) template,
          ];
          await _push(program, uid, sessions: sessions);
        }
      case (.program, .edited):
        if (_programs[id] case final Program program) await _keep(await _remoteService.editProgram(program), uid);
      case (.program, .deleted || .deletedKeepingTemplates):
        await _remoteService.deleteProgram(id, keepTemplates: change == .deletedKeepingTemplates);
      case (.action, .created || .edited):
        if (_held(_actions, programId, id, (action) => action.id) case final ProgramAction action) {
          await _confirmAction(action);
        }
      case (.action, _):
        await _remoteService.deleteProgramAction(programId, id);
      case (.base, .created || .edited):
        if (_held(_bases, programId, id, (base) => base.id) case final ProgramBase base) await _confirmBase(base);
      case (.base, _):
        await _remoteService.deleteProgramBase(programId, id);
      case (.skip, .created || .edited):
        // read from the mirror, not the program's list: one whose program
        // was deleted since is owed all the same
        final held = await _service.getSkips(uid);
        if (held.where((skip) => skip.id == id).firstOrNull case final TrainingSkip skip) await _confirmSkip(skip);
      case (.skip, _):
        await _remoteService.deleteSkip(id);
      case (.session, _):
        final held = await _templates.getTemplates(uid);
        if (held.where((template) => template.id == id).firstOrNull case final Template session) {
          await _file(session, programId, uid);
          await onSessionsChanged?.call();
        }
    }
  }

  static T? _held<T>(Map<String, List<T>> rows, String programId, String id, String? Function(T) idOf) {
    return rows[programId]?.where((each) => idOf(each) == id).firstOrNull;
  }

  /// The server's [programs], but for what this device still owes it: one it
  /// has not had yet, or not this version of, is the mirror's, and one deleted
  /// here stays deleted.
  List<Program> _merged(List<Program> programs) {
    final owed = {
      for (final each in _owed.values)
        if (each.row == .program) each.id: each.change,
    };
    return [
      for (final program in programs)
        if (!owed.containsKey(program.id)) program,
      for (final MapEntry(key: id, value: change) in owed.entries)
        if ((change == .created || change == .edited) && _programs[id] != null) _programs[id]!,
    ]..sort(_byCreation);
  }

  static int _byCreation(Program a, Program b) {
    return switch ((a.createdAt, b.createdAt)) {
      (final DateTime x, final DateTime y) when x != y => x.compareTo(y),
      _ => (a.id ?? '').compareTo(b.id ?? ''),
    };
  }

  /// As [_merged], for one program's actions or bases.
  List<T> _rowsOwed<T>(List<T> theirs, ProgramRow row, List<T> held, String? Function(T) idOf) {
    final owed = {
      for (final each in _owed.values)
        if (each.row == row) each.id: each.change,
    };
    return [
      for (final each in theirs)
        if (!owed.containsKey(idOf(each))) each,
      for (final each in held)
        if (owed[idOf(each)] == .created) each,
    ];
  }

  /// Answers the server gives that repeating would only repeat: a rule or key
  /// it does not take, a cap reached, a row it does not have.
  static const _refusals = {
    'invalid_rule',
    'invalid_key',
    'invalid_deload',
    'invalid_phase',
    'invalid_test',
    'invalid_target',
    'program_limit',
    'program_history_limit',
    'program_not_found',
    'unknown_program',
    'unknown_exercise',
    'unknown_workout',
    'unknown_action',
    'skip_limit',
  };

  static bool _isRefusal(Object error) {
    return switch (error) {
      {'code': final String code} => _refusals.contains(code),
      _ => false,
    };
  }

  void _replace(Iterable<Program> programs) {
    _programs
      ..clear()
      ..addEntries([
        for (final program in programs)
          if (program.id case final String id) MapEntry(id, program),
      ]);
  }

  void _groupSkips(Iterable<TrainingSkip> skips) {
    _group(_skips, skips, (skip) => skip.programId);
    _orphanSkips
      ..clear()
      ..addAll(skips.where((skip) => skip.programId == null));
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
