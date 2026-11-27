import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'analytics.dart';
import 'coaching.dart' show CoachingStatus;
import 'program_plan.dart';
import 'programs.dart' show ProgramLife;
import 'remote.dart';
import 'template_drafting.dart';

/// What the server does with a coach's work on a client's copy of a program
/// (heart-of-yours#558), the app's view of those routes.
abstract interface class ClientProgramService {
  /// The copies the coach may change: those sent through their connection.
  Future<List<Program>> getClientPrograms(String studentId);

  Future<CoachProgramView> getClientProgram(String studentId, String programId);

  Future<Program> editClientProgram(
    String studentId,
    Program program, {
    required int baseRevision,
    required String changeId,
  });

  Future<void> editClientSession(
    String studentId,
    String programId,
    Template session, {
    required int baseRevision,
    required String changeId,
  });

  Future<void> deleteClientSession(String studentId, String programId, String sessionId);

  /// Oldest first.
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since});

  Future<void> revertClientChange(String studentId, String programId, String changeId);
}

/// A save to a copy two people edit that didn't land: the other person
/// changed the same session (or the program's own fields) first, or the save
/// never arrived ([unsent]). Nothing was saved; the version made here waits
/// until it is kept or let go. The coach's on a client's copy
/// ([ClientPrograms]), the student's on their own (`Programs`).
final class ProgramConflict {
  final String programId;

  /// The save never reached the server, rather than losing to the client.
  final bool unsent;

  /// The server refused it: the coach may no longer change this copy (the
  /// connection paused or ended). Nothing to send again.
  final bool refused;

  /// The session the coach edited; null when it was the program's own fields.
  final Template? session;

  /// The program's fields as the coach wanted them, when those were the edit.
  final Program? fields;

  const new({required this.programId, this.session, this.fields, this.unsent = false, this.refused = false});
}

/// Whether [local], folded on this device, is where the server says the
/// client stands ([server], `CoachProgramView.position`).
bool _agrees(ProgramPosition local, Map<String, dynamic> server) {
  return local.week == server['week'] &&
      local.next == server['next'] &&
      local.lighter == (server['lighter'] ?? local.lighter);
}

/// The server's refusal of a write because the other person changed the same
/// thing first.
bool isProgramChanged(Object? error) => error is ServerRefusal && error.code == 'program_changed';

/// The server's refusal of a write the coach may no longer make: the copy
/// wasn't sent through their connection, or it ended.
bool _isForbidden(Object? error) => error is ServerRefusal && error.code == 'forbidden';

/// A coach's view of their clients' copies (#558): one open at a time, its
/// sessions, its history, and the editor on one of its sessions.
///
/// Both people edit a copy. Each write says which revision it started from,
/// so it conflicts only when the other person changed that same thing since;
/// then [conflict] holds what the coach wanted, and nothing is lost.
class ClientPrograms with ChangeNotifier, TemplateDrafting implements SignOutStateSentry {
  final ClientProgramService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// Told of each change once the server took it: a save kept as a conflict
  /// is not one, until [keepMine] lands it.
  final Analytics? analytics;

  new({required this._service, RemoteAccess? remote, this.onError, this.analytics})
    : _remote = remote ?? RemoteAccess();

  static ClientPrograms of(BuildContext context) => Provider.of<ClientPrograms>(context, listen: false);

  static ClientPrograms watch(BuildContext context) => Provider.of<ClientPrograms>(context, listen: true);

  final _views = <String, CoachProgramView>{};
  final _changes = <String, List<ProgramChange>>{};
  final _status = <String, CoachingStatus>{};
  final _conflicts = <String, ProgramConflict>{};
  final _editable = <String, bool>{};

  /// Copies whose writes the server refused: no longer the coach's to change,
  /// whatever the list of copies they sent says.
  final _refused = <String>{};
  final _managed = <String, List<Program>>{};

  /// The client and copy [editable] belongs to.
  ({String studentId, String programId})? _drafting;

  /// A session is a client's, never the coach's own (#591).
  @override
  bool get forSomeoneElse => true;

  CoachProgramView? view(String programId) => _views[programId];

  CoachingStatus status(String programId) => _status[programId] ?? .idle;

  /// What changed in [programId], newest first.
  List<ProgramChange> changes(String programId) => List.unmodifiable((_changes[programId] ?? const []).reversed);

  ProgramConflict? conflict(String programId) => _conflicts[programId];

  /// The copies the coach sent [studentId], once [loadManaged] has read them.
  List<Program> managed(String studentId) => List.unmodifiable(_managed[studentId] ?? const <Program>[]);

  /// Reads which copies the coach sent [studentId]: they're the coach's to
  /// change, waiting or followed. Answers whether they were read.
  Future<bool> loadManaged(String studentId) async {
    if (!_remote.allowed) return false;
    try {
      _managed[studentId] = (await _service.getClientPrograms(studentId)).where((each) => !each.archived).toList();
      notifyListeners();
      return true;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return false;
    }
  }

  /// Reads what changed in each of [programIds], copies of [studentId]'s, and
  /// the steps their ladders took, for what the client did to them since the
  /// coach last looked (#745). Answers whether every one was read: one whose
  /// read failed is reported, and reads as unchanged.
  Future<bool> readChanges(String studentId, Iterable<String> programIds) async {
    if (!_remote.allowed) return false;
    Future<bool> readOne(String programId) async {
      try {
        final (changes, view) = await (
          _service.getClientProgramChanges(studentId, programId),
          _service.getClientProgram(studentId, programId),
        ).wait;
        _changes[programId] = changes;
        _advances[programId] = [
          for (final action in view.actions)
            if ((action.kind, action.from, action.to) case (.advance, final String from, final String to))
              (from: from, to: to),
        ];
        return true;
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
        return false;
      }
    }

    final read = await programIds.map(readOne).wait;
    notifyListeners();
    return read.every((each) => each);
  }

  /// The exercises each copy's ladders stepped from and to, as
  /// [readChanges] read them.
  final _advances = <String, List<({String from, String to})>>{};

  /// When [studentId] last changed [programId] themselves, as far as its
  /// changes were read, counted as the roster's `changed` counts them
  /// (heart-api#476): what the coach did never, nor where it was filed, its
  /// archiving, or what a ladder stepping up wrote. Null with none.
  ///
  /// A session the client added that is in no history isn't here, though the
  /// roster counts it. TODO(#745): once the roster says which copies changed
  /// and when (the heart-api request for it), read that here instead.
  DateTime? changedBy(String studentId, String programId) {
    final advances = _advances[programId] ?? const <({String from, String to})>[];
    return (_changes[programId] ?? const <ProgramChange>[])
        .where((change) => change.actorId == studentId)
        .where((change) => !_same(_said(change.before), _said(change.after)))
        .where((change) => !advances.any((step) => _advanced(change.before, change.after, step)))
        .map((change) => change.at)
        .fold<DateTime?>(null, (latest, at) {
          return switch (latest) {
            final DateTime latest when !at.isAfter(latest) => latest,
            _ => at,
          };
        });
  }

  /// Whether the coach may change [programId]: a copy they sent, while the
  /// connection lasts. Their client's own program they only see.
  bool mayChange(String programId) => !_refused.contains(programId) && (_editable[programId] ?? false);

  @override
  void onSignOut() {
    _views.clear();
    _changes.clear();
    _status.clear();
    _conflicts.clear();
    _editable.clear();
    _refused.clear();
    _managed.clear();
    _advances.clear();
    _drafting = null;
    editable = null;
    notifyListeners();
  }

  /// Reads [programId] as the coach can see it, and its history.
  Future<void> open(String studentId, String programId) async {
    if (!_remote.allowed) return;
    _status[programId] = .loading;
    notifyListeners();
    try {
      final (view, changes, managed) = await (
        _service.getClientProgram(studentId, programId),
        _service.getClientProgramChanges(studentId, programId),
        _service.getClientPrograms(studentId),
      ).wait;
      _views[programId] = view;
      _changes[programId] = changes;
      _editable[programId] = managed.any((each) => each.id == programId);
      _status[programId] = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status[programId] = .failed;
    }
    notifyListeners();
  }

  /// [session] laid out as the client's own device would have started it
  /// [at] (#560, heart-api#439): their bases, stages and position from what
  /// happened before then, with the plan it was asked to be. As far as the
  /// coach can see: a workout hidden from them moves none of these. [starts]
  /// are when the workouts the coach has read of theirs began: what one moved
  /// counts from then ([movedAt]).
  ///
  /// Only from a copy [open] just read: one whose last read failed is stale.
  /// And only when that read can be trusted to plan from, its history folding
  /// [now] to where the server says the client stands; an answer without the
  /// history (from before heart-api#439) doesn't. Otherwise, or for a program
  /// not running, the session as it was written, with no plan: a plan kept is
  /// kept for good, so none is better than a wrong one.
  PlannedWorkout plan(
    Template session, {
    required DateTime at,
    required DateTime now,
    required RoundWeight round,
    Map<String, DateTime> starts = const {},
  }) {
    final unplanned = (workout: session.toWorkout(), plan: null);
    final id = session.programId;
    if (id == null || status(id) != .loaded) return unplanned;
    return switch (_views[id]) {
      CoachProgramView(:final program, :final actions, :final bases, :final marks, :final position)
          when program.live &&
              _agrees(ProgramPosition.of(program, marks: marks, actions: actions, now: now), position) =>
        planProgramSession(
          session,
          program: program,
          marks: marks,
          actions: actions,
          bases: bases,
          now: now,
          at: at,
          starts: starts,
          round: round,
        ),
      _ => unplanned,
    };
  }

  /// Opens [session] of the copy in the editor, or a new one with none. The
  /// editor works on a copy of it: leaving it changes nothing.
  void editSession(String studentId, String programId, {Template? session}) {
    _drafting = (studentId: studentId, programId: programId);
    editable = switch (session) {
      final Template session => Template.fromJson(session.toMap()),
      null => Template.empty(id: uuidV7(), order: _views[programId]?.sessions.length ?? 0),
    };
    notifyListeners();
  }

  @override
  Future<Template> startDraft() async {
    final count = switch (_drafting) {
      (:final programId, studentId: _) => _views[programId]?.sessions.length ?? 0,
      null => 0,
    };
    return Template.empty(id: uuidV7(), order: count);
  }

  @override
  Future<void> saveEditable() async {
    final (session, drafting) = (editable, _drafting);
    editable = null;
    _drafting = null;
    notifyListeners();
    if (session == null || drafting == null) return;
    await _writeSession(drafting.studentId, drafting.programId, session);
  }

  @override
  Future<void> discardEditable() async {
    editable = null;
    _drafting = null;
    notifyListeners();
  }

  /// Changes the copy's own fields: name, note, weeks and days a week. A
  /// save that doesn't land is kept in [conflict].
  Future<void> editFields(String studentId, Program fields) async {
    final programId = fields.id!;
    final base = _views[programId]?.program.revision ?? 0;
    try {
      await _service.editClientProgram(studentId, fields, baseRevision: base, changeId: uuidV7());
      _conflicts.remove(programId);
      analytics?.clientProgramEdited(edit: .fields);
    } catch (error, stacktrace) {
      _settle(
        programId,
        error,
        stacktrace,
        ({required unsent, required refused}) =>
            ProgramConflict(programId: programId, fields: fields, unsent: unsent, refused: refused),
      );
    }
    await open(studentId, programId);
  }

  /// Removes a session of the copy. Throws what the service threw.
  Future<void> deleteSession(String studentId, String programId, String sessionId) async {
    await _service.deleteClientSession(studentId, programId, sessionId);
    analytics?.clientProgramEdited(edit: .sessionDeleted);
    await open(studentId, programId);
  }

  /// Saves the coach's version over the client's, from the revision just
  /// read, or sends again one that never arrived.
  Future<void> keepMine(String studentId, String programId) async {
    final conflict = _conflicts.remove(programId);
    notifyListeners();
    switch (conflict) {
      case ProgramConflict(:final Template session):
        await _writeSession(studentId, programId, session);
      case ProgramConflict(:final Program fields):
        await editFields(studentId, fields);
      default:
        break;
    }
  }

  /// Lets the coach's version go, keeping the client's.
  void dropMine(String programId) {
    if (_conflicts.remove(programId) != null) notifyListeners();
  }

  /// Puts [change] back, as a new change. Throws what the service threw,
  /// `409` among it when the client has since built on it.
  Future<void> revert(String studentId, String programId, ProgramChange change) async {
    await _service.revertClientChange(studentId, programId, change.id);
    analytics?.clientProgramEdited(edit: .reverted);
    await open(studentId, programId);
  }

  Future<void> _writeSession(String studentId, String programId, Template session) async {
    final base = _views[programId]?.program.sessionRevisions[session.id] ?? 0;
    try {
      await _service.editClientSession(studentId, programId, session, baseRevision: base, changeId: uuidV7());
      _conflicts.remove(programId);
      analytics?.clientProgramEdited(edit: .session);
    } catch (error, stacktrace) {
      _settle(
        programId,
        error,
        stacktrace,
        ({required unsent, required refused}) =>
            ProgramConflict(programId: programId, session: session, unsent: unsent, refused: refused),
      );
    }
    await open(studentId, programId);
  }

  /// A write that didn't land, kept to say so: the client got there first,
  /// it never arrived, or the server refused it because the coach may no
  /// longer change the copy, which then stays read-only.
  void _settle(
    String programId,
    Object error,
    StackTrace stacktrace,
    ProgramConflict Function({required bool unsent, required bool refused}) kept,
  ) {
    if (_isForbidden(error)) {
      _refused.add(programId);
      _conflicts[programId] = kept(unsent: false, refused: true);
      return;
    }
    final changed = isProgramChanged(error);
    if (!changed) onError?.call(error, stacktrace: stacktrace);
    _conflicts[programId] = kept(unsent: !changed, refused: false);
  }
}

/// What a snapshot of a session or a program holds besides what it says, as
/// heart-api leaves it out of `changed`: where it is filed, whether it is
/// archived, who sent it, and its revisions.
const _unsaid = {'archived', 'folder', 'assignedBy', 'revision', 'sessionRevisions'};

Map<String, dynamic>? _said(Map<String, dynamic>? snapshot) {
  return switch (snapshot) {
    final Map<String, dynamic> snapshot => {
      for (final MapEntry(:key, :value) in snapshot.entries)
        if (!_unsaid.contains(key)) key: value,
    },
    null => null,
  };
}

/// [snapshot] without [keys].
Map<String, dynamic> _without(Map<String, dynamic> snapshot, Set<String> keys) {
  return {
    for (final MapEntry(:key, :value) in snapshot.entries)
      if (!keys.contains(key)) key: value,
  };
}

/// Whether two snapshots differ only as a ladder's [step] from one exercise
/// to the next makes them, as heart-api tells one: in a session, that
/// exercise swapped for the next in place; in a program, its rule moved to
/// the next exercise.
bool _advanced(Map<String, dynamic>? before, Map<String, dynamic>? after, ({String from, String to}) step) {
  if (before == null || after == null) return false;
  List<String?>? ids(Map<String, dynamic> snapshot) {
    return switch (snapshot['exercises']) {
      final List exercises => [
        for (final each in exercises)
          switch (each) {
            {'exercise': {'id': final String id}} => id,
            _ => null,
          },
      ],
      _ => null,
    };
  }

  final session = switch ((ids(before), ids(after))) {
    (final List<String?> was, final List<String?> became) =>
      was.contains(step.from) &&
          _same([for (final id in was) _stepped(id, step)], became) &&
          _same(
            _without(before, const {'exercises', 'folder', 'assignedBy'}),
            _without(after, const {'exercises', 'folder', 'assignedBy'}),
          ),
    _ => false,
  };
  final rules = switch ((before['rules'], after['rules'])) {
    (final Map was, final Object? became) when was.containsKey(step.from) =>
      _same({for (final MapEntry(:key, :value) in was.entries) _stepped(key, step): value}, became) &&
          _same(
            _without(before, const {'rules', 'revision', 'sessionRevisions'}),
            _without(after, const {'rules', 'revision', 'sessionRevisions'}),
          ),
    _ => false,
  };
  return session || rules;
}

/// [id], or where [step] took it.
Object? _stepped(Object? id, ({String from, String to}) step) {
  return switch (id) {
    final String id when id == step.from => step.to,
    _ => id,
  };
}

/// Whether two JSON values hold the same.
bool _same(Object? a, Object? b) {
  return switch ((a, b)) {
    (final Map a, final Map b) =>
      a.length == b.length && a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key])),
    (final List a, final List b) => a.length == b.length && a.indexed.every((each) => _same(each.$2, b[each.$1])),
    _ => a == b,
  };
}
