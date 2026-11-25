import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

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

  /// What the client's device plans from (heart-api#439), and the sessions'
  /// exercises: none unless a test gives them.
  Map<String, Object> planning = {};
  List<Object> exercises = [];
  var failRead = false;

  @override
  Future<List<Program>> getClientPrograms(String studentId) async {
    return [if (managed) Program(id: 'p1', name: 'Strength block', perWeek: 2, weeks: 4)];
  }

  @override
  Future<CoachProgramView> getClientProgram(String studentId, String programId) async {
    if (failRead) throw const ServerFailed();
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
          {'id': id, 'name': 'Day A', 'order': 0, 'programId': programId, 'exercises': exercises},
      ],
      'position': {'week': 1},
      ...planning,
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
      throw refusedAs({'code': 'program_changed', 'revision': sessionRevisions[session.id]});
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
    if (baseRevision != programRevision) throw refusedAs({'code': 'program_changed', 'revision': programRevision});
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

class _FailingChanges extends _Server {
  @override
  Future<List<ProgramChange>> getClientProgramChanges(String studentId, String programId, {String? since}) async {
    throw const ServerFailed();
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

  test("when the client last changed a copy by hand: never the coach's change, nor the library's (#745)", () async {
    ProgramChange change(String id, String? actor, String kind, int day) {
      return ProgramChange(
        id: id,
        programId: 'p1',
        actorId: actor,
        kind: kind,
        revision: day,
        at: DateTime.utc(2026, 11, day),
      );
    }

    server.changes.addAll([
      change('c1', 'sam', 'edit', 1),
      change('c2', 'sam', 'create', 3),
      change('c3', 'coach', 'edit', 5),
      change('c4', null, 'library_update', 6),
    ]);
    expect(programs.changedBy('sam', 'p1'), isNull, reason: 'nothing read yet');

    await programs.readChanges('sam', ['p1']);

    expect(programs.changedBy('sam', 'p1'), DateTime.utc(2026, 11, 3));
    expect(programs.changedBy('sam', 'p2'), isNull);
  });

  test('a copy whose changes fail to read reads as unchanged, and is reported', () async {
    final errors = <Object>[];
    programs = ClientPrograms(service: _FailingChanges(), onError: (error, {stacktrace}) => errors.add(error));

    await programs.readChanges('sam', ['p1']);

    expect(programs.changedBy('sam', 'p1'), isNull);
    expect(errors, hasLength(1));
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
    server.refuse = refusedAs({'code': 'forbidden'});
    await programs.saveEditable();

    expect(programs.conflict('p1')?.refused, isTrue);
    expect(programs.mayChange('p1'), isFalse, reason: 'still listed as sent, but refused');

    await programs.open('sam', 'p1');
    expect(programs.mayChange('p1'), isFalse);
  });

  test('each change is counted once it landed, and one kept as a conflict is not (#568)', () async {
    final reported = ReportedAnalytics();
    programs = ClientPrograms(
      service: server,
      analytics: Analytics(service: reported),
    );
    await programs.open('sam', 'p1');
    final change = ProgramChange(id: 'c1', programId: 'p1', kind: 'edit', revision: 1, at: DateTime.utc(2026, 11, 1));

    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    await programs.saveEditable();
    // the client got there first: kept, not counted
    programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
    server.sessionRevisions['s1'] = 9;
    await programs.saveEditable();
    await programs.editFields('sam', programs.view('p1')!.program);
    await programs.revert('sam', 'p1', change);
    await programs.deleteSession('sam', 'p1', 's1');

    expect(reported.events.map((each) => each.$2['coaching_action']), [
      'session',
      'fields',
      'reverted',
      'session_deleted',
    ]);
    expect(reported.names, everyElement('client_program_edited'));
  });

  group("a session laid out as the client's device would (heart-api#439)", () {
    final now = DateTime.utc(2026, 11, 16, 12);
    num round(Exercise _, num kilograms) => (kilograms / 2.5).round() * 2.5;
    Map<String, dynamic> base(String id, num value, DateTime at) {
      return ProgramBase(id: id, programId: 'p1', exerciseId: 'squat', value: value, at: at).toMap();
    }

    setUp(() {
      server.exercises = [
        {
          'id': 'te1',
          'exercise': {'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs'},
          'sets': [
            {
              'id': 'set-1',
              'set_type': 'normal',
              'target': {
                'share': 0.7,
                'reps': {'min': 5, 'max': 5},
              },
            },
          ],
        },
      ];
      server.planning = {
        'position': {'week': 1, 'next': 's1'},
        'bases': [base('b1', 100, DateTime.utc(2026, 11)), base('b2', 110, DateTime.utc(2026, 11, 8))],
        'actions': <Object>[],
        'marks': <Object>[],
      };
    });

    Future<PlannedWorkout> planAt(DateTime at) async {
      await programs.open('muffin', 'p1');
      final session = programs.view('p1')!.sessions.single;
      return programs.plan(session, at: at, now: now, round: round);
    }

    test("from the client's bases, with the plan it was asked to be", () async {
      final (:workout, :plan) = await planAt(now);

      final set = workout.single.single;
      // 70% of the later 110 is 77, down to the 2.5 step; 100's would be 70
      expect(set.target?[TargetMeasure.weight]?.min, 75);
      expect(plan, isNotNull);
      final planned = ((plan!.plan['exercises'] as List).single as Map)['sets'] as List;
      expect((planned.single as Map)['setId'], set.id, reason: 'target beside done finds the set it became');
    });

    test('as it stood when the session was: nothing after it moves it', () async {
      final (:workout, plan: _) = await planAt(DateTime.utc(2026, 11, 5));

      expect(workout.single.single.target?[TargetMeasure.weight]?.min, 70, reason: "the base the 8th set wasn't yet");
    });

    test("a history that doesn't fold to where the server says they are plans nothing", () async {
      // as an answer from before the history was sent reads: none of it
      server.planning['position'] = {'week': 3, 'next': 's1'};

      final (:workout, :plan) = await planAt(now);

      expect(workout.single.single.target?[TargetMeasure.weight], isNull);
      expect(plan, isNull);
    });

    test('a copy whose last read failed plans nothing, rather than from what it read before', () async {
      await programs.open('muffin', 'p1');
      server.failRead = true;

      final (:workout, :plan) = await planAt(now);

      expect(programs.view('p1'), isNotNull, reason: 'the earlier read still shows');
      expect(plan, isNull);
    });

    test('a copy never read starts as written, with no plan', () {
      final session = Template.fromJson({
        'id': 's1',
        'name': 'Day A',
        'order': 0,
        'programId': 'p2',
        'exercises': server.exercises,
      });

      final (:workout, :plan) = programs.plan(session, at: now, now: now, round: round);

      expect(workout.single.single.target?[TargetMeasure.weight], isNull);
      expect(plan, isNull);
    });
  });

  test('sign-out forgets every copy', () async {
    await programs.open('sam', 'p1');
    programs.onSignOut();
    expect(programs.view('p1'), isNull);
  });
}
