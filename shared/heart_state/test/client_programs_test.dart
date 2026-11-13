import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// One copy on the server, with revisions as the server keeps them.
class _Server implements ClientProgramService {
  var programRevision = 0;
  final sessionRevisions = <String, int>{'s1': 0};
  final sessions = <String, Template>{};
  final changes = <ProgramChange>[];
  final writes = <(String, int)>[];
  final reverted = <String>[];
  Object? refuse;

  var managed = true;

  @override
  Future<List<Program>> getClientPrograms(String studentId) async {
    return [if (managed) Program(id: 'p1', name: 'Strength block', perWeek: 2, weeks: 4)];
  }

  @override
  Future<CoachProgramView> getClientProgram(String studentId, String programId) async {
    return CoachProgramView.fromJson({
      'program': {
        'id': programId,
        'name': 'Strength block',
        'perWeek': 2,
        'weeks': 4,
        'sessions': sessionRevisions.keys.toList(),
        'revision': programRevision,
        'sessionRevisions': sessionRevisions,
      },
      'sessions': [
        for (final id in sessionRevisions.keys)
          {'id': id, 'name': 'Day A', 'order': 0, 'programId': programId, 'exercises': <Object>[]},
      ],
      'position': {'week': 1},
    });
  }

  @override
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since}) async {
    return changes;
  }

  @override
  Future<void> editClientSession(
    String studentId,
    String programId,
    Template session, {
    required int baseRevision,
    required String changeId,
  }) async {
    if (refuse case final refusal?) throw refusal;
    writes.add((session.id, baseRevision));
    if (baseRevision != sessionRevisions[session.id]) {
      throw {'code': 'program_changed', 'revision': sessionRevisions[session.id]};
    }
    sessionRevisions[session.id] = baseRevision + 1;
  }

  @override
  Future<Program> editClientProgram(
    String studentId,
    Program program, {
    required int baseRevision,
    required String changeId,
  }) async {
    if (baseRevision != programRevision) throw {'code': 'program_changed', 'revision': programRevision};
    programRevision++;
    return program;
  }

  @override
  Future<void> deleteClientSession(String studentId, String programId, String sessionId) async {
    sessionRevisions.remove(sessionId);
  }

  @override
  Future<void> revertClientChange(String studentId, String programId, String changeId) async {
    reverted.add(changeId);
  }
}

void main() {
  late _Server server;
  late ClientPrograms programs;

  setUp(() {
    server = _Server();
    programs = ClientPrograms(service: server);
  });

  test('opens a copy with its history, newest first', () async {
    server.changes.addAll([
      ProgramChange(id: 'c1', programId: 'p1', kind: 'edit', revision: 1, at: DateTime.utc(2026, 11, 1)),
      ProgramChange(id: 'c2', programId: 'p1', kind: 'edit', revision: 2, at: DateTime.utc(2026, 11, 2)),
    ]);

    await programs.open('sam', 'p1');

    expect(programs.status('p1'), CoachingStatus.loaded);
    expect(programs.view('p1')?.sessions.single.id, 's1');
    expect(programs.changes('p1').map((each) => each.id), ['c2', 'c1']);
  });

  test("a session saved from the revision read lands, and the next starts from the server's", () async {
    await programs.open('sam', 'p1');
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    await programs.saveEditable();

    expect(server.writes, [('s1', 0)]);
    expect(programs.conflict('p1'), isNull);
    expect(programs.view('p1')?.program.sessionRevisions['s1'], 1);
  });

  test('a save the client beat to it is kept, and Keep mine sends it again from theirs', () async {
    await programs.open('sam', 'p1');
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    server.sessionRevisions['s1'] = 3; // the client edited Day A meanwhile
    await programs.saveEditable();

    final conflict = programs.conflict('p1');
    expect(conflict?.session?.id, 's1');
    expect(conflict?.unsent, isFalse);

    await programs.keepMine('sam', 'p1');
    expect(server.writes.last, ('s1', 3));
    expect(programs.conflict('p1'), isNull);
  });

  test("Keep theirs lets the coach's version go", () async {
    await programs.open('sam', 'p1');
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    server.sessionRevisions['s1'] = 3;
    await programs.saveEditable();

    programs.dropMine('p1');

    expect(programs.conflict('p1'), isNull);
    expect(server.writes, hasLength(1));
  });

  test('a save that never arrived is kept as unsent', () async {
    await programs.open('sam', 'p1');
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    server.refuse = Exception('offline');
    await programs.saveEditable();

    expect(programs.conflict('p1')?.unsent, isTrue);
  });

  test("the program's own fields conflict the same way", () async {
    await programs.open('sam', 'p1');
    server.programRevision = 2;

    await programs.editFields('sam', programs.view('p1')!.program);

    expect(programs.conflict('p1')?.fields, isNotNull);
  });

  test('putting a change back reads the copy again', () async {
    await programs.open('sam', 'p1');
    final change = ProgramChange(id: 'c1', programId: 'p1', kind: 'edit', revision: 1, at: DateTime.utc(2026, 11, 1));

    await programs.revert('sam', 'p1', change);

    expect(server.reverted, ['c1']);
  });

  test('their own program is theirs: the coach sees it, and may not change it', () async {
    server.managed = false;
    await programs.open('sam', 'p1');
    expect(programs.mayChange('p1'), isFalse);

    server.managed = true;
    await programs.open('sam', 'p1');
    expect(programs.mayChange('p1'), isTrue);
  });

  test('a write refused as no longer theirs is kept to say so, and the copy stays read-only after a read', () async {
    await programs.open('sam', 'p1');
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    server.refuse = {'code': 'forbidden'};
    await programs.saveEditable();

    expect(programs.conflict('p1')?.refused, isTrue);
    expect(programs.mayChange('p1'), isFalse, reason: 'still listed as sent, but refused');

    await programs.open('sam', 'p1');
    expect(programs.mayChange('p1'), isFalse);
  });

  test('sign-out forgets every copy', () async {
    await programs.open('sam', 'p1');
    programs.onSignOut();
    expect(programs.view('p1'), isNull);
  });
}
