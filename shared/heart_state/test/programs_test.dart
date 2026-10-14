import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The Programs notifier (#346): local first, the server's copy after, and a
/// position that is folded on request, never held.
void main() {
  const uid = 'u1';
  const bench = '019a0000-0000-7000-8000-00000000000b';

  late _Local local;
  late _Remote remote;
  late MockTemplateService templates;
  late RemoteAccess access;
  late Programs programs;
  late List<Object> errors;
  late int sessionsChanged;

  Template session(String id, {int order = 0}) => Template.fromJson({'id': id, 'name': 'Day $id', 'order': order});

  Program program({String id = 'p1', List<String> sessions = const ['s1', 's2'], DateTime? createdAt}) {
    return Program(
      id: id,
      name: 'Getting stronger',
      perWeek: 3,
      sessions: sessions,
      createdAt: createdAt ?? DateTime.utc(2026, 10, 1),
    );
  }

  Programs relaunch() {
    return Programs(
      service: local,
      remoteService: remote,
      templates: templates,
      remote: access,
      onError: (error, {stacktrace}) => errors.add(error),
    )..userId = uid;
  }

  setUp(() {
    local = _Local();
    remote = _Remote();
    templates = MockTemplateService();
    when(templates.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    access = RemoteAccess(hasToken: () => true)..account = true;
    errors = [];
    sessionsChanged = 0;
    programs = Programs(
      service: local,
      remoteService: remote,
      templates: templates,
      remote: access,
      onError: (error, {stacktrace}) => errors.add(error),
      onSessionsChanged: () async => sessionsChanged++,
    )..userId = uid;
  });

  group('init', () {
    test('reads the mirror, then the server replaces it, history and all', () async {
      local.programs[uid] = [program(id: 'gone')];
      remote.programs = [program()];
      remote.actions['p1'] = [ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 2))];
      remote.bases['p1'] = [
        ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench, value: 100, at: DateTime.utc(2026, 10, 1)),
      ];

      await programs.init();

      expect(programs.all.map((each) => each.id), ['p1']);
      expect(local.programs[uid]!.map((each) => each.id), ['p1']);
      expect(programs.actionsOf('p1').single.kind, ProgramActionKind.pause);
      expect(programs.currentBasesOf('p1')[bench]?.value, 100);
      expect(local.actions.map((each) => each.id), ['a1']);
      expect(programs.hasLoaded, isTrue);
    });

    test('with the remote leg closed, the mirror is the whole story', () async {
      access.account = false;
      local.programs[uid] = [program()];

      await programs.init();

      expect(programs.all.map((each) => each.id), ['p1']);
      expect(remote.calls, isEmpty);
    });

    test('a server that fails costs its step, not the mirror', () async {
      local.programs[uid] = [program()];
      remote.failing = true;

      await programs.init();

      expect(programs.all.map((each) => each.id), ['p1']);
      expect(errors, isNotEmpty);
    });

    test('a program only the server had has its position', () async {
      remote.programs = [program()];
      local.marks['p1'] = [ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 6), isWorkout: true)];

      await programs.init();

      expect(programs.position(programs.lookup('p1')!, now: DateTime.utc(2026, 10, 7)).done, {'s1'});
    });

    test('an archived program\'s history is read once', () async {
      remote.programs = [
        Program.fromJson({...program().toMap(), 'archived': true}),
      ];
      remote.actions['p1'] = [ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 2))];

      await programs.init();
      await relaunch().init();

      expect(remote.calls.where((each) => each.startsWith('getProgramActions')), hasLength(1));
    });
  });

  group('what the server did not confirm', () {
    test('a program it never got is kept, and sent at the next launch', () async {
      when(templates.getTemplates(uid)).thenAnswer((_) async => []);
      remote.failing = true;
      final created = await programs.create(Program(name: 'Upper / Lower'), sessions: [session('s1')]);
      expect(local.owed.map((each) => (each.row, each.change)), [
        (ProgramRow.program, ProgramChange.created),
        (ProgramRow.session, ProgramChange.edited),
      ]);

      remote.failing = false;
      final next = relaunch();
      await next.init();

      expect(remote.calls, contains(startsWith('replayProgram ${created.id}')));
      expect(next.lookup(created.id!), isNotNull);
      expect(local.programs[uid]!.map((each) => each.id), [created.id]);
      expect(local.owed, isEmpty);
    });

    test('a deletion it never got stays deleted', () async {
      local.programs[uid] = [program()];
      remote.programs = [program()];
      await programs.init();
      remote.failing = true;
      await programs.delete(programs.lookup('p1')!, keepTemplates: false);

      remote.failing = false;
      final next = relaunch();
      await next.init();

      expect(remote.calls, contains('deleteProgram p1 false'));
      expect(next.all, isEmpty);
      expect(local.owed, isEmpty);
    });

    test('a step it never got survives its read, and goes up', () async {
      local.programs[uid] = [program()];
      remote.programs = [program()];
      await programs.init();
      remote.failing = true;
      final pause = await programs.act(programs.lookup('p1')!, .pause);

      remote.failing = false;
      final next = relaunch();
      await next.init();

      expect(remote.calls, contains('replayProgramAction ${pause.id}'));
      expect(next.actionsOf('p1').map((each) => each.id), [pause.id]);
      expect(local.owed, isEmpty);
    });

    test('a step undone before it went up is owed nothing', () async {
      local.programs[uid] = [program()];
      remote.programs = [program()];
      await programs.init();
      remote.failing = true;
      final pause = await programs.act(programs.lookup('p1')!, .pause);
      await programs.undo(pause);

      expect(local.owed, isEmpty);
    });

    test('a refusal is not asked again', () async {
      local.programs[uid] = [program()];
      local.owed.add((row: .program, id: 'p1', programId: 'p1', change: .edited));
      remote.refusing = 'invalid_rule';

      await programs.init();

      expect(local.owed, isEmpty);
    });
  });

  group('create', () {
    test('files its sessions under it, keeps the order, and sends it whole', () async {
      final created = await programs.create(
        Program(name: 'Upper / Lower', perWeek: 4),
        sessions: [session('s1'), session('s2', order: 1)],
      );

      final [stored] = verify(templates.storeTemplates(captureAny, userId: uid)).captured;
      expect((stored as List<Template>).map((each) => each.programId), [created.id, created.id]);
      expect(created.sessions, ['s1', 's2']);
      expect(created.createdAt, isNotNull);
      expect(local.programs[uid]!.single.id, created.id);
      expect(remote.calls, ['replayProgram ${created.id} s1,s2']);
      expect(sessionsChanged, 1);
    });

    test('a template the account already holds joins through its own filing', () async {
      // the server made the program and filed none of them: they were not new
      remote.programAnswer = (program) => Program.fromJson({...program.toMap(), 'sessions': <String>[]});

      final created = await programs.create(
        Program(name: 'Split'),
        sessions: [session('s1'), session('s2', order: 1)],
      );

      expect(remote.calls.skip(1), ['setTemplateProgram s1 ${created.id}', 'setTemplateProgram s2 ${created.id}']);
      expect(created.sessions, ['s1', 's2']);
      expect(local.owed, isEmpty);
    });

    test('a filing that fails is owed, and the next launch files it', () async {
      when(templates.getTemplates(uid)).thenAnswer((_) async => [session('s1'), session('s2', order: 1)]);
      remote.programAnswer = (program) => Program.fromJson({...program.toMap(), 'sessions': <String>[]});
      remote.failingFilings.add('s2');

      final created = await programs.create(
        Program(name: 'Split'),
        sessions: [session('s1'), session('s2', order: 1)],
      );
      expect(local.owed.map((each) => (each.row, each.id)), [(ProgramRow.session, 's2')]);

      remote
        ..failingFilings.clear()
        ..calls.clear();
      await relaunch().init();

      expect(remote.calls, contains('setTemplateProgram s2 ${created.id}'));
      expect(remote.calls, isNot(contains(startsWith('replayProgram'))));
      expect(local.owed, isEmpty);
    });

    test('offline it stays local, under its own id', () async {
      access.account = false;

      final created = await programs.create(Program(name: 'Walk and move'), sessions: [session('s1')]);

      expect(created.id, isNotNull);
      expect(programs.lookup(created.id!), isNotNull);
      expect(remote.calls, isEmpty);
    });
  });

  group('position', () {
    test('a cycle done moves the week; a repeat runs it again', () async {
      local.programs[uid] = [program()];
      local.marks['p1'] = [
        ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 6, 8), isWorkout: true),
        ProgramMark(templateId: 's2', at: DateTime.utc(2026, 10, 8, 8), isWorkout: true),
      ];
      access.account = false;
      await programs.init();
      final now = DateTime.utc(2026, 10, 9);

      final p1 = programs.lookup('p1')!;
      expect(programs.position(p1, now: now).week, 2);
      expect(programs.position(p1, now: now).thisWeek, 2);

      await programs.act(p1, .repeat, at: DateTime.utc(2026, 10, 9, 9));

      final again = programs.position(p1, now: now);
      expect((again.week, again.next), (1, 's1'));
    });

    test('the weekly count follows the first day of the week it is given', () async {
      local.programs[uid] = [program()];
      // a Sunday
      local.marks['p1'] = [ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 11, 8), isWorkout: true)];
      access.account = false;
      await programs.init();
      final monday = DateTime.utc(2026, 10, 12, 12);
      final p1 = programs.lookup('p1')!;

      expect(programs.position(p1, now: monday).thisWeek, 0);
      expect(programs.position(p1, now: monday, firstWeekday: DateTime.sunday).thisWeek, 1);
    });

    test('refreshing reads the marks again', () async {
      local.programs[uid] = [program()];
      access.account = false;
      await programs.init();
      local.marks['p1'] = [ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 6), isWorkout: true)];

      await programs.refreshMarks();

      expect(programs.position(programs.lookup('p1')!, now: DateTime.utc(2026, 10, 7)).done, {'s1'});
    });
  });

  group('steering and bases', () {
    setUp(() async {
      local.programs[uid] = [program()];
      access.account = false;
      await programs.init();
      access.account = true;
    });

    test('an action lands locally and on the server; undoing it takes its bases', () async {
      final p1 = programs.lookup('p1')!;
      final replay = await programs.act(p1, .replay, week: 1);
      await programs.setBase(p1, exerciseId: bench, value: 90, actionId: replay.id);

      await programs.undo(replay);

      expect(programs.actionsOf('p1'), isEmpty);
      expect(programs.basesOf('p1'), isEmpty);
      expect(local.actions, isEmpty);
      expect(remote.calls, contains('deleteProgramAction p1 ${replay.id}'));
    });

    test('only a replay names a week', () async {
      final pause = await programs.act(programs.lookup('p1')!, .pause, week: 3);

      expect(pause.week, isNull);
    });

    test('a bump another device already wrote comes back as that one, and this copy goes', () async {
      remote.baseAnswer = (base) => ProgramBase(
        id: 'first',
        programId: base.programId,
        exerciseId: base.exerciseId,
        value: base.value,
        workoutId: base.workoutId,
        at: base.at,
      );

      final saved = await programs.setBase(programs.lookup('p1')!, exerciseId: bench, value: 102.5, workoutId: 'w1');

      expect(saved.id, 'first');
      expect(programs.basesOf('p1').map((each) => each.id), ['first']);
      expect(local.bases.map((each) => each.id), ['first']);
    });

    test('deleting a program can keep its sessions', () async {
      await programs.delete(programs.lookup('p1')!, keepTemplates: true);

      expect(programs.all, isEmpty);
      expect(local.deleted, [('p1', true)]);
      expect(remote.calls, contains('deleteProgram p1 true'));
      expect(sessionsChanged, 1);
    });

    test('archiving keeps the program and its history', () async {
      final archived = await programs.archive(programs.lookup('p1')!);

      expect(archived.archived, isTrue);
      expect(programs.following, isEmpty);
      expect(programs.all, hasLength(1));
    });
  });

  test('signing out forgets every program', () async {
    local.programs[uid] = [program()];
    await programs.init();

    programs.onSignOut();

    expect(programs.all, isEmpty);
    expect((programs.userId, programs.hasLoaded), (null, false));
  });
}

class _Local implements LocalProgramService {
  final programs = <String, List<Program>>{};
  final marks = <String, List<ProgramMark>>{};
  final actions = <ProgramAction>[];
  final bases = <ProgramBase>[];
  final deleted = <(String, bool)>[];

  @override
  Future<List<Program>> getPrograms(String userId) async => [...?programs[userId]];

  @override
  Future<void> storePrograms(Iterable<Program> programs, String userId) async {
    this.programs[userId] = [...programs];
  }

  @override
  Future<void> storeProgram(Program program, String userId) async {
    final held = programs.putIfAbsent(userId, () => [])..removeWhere((each) => each.id == program.id);
    held.add(program);
  }

  @override
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) async {
    deleted.add((programId, keepTemplates));
    for (final held in programs.values) {
      held.removeWhere((each) => each.id == programId);
    }
  }

  @override
  Future<List<ProgramMark>> getProgramMarks(String userId, String programId) async => [...?marks[programId]];

  @override
  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId}) async {
    return [
      for (final action in actions)
        if (programId == null || action.programId == programId) action,
    ];
  }

  @override
  Future<void> storeProgramActions(String programId, Iterable<ProgramAction> actions) async {
    this.actions
      ..removeWhere((each) => each.programId == programId)
      ..addAll(actions);
  }

  @override
  Future<void> storeProgramAction(ProgramAction action) async {
    actions
      ..removeWhere((each) => each.id == action.id)
      ..add(action);
  }

  @override
  Future<void> deleteProgramAction(String actionId) async {
    actions.removeWhere((each) => each.id == actionId);
    bases.removeWhere((each) => each.actionId == actionId);
  }

  @override
  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId}) async {
    return [
      for (final base in bases)
        if (programId == null || base.programId == programId) base,
    ];
  }

  @override
  Future<void> storeProgramBases(String programId, Iterable<ProgramBase> bases) async {
    this.bases
      ..removeWhere((each) => each.programId == programId)
      ..addAll(bases);
  }

  @override
  Future<void> storeProgramBase(ProgramBase base) async {
    bases
      ..removeWhere((each) => each.id == base.id)
      ..add(base);
  }

  @override
  Future<void> deleteProgramBase(String baseId) async => bases.removeWhere((each) => each.id == baseId);

  final owed = <ProgramOwed>[];

  @override
  Future<List<ProgramOwed>> getProgramsOwed(String userId) async => [...owed];

  @override
  Future<void> owePrograms(String userId, ProgramOwed owed) async {
    this.owed
      ..removeWhere((each) => (each.row, each.id) == (owed.row, owed.id))
      ..add(owed);
  }

  @override
  Future<void> settleProgram(ProgramRow row, String id) async {
    owed.removeWhere((each) => (each.row, each.id) == (row, id));
  }
}

class _Remote implements RemoteProgramService {
  final calls = <String>[];
  var programs = <Program>[];
  final actions = <String, List<ProgramAction>>{};
  final bases = <String, List<ProgramBase>>{};
  bool failing = false;

  /// A code every call is refused with.
  String? refusing;
  ProgramBase Function(ProgramBase)? baseAnswer;

  /// What the server's create answers with; the program as sent by default.
  Program Function(Program)? programAnswer;

  /// Templates whose filing under a program fails.
  final failingFilings = <String>{};

  void _call(String call) {
    calls.add(call);
    if (failing) throw {'error': 'unavailable'};
    if (refusing case final String code) throw {'code': code};
  }

  @override
  Future<List<Program>> getPrograms() async {
    _call('getPrograms');
    return programs;
  }

  @override
  Future<Replayed<Program>> replayProgram(Program program, {required Iterable<Template> sessions}) async {
    _call('replayProgram ${program.id} ${sessions.map((each) => each.id).join(',')}');
    final row = programAnswer?.call(program) ?? program;
    programs = [...programs.where((each) => each.id != program.id), row];
    return (row: row, created: true);
  }

  @override
  Future<Program> editProgram(Program program) async {
    _call('editProgram ${program.id}');
    return program;
  }

  @override
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) async {
    _call('deleteProgram $programId $keepTemplates');
    programs = [...programs.where((each) => each.id != programId)];
  }

  @override
  Future<List<ProgramAction>> getProgramActions(String programId) async {
    _call('getProgramActions $programId');
    return [...?actions[programId]];
  }

  @override
  Future<Replayed<ProgramAction>> replayProgramAction(ProgramAction action) async {
    _call('replayProgramAction ${action.id}');
    actions.putIfAbsent(action.programId!, () => []).add(action);
    return (row: action, created: true);
  }

  @override
  Future<void> deleteProgramAction(String programId, String actionId) async {
    _call('deleteProgramAction $programId $actionId');
  }

  @override
  Future<List<ProgramBase>> getProgramBases(String programId) async {
    _call('getProgramBases $programId');
    return [...?bases[programId]];
  }

  @override
  Future<Replayed<ProgramBase>> replayProgramBase(ProgramBase base) async {
    _call('replayProgramBase ${base.id}');
    return (row: baseAnswer?.call(base) ?? base, created: baseAnswer == null);
  }

  @override
  Future<void> deleteProgramBase(String programId, String baseId) async {
    _call('deleteProgramBase $programId $baseId');
  }

  @override
  Future<Template> setTemplateProgram(Template template, {required String? programId}) async {
    _call('setTemplateProgram ${template.id} $programId');
    if (failingFilings.contains(template.id)) throw {'error': 'unavailable'};
    return Template.fromJson({...template.toMap(), 'programId': programId});
  }
}
