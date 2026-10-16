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

      expect(
        programs.position(programs.lookup('p1')!, now: DateTime.utc(2026, 10, 7), firstWeekday: DateTime.monday).done,
        {'s1'},
      );
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

    test('each session joins when this device filed it, not when the server hears of it', () async {
      final before = DateTime.timestamp();
      await programs.create(Program(name: 'Split'), sessions: [session('s1'), session('s2', order: 1)]);

      final [stored] = verify(templates.storeTemplates(captureAny, userId: uid)).captured;
      for (final Template(:joined) in stored as List<Template>) {
        expect(joined, isNotNull);
        expect(joined!.isBefore(before), isFalse);
      }
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
      expect(programs.position(p1, now: now, firstWeekday: DateTime.monday).week, 2);
      expect(programs.position(p1, now: now, firstWeekday: DateTime.monday).thisWeek, 2);

      await programs.act(p1, .repeat, at: DateTime.utc(2026, 10, 9, 9));

      final again = programs.position(p1, now: now, firstWeekday: DateTime.monday);
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

      expect(programs.position(p1, now: monday, firstWeekday: DateTime.monday).thisWeek, 0);
      expect(programs.position(p1, now: monday, firstWeekday: DateTime.sunday).thisWeek, 1);
    });

    test('refreshing reads the marks again', () async {
      local.programs[uid] = [program()];
      access.account = false;
      await programs.init();
      local.marks['p1'] = [ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 6), isWorkout: true)];

      await programs.refreshMarks();

      expect(
        programs.position(programs.lookup('p1')!, now: DateTime.utc(2026, 10, 7), firstWeekday: DateTime.monday).done,
        {'s1'},
      );
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

    test('a lighter cycle is a step like the others, and the position reads it', () async {
      final p1 = programs.lookup('p1')!;
      final lighter = await programs.act(p1, .lighter);

      expect(remote.calls, contains('replayProgramAction ${lighter.id}'));
      expect(programs.position(p1, now: DateTime.timestamp(), firstWeekday: DateTime.monday).lighter, isTrue);
    });

    test("a ladder's advance names what it moved and why, and is owed like any step", () async {
      remote.failing = true;
      final advance = await programs.advance(programs.lookup('p1')!, from: bench, to: 'harder', workoutId: 'w1');

      expect(
        (advance.kind, advance.from, advance.to, advance.workoutId),
        (ProgramActionKind.advance, bench, 'harder', 'w1'),
      );
      expect(local.actions.single.id, advance.id);
      expect(local.owed.map((each) => (each.row, each.id)), [(ProgramRow.action, advance.id)]);
    });

    test('a base can belong to one occurrence of a lift', () async {
      final base = await programs.setBase(programs.lookup('p1')!, exerciseId: bench, slot: 'te2', value: 80);

      expect(base.slot, 'te2');
      expect(programs.currentBasesOf('p1')['te2']?.value, 80);
    });

    test('a workout gone from the mirror takes its advance from the page too', () async {
      final advance = await programs.advance(programs.lookup('p1')!, from: bench, to: 'harder', workoutId: 'w1');
      // what deleteWorkout does in the mirror
      local.actions.removeWhere((each) => each.workoutId == 'w1');

      await programs.refreshMarks();

      expect(programs.actionsOf('p1').map((each) => each.id), isNot(contains(advance.id)));
    });

    test('a re-read takes what a history move re-keyed in the mirror, and asks the server nothing', () async {
      local.programs[uid] = [
        Program.fromJson({
          ...program().toMap(),
          'rules': {
            'moved': {'kind': 'addWeight', 'step': 2.5},
          },
        }),
      ];
      remote.calls.clear();

      await programs.reread();

      expect(programs.lookup('p1')!.rules.keys, ['moved']);
      expect(remote.calls, isEmpty);
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

  group('growth (#350)', () {
    const squat = {'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs'};
    const wall = {'id': 'wall', 'name': 'Wall push-up', 'category': 'Reps Only', 'target': 'Chest'};
    var ids = 0;

    // a set as logged: ticked unless said otherwise, against [target]
    Map logged({int? reps, num? weight, Map? target, bool done = true}) => {
      'id': 'set-${ids++}',
      'set_type': 'normal',
      'completed': done,
      'reps': ?reps,
      'weight': ?weight,
      'target': ?target,
    };

    const fives = {
      'reps': {'min': 5, 'max': 5},
    };

    Workout done(
      String id, {
      required DateTime start,
      String templateId = 's1',
      List<Map> exercises = const [],
    }) {
      return Workout.fromJson({
        'id': id,
        'start': start.toIso8601String(),
        'end': start.add(const Duration(hours: 1)).toIso8601String(),
        'templateId': templateId,
        'programId': 'p1',
        'exercises': exercises,
      });
    }

    Map squats(List<int> reps, {num weight = 100, String id = 'we'}) => {
      'id': '$id-${ids++}',
      'exercise': squat,
      'sets': [for (final each in reps) logged(reps: each, weight: weight, target: fives)],
    };

    Future<void> follow(Program program, {List<ProgramBase> bases = const []}) async {
      local.programs[uid] = [program];
      local.bases.addAll(bases);
      access.account = false;
      await programs.init();
      access.account = true;
    }

    ProgramBase base(num value, {String exerciseId = 'squat', String? slot, DateTime? at}) => ProgramBase(
      id: 'b-$value-${slot ?? exerciseId}',
      programId: 'p1',
      exerciseId: exerciseId,
      slot: slot,
      value: value,
      at: at ?? DateTime.utc(2026, 10, 1),
    );

    Program growing(Map<String, GrowthRule> rules, {Map<String, ProgramTest> tests = const {}}) {
      return Program(
        id: 'p1',
        name: 'Getting stronger',
        perWeek: 3,
        sessions: const ['s1'],
        rules: rules,
        tests: tests,
        createdAt: DateTime.utc(2026, 10, 1),
      );
    }

    const tiers = Stages(
      stages: [Stage(sets: 5, reps: 3, amrap: true), Stage(sets: 6, reps: 2, amrap: true), Stage(sets: 10, reps: 1)],
      step: 2.5,
      miss: MissRule(after: 1, cut: 0.15),
    );
    const threes = {
      'reps': {'min': 3, 'max': 3},
    };

    test('a stages rule: a short session moves it on, and Keep takes the stage back', () async {
      await follow(growing({'squat': tiers}), bases: [base(100)]);
      final workout = done(
        'w1',
        start: DateTime.utc(2026, 10, 5),
        exercises: [
          {
            'id': 'we-${ids++}',
            'exercise': squat,
            'sets': [
              for (final reps in [3, 3, 2]) logged(reps: reps, weight: 100, target: threes),
            ],
          },
        ],
      );

      final [move] = await programs.grow(workout);

      expect(move.step, const ToStage(1));
      expect((move.action?.kind, move.action?.exercise, move.action?.stage), (ProgramActionKind.stage, 'squat', 1));
      expect(move.base, isNull, reason: 'a stage move keeps the weight');
      expect(programs.currentStagesOf('p1'), {'squat': 1});

      await programs.keep(move);
      expect(programs.currentStagesOf('p1'), isEmpty);
      expect(programs.currentBasesOf('p1')['squat']?.value, 100);
    });

    test("a stages rule's last stage starts over from the first, lighter by the cut", () async {
      await follow(growing({'squat': tiers}), bases: [base(100)]);
      await programs.moveStage(
        programs.lookup('p1')!,
        exerciseId: 'squat',
        stage: 2,
        workoutId: 'w0',
        at: DateTime.utc(2026, 10, 3),
      );

      final [move] = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            {
              'id': 'we-${ids++}',
              'exercise': squat,
              'sets': [
                logged(
                  reps: 0,
                  weight: 100,
                  target: const {
                    'reps': {'min': 1, 'max': 1},
                  },
                ),
              ],
            },
          ],
        ),
      );

      // 85, on the step
      expect(move.step, const ToStage(0, base: 85));
      expect((move.base?.value, move.action?.stage), (85, 0));
      expect(programs.currentStagesOf('p1'), {'squat': 0});
      expect(programs.currentBasesOf('p1')['squat']?.value, 85);

      await programs.keep(move);
      expect(programs.currentStagesOf('p1'), {'squat': 2});
      expect(programs.currentBasesOf('p1')['squat']?.value, 100);
    });

    test('a session that makes every set grows the base, caused by the workout', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);
      final workout = done(
        'w1',
        start: DateTime.utc(2026, 10, 5),
        exercises: [
          squats([5, 5]),
        ],
      );

      final [move] = await programs.grow(workout);

      expect((move.step, move.before), (const Grow(102.5), 100));
      expect((move.base?.value, move.base?.workoutId), (102.5, 'w1'));
      expect(programs.currentBasesOf('p1')['squat']?.value, 102.5);
    });

    test('a third miss in a row cuts; the streak is read from the sessions since the base', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);
      local.workouts['p1'] = [
        // before the base: judged against another, so it counts for nothing
        done(
          'w0',
          start: DateTime.utc(2026, 9, 28),
          exercises: [
            squats([3, 3]),
          ],
        ),
        done(
          'w1',
          start: DateTime.utc(2026, 10, 2),
          exercises: [
            squats([5, 3]),
          ],
        ),
        done(
          'w2',
          start: DateTime.utc(2026, 10, 4),
          exercises: [
            squats([5, 4]),
          ],
        ),
      ];

      final [move] = await programs.grow(
        done(
          'w3',
          start: DateTime.utc(2026, 10, 6),
          exercises: [
            squats([5, 2]),
          ],
        ),
      );

      expect(move.step, const Cut(90));
      expect(programs.currentBasesOf('p1')['squat']?.value, 90);
    });

    test('a miss short of a cut is said, and writes nothing', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);

      final [move] = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            squats([5, 3]),
          ],
        ),
      );

      expect((move.step, move.cutAfter, move.base), (const Missed(1), 3, null));
      expect(programs.basesOf('p1'), hasLength(1));
    });

    test('in a lighter cycle nothing moves', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);
      await programs.act(programs.lookup('p1')!, .lighter, at: DateTime.utc(2026, 10, 3));

      final moves = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            squats([5, 5]),
          ],
        ),
      );

      expect(moves, isEmpty);
    });

    test('once per workout, and never for one something was already written for', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);
      final workout = done(
        'w1',
        start: DateTime.utc(2026, 10, 5),
        exercises: [
          squats([5, 5]),
        ],
      );

      await programs.grow(workout);
      await programs.grow(workout);
      expect(programs.basesOf('p1'), hasLength(2));

      // the same finish, replayed on a relaunch
      final again = relaunch();
      local.programs[uid] = [programs.lookup('p1')!];
      await again.init();
      expect(await again.grow(workout), isEmpty);
      expect(local.bases, hasLength(2));
    });

    test("a ladder climbs: the advance, the rule's key and the sessions move; Keep takes all three back", () async {
      final swaps = <(String, String, String)>[];
      programs = Programs(
        service: local,
        remoteService: remote,
        templates: templates,
        remote: access,
        onError: (error, {stacktrace}) => errors.add(error),
        onAdvance: (sessions, {required from, required to}) async => swaps.add((sessions.join(','), from, to)),
      )..userId = uid;
      await follow(
        growing({
          'wall': const Ladder(rungs: ['wall', 'incline'], top: 12, bottom: 8),
        }),
      );

      final moves = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            {
              'id': 'we1',
              'exercise': wall,
              'sets': [logged(reps: 12), logged(reps: 12)],
            },
          ],
        ),
      );

      expect(errors, isEmpty);
      final [move] = moves;
      expect(move.step, const Advance('incline'));
      expect((move.action?.from, move.action?.to, move.action?.workoutId), ('wall', 'incline', 'w1'));
      expect(programs.lookup('p1')!.rules.keys, ['incline']);
      expect(swaps.single, ('s1', 'wall', 'incline'));

      await programs.keep(move);

      expect(programs.actionsOf('p1'), isEmpty);
      expect(programs.lookup('p1')!.rules.keys, ['wall']);
      expect(swaps.last, ('s1', 'incline', 'wall'));
    });

    test('a replace in the program moves the rule and the sessions, and leaves the bases (#354)', () async {
      final swaps = <(String, String, String)>[];
      programs = Programs(
        service: local,
        remoteService: remote,
        templates: templates,
        remote: access,
        onError: (error, {stacktrace}) => errors.add(error),
        onAdvance: (sessions, {required from, required to}) async => swaps.add((sessions.join(','), from, to)),
      )..userId = uid;
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);

      await programs.replaceExercise(programs.lookup('p1')!, from: 'squat', to: 'front-squat');

      expect(errors, isEmpty);
      expect(programs.lookup('p1')!.rules.keys, ['front-squat']);
      expect(swaps.single, ('s1', 'squat', 'front-squat'));
      expect(programs.currentBasesOf('p1').keys, ['squat']);
    });

    test('a test session sets training maxes, judged against no rule, and Keep takes one back', () async {
      await follow(growing({'squat': const AddWeight(step: 5)}, tests: {'s1': const ProgramTest()}));

      // 100 × 5: an estimated 112.5, 90% of it 101.25, down to 100 on 5s
      final [move] = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            squats([5]),
          ],
        ),
      );

      expect((move.isTest, move.step), (true, const Grow(100)));
      expect(programs.currentBasesOf('p1')['squat']?.value, 100);

      await programs.keep(move);

      expect(programs.basesOf('p1'), isEmpty);
    });

    test('a lift the program keeps two bases for grows each by its own occurrence', () async {
      await follow(
        growing({'squat': const AddWeight(step: 2.5)}),
        bases: [
          base(100, slot: 'heavy'),
          base(70, slot: 'light'),
        ],
      );
      final session = Template.fromJson({
        'id': 's1',
        'name': 'Squat twice',
        'order': 0,
        'programId': 'p1',
        'exercises': [
          {
            'id': 'heavy',
            'exercise': squat,
            'sets': [logged(done: false, target: fives)],
          },
          {
            'id': 'light',
            'exercise': squat,
            'sets': [logged(done: false, target: fives)],
          },
        ],
      });

      final moves = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            squats([5, 5]),
            squats([5, 3], weight: 70),
          ],
        ),
        session: session,
      );

      expect(moves.map((move) => (move.slot, move.step)), [('heavy', const Grow(102.5)), ('light', const Missed(1))]);
      expect(programs.currentBasesOf('p1')['heavy']?.value, 102.5);
      expect(programs.currentBasesOf('p1')['light']?.value, 70);
    });

    test('a skipped first occurrence leaves its slot alone: the second grows its own base', () async {
      await follow(
        growing({'squat': const AddWeight(step: 2.5)}),
        bases: [
          base(100, slot: 'heavy'),
          base(70, slot: 'light'),
        ],
      );
      final session = Template.fromJson({
        'id': 's1',
        'name': 'Squat twice',
        'order': 0,
        'programId': 'p1',
        'exercises': [
          {
            'id': 'heavy',
            'exercise': squat,
            'sets': [logged(done: false, target: fives)],
          },
          {
            'id': 'light',
            'exercise': squat,
            'sets': [logged(done: false, target: fives)],
          },
        ],
      });
      final workout = done(
        'w1',
        start: DateTime.utc(2026, 10, 5),
        exercises: [
          {
            'id': 'we-heavy',
            'exercise': squat,
            'sets': [logged(reps: 5, weight: 100, target: fives, done: false)],
          },
          squats([5, 5], weight: 70),
        ],
      );

      // read before the finish, which drops the occurrence nobody ticked
      final slots = slotsOf(workout, session);
      workout.removeEmptySets();
      final moves = await programs.grow(workout, session: session, slots: slots);

      expect(moves.map((move) => (move.slot, move.step)), [('light', const Grow(72.5))]);
      expect(programs.currentBasesOf('p1')['heavy']?.value, 100);
      expect(programs.currentBasesOf('p1')['light']?.value, 72.5);
    });

    test('a climb onto a lift with a rule of its own keeps both rules where they are', () async {
      programs = Programs(
        service: local,
        remoteService: remote,
        templates: templates,
        remote: access,
        onError: (error, {stacktrace}) => errors.add(error),
        onAdvance: (sessions, {required from, required to}) async {},
      )..userId = uid;
      await follow(
        growing({
          'wall': const Ladder(rungs: ['wall', 'incline'], top: 12, bottom: 8),
          'incline': const AddWeight(step: 2.5),
        }),
      );

      final [move] = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            {
              'id': 'we1',
              'exercise': wall,
              'sets': [logged(reps: 12), logged(reps: 12)],
            },
          ],
        ),
      );

      expect(move.step, const Advance('incline'));
      final rules = programs.lookup('p1')!.rules;
      expect(rules.keys, unorderedEquals(['wall', 'incline']));
      expect(rules['incline'], const AddWeight(step: 2.5));

      await programs.keep(move);

      expect(programs.lookup('p1')!.rules['incline'], const AddWeight(step: 2.5));
      expect(programs.lookup('p1')!.rules['wall'], isA<Ladder>());
    });

    test('a move that fails to write leaves the others reported, Keep and all', () async {
      programs = Programs(
        service: local,
        remoteService: remote,
        templates: templates,
        remote: access,
        onError: (error, {stacktrace}) => errors.add(error),
        onAdvance: (sessions, {required from, required to}) async => throw StateError('no sessions'),
      )..userId = uid;
      await follow(
        growing({
          'wall': const Ladder(rungs: ['wall', 'incline'], top: 12, bottom: 8),
          'squat': const AddWeight(step: 2.5),
        }),
        bases: [base(100)],
      );

      final moves = await programs.grow(
        done(
          'w1',
          start: DateTime.utc(2026, 10, 5),
          exercises: [
            {
              'id': 'we1',
              'exercise': wall,
              'sets': [logged(reps: 12), logged(reps: 12)],
            },
            squats([5, 5]),
          ],
        ),
      );

      expect(errors, [isA<StateError>()]);
      final [move] = moves;
      expect((move.exerciseId, move.base?.value), ('squat', 102.5));
    });

    test('a growth that could not run is run again when asked again', () async {
      await follow(growing({'squat': const AddWeight(step: 2.5)}), bases: [base(100)]);
      final workout = done(
        'w1',
        start: DateTime.utc(2026, 10, 5),
        exercises: [
          squats([5, 5]),
        ],
      );

      local.marksFail = StateError('mirror locked');
      expect(await programs.grow(workout), isEmpty);
      local.marksFail = null;

      final [move] = await programs.grow(workout);
      expect(move.base?.value, 102.5);
    });
  });

  group('not today (#312)', () {
    final now = DateTime.utc(2026, 10, 7, 12);

    Future<Program> following() async {
      local.programs[uid] = [program()];
      remote.programs = [program()];
      await programs.init();
      return programs.lookup('p1')!;
    }

    test('a skip sets the session aside: done in the cycle, the next one up, and sent', () async {
      final followed = await following();

      final skip = await programs.skip(followed, session: 's1', at: DateTime.utc(2026, 10, 7, 8));

      final position = programs.position(followed, now: now, firstWeekday: DateTime.monday);
      expect(position.done, {'s1'});
      expect((position.next, position.thisWeek), ('s2', 0));
      expect(programs.skipsOf('p1').map((each) => each.id), [skip.id]);
      expect(local.skips.single.templateId, 's1');
      expect(remote.calls, contains('replaySkip ${skip.id}'));
      expect(local.owed, isEmpty);
      expect(programs.skippedIn(followed, position), {'s1'});
      expect(programs.skips.map((each) => each.id), [skip.id]);
    });

    test('a session done after a skip of it is done, not skipped', () async {
      final followed = await following();
      await programs.skip(followed, session: 's1', at: DateTime.utc(2026, 10, 6, 8));
      local.marks['p1'] = [ProgramMark(templateId: 's1', at: DateTime.utc(2026, 10, 7, 8), isWorkout: true)];
      await programs.refreshMarks();

      final position = programs.position(followed, now: now, firstWeekday: DateTime.monday);

      expect(position.done, {'s1'});
      expect(programs.skippedIn(followed, position), isEmpty);
    });

    test('a skip the server never heard of is owed, and the next launch sends it', () async {
      final followed = await following();
      remote.failing = true;

      final skip = await programs.skip(followed, session: 's1');
      expect(local.owed.map((each) => (each.row, each.id)), [(ProgramRow.skip, skip.id)]);

      remote.failing = false;
      final next = relaunch();
      await next.init();

      expect(remote.skips.map((each) => each.id), [skip.id]);
      expect(local.owed, isEmpty);
      expect(next.position(next.lookup('p1')!, now: now, firstWeekday: DateTime.monday).done, {'s1'});
    });

    test('taking it back makes the session due again, there and here', () async {
      final followed = await following();
      final skip = await programs.skip(followed, session: 's1');

      await programs.unskip(skip);

      expect(programs.position(followed, now: now, firstWeekday: DateTime.monday).next, 's1');
      expect(local.skips, isEmpty);
      expect(programs.skipsOf('p1'), isEmpty);
      expect(remote.calls, contains('deleteSkip ${skip.id}'));
    });

    test("the server's skips replace the mirror's, but for one still owed", () async {
      local.skips.add(TrainingSkip(id: 'gone', at: DateTime.utc(2026, 10, 2), templateId: 's2', programId: 'p1'));
      remote.skips = [TrainingSkip(id: 'theirs', at: DateTime.utc(2026, 10, 3), templateId: 's2', programId: 'p1')];
      final followed = await following();
      remote.failing = true;
      final mine = await programs.skip(followed, session: 's1');

      remote.failing = false;
      final next = relaunch();
      remote.failing = true;
      await next.init();
      expect(local.skips.map((each) => each.id), containsAll(['theirs', mine.id]));
      expect(local.skips.map((each) => each.id), isNot(contains('gone')));
    });

    test('deleting the program leaves a skip it never sent still owed', () async {
      final followed = await following();
      remote.failing = true;
      final skip = await programs.skip(followed, session: 's1');

      await programs.delete(followed, keepTemplates: true);

      expect(local.owed.map((each) => (each.row, each.id)), contains((ProgramRow.skip, skip.id)));
    });

    test('a skip outlives its deleted program: History still lists it, program-less', () async {
      final followed = await following();
      final skip = await programs.skip(followed, session: 's1');

      await programs.delete(followed, keepTemplates: true);

      expect(programs.skipsOf('p1'), isEmpty);
      final [kept] = programs.skips;
      expect((kept.id, kept.templateId, kept.programId), (skip.id, 's1', null));
    });

    test("a program-less skip, the mirror's and the server's, is listed", () async {
      final orphan = TrainingSkip(id: 'orphan', at: DateTime.utc(2026, 10, 2), templateId: 's2');
      local.skips.add(orphan);
      remote.skips = [orphan];
      await following();

      expect(programs.skips.map((each) => each.id), contains('orphan'));
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

  Object? marksFail;

  @override
  Future<List<ProgramMark>> getProgramMarks(String userId, String programId) async {
    if (marksFail case final Object error) throw error;
    return [
      ...?marks[programId],
      for (final skip in skips)
        if (skip.programId == programId) ProgramMark.skip(skip),
    ];
  }

  final skips = <TrainingSkip>[];

  @override
  Future<List<TrainingSkip>> getSkips(String userId) async => [...skips];

  @override
  Future<void> storeSkips(Iterable<TrainingSkip> skips, String userId) async {
    this.skips
      ..clear()
      ..addAll(skips);
  }

  @override
  Future<void> storeSkip(TrainingSkip skip, String userId) async {
    skips
      ..removeWhere((each) => each.id == skip.id)
      ..add(skip);
  }

  @override
  Future<void> deleteSkip(String skipId) async => skips.removeWhere((each) => each.id == skipId);

  final workouts = <String, List<Workout>>{};

  @override
  Future<List<Workout>> getProgramWorkouts(String userId, String programId) async => [...?workouts[programId]];

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

  var skips = <TrainingSkip>[];

  @override
  Future<List<TrainingSkip>> getSkips() async {
    _call('getSkips');
    return [...skips];
  }

  @override
  Future<Replayed<TrainingSkip>> replaySkip(TrainingSkip skip) async {
    _call('replaySkip ${skip.id}');
    skips = [...skips.where((each) => each.id != skip.id), skip];
    return (row: skip, created: true);
  }

  @override
  Future<void> deleteSkip(String skipId) async {
    _call('deleteSkip $skipId');
    skips = [...skips.where((each) => each.id != skipId)];
  }

  @override
  Future<Template> setTemplateProgram(Template template, {required String? programId}) async {
    _call('setTemplateProgram ${template.id} $programId');
    if (failingFilings.contains(template.id)) throw {'error': 'unavailable'};
    return Template.fromJson({...template.toMap(), 'programId': programId});
  }
}
