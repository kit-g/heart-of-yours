import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'coaching.dart' show CoachingStatus;
import 'remote.dart';
import 'template_drafting.dart';

/// What the server does with a coach's library (heart-of-yours#557). Like
/// [RosterService], the app's view of a few routes, which the app adapts
/// `Api` onto.
abstract interface class CoachLibraryService {
  /// The library, a page at a time, without bodies.
  Future<({List<CoachProgram> items, String? cursor})> getLibraryPrograms({String? cursor});

  /// One program, with its body.
  Future<CoachProgram> getLibraryProgram(String programId);

  /// Saves [body] under [programId], the first time or as a new version.
  Future<CoachProgram> saveLibraryProgram(String programId, Map<String, dynamic> body);

  Future<void> deleteLibraryProgram(String programId);

  /// Which clients hold a copy, and of which version.
  Future<List<CoachProgramHolder>> getLibraryHolders(String programId);

  /// Copies the program to each connection; each answers on its own.
  Future<List<ProgramDelivery>> sendLibraryProgram(String programId, Iterable<String> connectionIds);
}

/// One of a coach's library programs, read whole: its own fields as a
/// [Program], and its sessions as [Template]s, the shapes the program form
/// and the template editor already edit.
///
/// The body is a document the server keeps as it is sent, so what this build
/// can't read stays in it: [toBody] writes the fields and sessions back over
/// the body as it came.
class CoachLibraryProgram {
  final String id;

  /// The version the server holds; each save makes a new one.
  final int version;

  final DateTime updatedAt;

  final Program program;

  final List<Template> sessions;

  final Map<String, dynamic> _body;

  const new _({
    required this.id,
    required this.version,
    required this.updatedAt,
    required this.program,
    required this.sessions,
    required this._body,
  });

  /// [program], read with its body. A body's exercises are named by id, and
  /// [exerciseOf] finds each among the coach's: one it can't is kept as it
  /// came, unread, and saved back so.
  factory fromCoachProgram(CoachProgram program, {required Exercise? Function(String id) exerciseOf}) {
    final body = {...?program.body};
    Map<String, dynamic> exercise(Map each) {
      return {
        ...each.cast<String, dynamic>(),
        if (each['exercise'] case final String id)
          if (exerciseOf(id) case final Exercise known) 'exercise': known.toMap(),
      };
    }

    final sessions = [
      for (final (index, session) in ((body['sessions'] as List?) ?? const []).whereType<Map>().indexed)
        Template.fromJson({
          ...session,
          'order': index,
          'exercises': [
            for (final each in (session['exercises'] as List?) ?? const [])
              if (each is Map) exercise(each),
          ],
        }),
    ];
    return CoachLibraryProgram._(
      id: program.id,
      version: program.version,
      updatedAt: program.updatedAt,
      program: Program.fromJson({'name': program.name, ...body, 'id': program.id, 'sessions': const []}),
      sessions: sessions,
      body: body,
    );
  }

  /// A program that has never been saved.
  factory blank(Program program) {
    final id = uuidV7();
    return CoachLibraryProgram._(
      id: id,
      version: 0,
      updatedAt: DateTime.timestamp(),
      program: program,
      sessions: const [],
      body: const {},
    );
  }

  /// This program with [program]'s fields and [sessions], unsaved.
  CoachLibraryProgram copyWith({Program? program, List<Template>? sessions}) {
    return CoachLibraryProgram._(
      id: id,
      version: version,
      updatedAt: updatedAt,
      program: program ?? this.program,
      sessions: sessions ?? this.sessions,
      body: _body,
    );
  }

  /// The body a save sends: `POST /programs`' shape, sessions in order, and
  /// each exercise named by its id.
  Map<String, dynamic> toBody() {
    Map<String, dynamic> exercise(Map each) {
      return {
        ...each.cast<String, dynamic>(),
        if (each['exercise'] case final Map named) 'exercise': named['id'],
      }..remove('start');
    }

    final fields = program.toMap()
      ..removeWhere((key, _) => const {'id', 'sessions', 'archived', 'createdAt', 'joined'}.contains(key));
    return {
      // a field taken away is gone from the body too, not kept from before
      ...{..._body}..removeWhere((key, _) => _programKeys.contains(key)),
      ...fields,
      'sessions': [
        for (final session in sessions)
          {
            'id': session.id,
            'name': ?session.name,
            'note': ?session.note,
            'exercises': [
              for (final each in session.toMap()['exercises'] as List)
                if (each is Map) exercise(each),
            ],
          },
      ],
    };
  }

  static const _programKeys = {
    'name',
    'note',
    'source',
    'perWeek',
    'days',
    'weeks',
    'rules',
    'constraint',
    'deload',
    'phases',
    'tests',
    'sessions',
  };
}

/// How sending a program to one client went, by the `reason` the server
/// gives; open like `ClientReason`.
enum DeliveryRefusal {
  /// No longer coached by the coach.
  notCoaching('not_coaching'),

  /// Holds as many programs as they may.
  programLimit('program_limit'),

  /// An exercise of the program could not be given to them.
  unknownExercise('unknown_exercise');

  final String code;

  new(this.code);

  static DeliveryRefusal? of(String? code) => values.where((each) => each.code == code).firstOrNull;
}

/// A coach's library: programs written for clients, apart from the coach's
/// own training, kept on the server as versioned documents, and sent as
/// copies the clients own.
///
/// Server-only, as [Roster] is, and read only when the Programs tab of the
/// Coaching space opens. A session of a program is edited in the template
/// editor through [TemplateDrafting]; its save is a save of the program.
///
/// A save that doesn't reach the server is kept here, and the program is
/// [unsaved] until [retry] gets it there: the coach's work is not dropped on
/// a bad connection.
class CoachLibrary with ChangeNotifier, TemplateDrafting implements SignOutStateSentry {
  final CoachLibraryService _service;
  final RemoteAccess _remote;
  final Exercise? Function(String id) _exerciseOf;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  final _programs = <CoachProgram>[];
  final _open = <String, CoachLibraryProgram>{};
  final _unsaved = <String>{};
  final _saving = <String>{};
  CoachingStatus _status = .idle;

  /// The program [editable] is a session of.
  String? _drafting;

  new({
    required this._service,
    required this._exerciseOf,
    RemoteAccess? remote,
    this.onError,
  }) : _remote = remote ?? RemoteAccess();

  static CoachLibrary of(BuildContext context) => Provider.of<CoachLibrary>(context, listen: false);

  static CoachLibrary watch(BuildContext context) => Provider.of<CoachLibrary>(context, listen: true);

  CoachingStatus get status => _status;

  /// The library, the most recently changed first.
  List<CoachProgram> get programs => UnmodifiableListView(_programs);

  /// A program read whole by [open], or made here.
  CoachLibraryProgram? lookup(String id) => _open[id];

  /// Whether [id]'s last change failed to reach the server, and is only on
  /// this device.
  bool unsaved(String id) => _unsaved.contains(id);

  /// Whether a change to [id] is on its way to the server.
  bool saving(String id) => _saving.contains(id);

  @override
  void onSignOut() {
    _programs.clear();
    _open.clear();
    _unsaved.clear();
    _saving.clear();
    _status = .idle;
    _drafting = null;
    editable = null;
    notifyListeners();
  }

  /// Reads the library, every page of it.
  Future<void> load() async {
    if (!_remote.allowed) return;
    _status = .loading;
    notifyListeners();
    try {
      final all = <CoachProgram>[];
      String? cursor;
      do {
        final page = await _service.getLibraryPrograms(cursor: cursor);
        all.addAll(page.items);
        cursor = page.cursor;
      } while (cursor != null);
      _programs
        ..clear()
        ..addAll(all..sort(_byChange));
      _status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// Reads [id] whole. One with a change still unsaved stays as this device
  /// has it. Throws what the service threw.
  Future<CoachLibraryProgram> open(String id) async {
    if ((_unsaved.contains(id) || _saving.contains(id)) && _open[id] != null) return _open[id]!;
    final program = await _service.getLibraryProgram(id);
    final read = CoachLibraryProgram.fromCoachProgram(program, exerciseOf: _exerciseOf);
    _open[id] = read;
    _summarize(program);
    notifyListeners();
    return read;
  }

  /// A new program of [fields], with no sessions yet, saved as its first
  /// version. Throws what the service threw, and keeps nothing then.
  Future<CoachLibraryProgram> create(Program fields) async {
    final blank = CoachLibraryProgram.blank(fields);
    final saved = await _service.saveLibraryProgram(blank.id, blank.toBody());
    final read = CoachLibraryProgram.fromCoachProgram(saved, exerciseOf: _exerciseOf);
    _open[read.id] = read;
    _summarize(saved);
    notifyListeners();
    return read;
  }

  /// Saves [program] as it now is: here at once, then on the server. Answers
  /// whether the server took it.
  Future<bool> save(CoachLibraryProgram program) async {
    _open[program.id] = program;
    _saving.add(program.id);
    notifyListeners();
    try {
      final saved = await _service.saveLibraryProgram(program.id, program.toBody());
      // a later change made while this one was on its way is the one kept
      if (identical(_open[program.id], program)) {
        _open[program.id] = CoachLibraryProgram.fromCoachProgram(saved, exerciseOf: _exerciseOf);
        _unsaved.remove(program.id);
        _saving.remove(program.id);
      }
      _summarize(saved);
      notifyListeners();
      return true;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      if (identical(_open[program.id], program)) {
        _unsaved.add(program.id);
        _saving.remove(program.id);
      }
      notifyListeners();
      return false;
    }
  }

  /// Sends [id]'s unsaved change again.
  Future<bool> retry(String id) async {
    return switch (_open[id]) {
      final CoachLibraryProgram program => save(program),
      null => Future.value(false),
    };
  }

  /// Takes [session] out of [program], and saves it.
  Future<bool> removeSession(CoachLibraryProgram program, Template session) {
    return save(program.copyWith(sessions: [...program.sessions.where((each) => each.id != session.id)]));
  }

  /// Moves the session at [from] to [to], its place once it has moved.
  Future<bool> moveSession(CoachLibraryProgram program, int from, int to) {
    final sessions = [...program.sessions];
    final moved = sessions.removeAt(from);
    sessions.insert(to, moved);
    return save(program.copyWith(sessions: sessions));
  }

  /// Deletes [id] from the library. Clients keep their copies. Throws what
  /// the service threw, and changes nothing here then.
  Future<void> delete(String id) async {
    await _service.deleteLibraryProgram(id);
    _programs.removeWhere((each) => each.id == id);
    _open.remove(id);
    _unsaved.remove(id);
    _saving.remove(id);
    notifyListeners();
  }

  /// Which clients hold [id], and of which version. Throws what the service
  /// threw.
  Future<List<CoachProgramHolder>> holders(String id) => _service.getLibraryHolders(id);

  /// Sends [id] to each of [connectionIds]. Throws what the service threw.
  Future<List<ProgramDelivery>> send(String id, Iterable<String> connectionIds) {
    return _service.sendLibraryProgram(id, connectionIds);
  }

  /// Opens [session] of [program] in the editor, or a new one with none.
  /// The editor works on a copy: leaving it leaves the program as it was.
  void editSession(CoachLibraryProgram program, {Template? session}) {
    _drafting = program.id;
    editable = switch (session) {
      final Template session => Template.fromJson(session.toMap()),
      null => Template.empty(id: uuidV7(), order: program.sessions.length),
    };
    notifyListeners();
  }

  @override
  Future<Template> startDraft() async {
    final count = switch (_drafting) {
      final String id => _open[id]?.sessions.length ?? 0,
      null => 0,
    };
    return Template.empty(id: uuidV7(), order: count);
  }

  /// Puts the session in its program, where it was or last, and saves the
  /// program.
  @override
  Future<void> saveEditable() async {
    final (session, program) = (editable, _open[_drafting]);
    editable = null;
    _drafting = null;
    notifyListeners();
    if (session == null || program == null) return;
    final sessions = switch (program.sessions.indexWhere((each) => each.id == session.id)) {
      -1 => [...program.sessions, session],
      final index => [...program.sessions]..[index] = session,
    };
    await save(program.copyWith(sessions: sessions));
  }

  @override
  Future<void> discardEditable() async {
    editable = null;
    _drafting = null;
    notifyListeners();
  }

  void _summarize(CoachProgram program) {
    final summary = CoachProgram(
      id: program.id,
      name: program.name,
      version: program.version,
      updatedAt: program.updatedAt,
    );
    _programs
      ..removeWhere((each) => each.id == program.id)
      ..add(summary)
      ..sort(_byChange);
  }

  static int _byChange(CoachProgram a, CoachProgram b) => b.updatedAt.compareTo(a.updatedAt);
}
