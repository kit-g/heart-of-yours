import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Programs in the mirror (#346), against a real in-memory SQLite: the shapes
/// here are JSON columns, a session order derived from two tables, and which
/// rows a delete is allowed to take with it.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const bench = '019a0000-0000-7000-8000-00000000000b';
  const squat = '019a0000-0000-7000-8000-00000000000c';

  Program program({
    String id = 'p1',
    List<String> sessions = const [],
    Map<String, GrowthRule> rules = const {},
  }) {
    return Program(
      id: id,
      name: 'Getting stronger',
      perWeek: 3,
      days: {5, 1, 3},
      weeks: 12,
      rules: rules,
      sessions: sessions,
      createdAt: DateTime.utc(2026, 10, 1),
    );
  }

  Template session(String id, {String? programId = 'p1', int order = 0}) {
    return Template.fromJson({'id': id, 'name': 'Session $id', 'order': order, 'programId': ?programId});
  }

  Future<void> workout(String id, {String? templateId, String? programId = 'p1', DateTime? start, bool done = true}) {
    final at = start ?? DateTime.utc(2026, 10, 2, 8);
    return local.storeWorkoutHistory([
      Workout.fromJson({
        'id': id,
        'start': at.toIso8601String(),
        'end': done ? at.add(const Duration(hours: 1)).toIso8601String() : null,
        'templateId': ?templateId,
        'programId': ?programId,
      }),
    ], userId);
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  group('programs', () {
    test('a stored program reads back whole, unread rules included', () async {
      final read = Program.fromJson({
        ...program(rules: {bench: const AddWeight(step: 2.5)}).toMap(),
        'rules': {
          bench: {'kind': 'addWeight', 'step': 2.5},
          squat: {'kind': 'fromTheFuture', 'pace': 3},
        },
      });

      await local.storeProgram(read, userId);
      final [stored] = await local.getPrograms(userId);

      expect(stored.toMap(), {...read.toMap(), 'sessions': <String>[]});
      expect(stored.days, {1, 3, 5});
      expect(stored.unreadRules, {
        squat: {'kind': 'fromTheFuture', 'pace': 3},
      });
    });

    test('sessions keep the stored order, lose a deleted template and gain one filed elsewhere', () async {
      await local.storeTemplates([
        session('t1', order: 0),
        session('t2', order: 1),
        session('t3', order: 2),
      ], userId: userId);
      await local.storeProgram(program(sessions: ['t3', 't1', 't2']), userId);

      await local.deleteTemplate('t1');
      await local.storeTemplates([session('t4', order: 3)], userId: userId);

      final [stored] = await local.getPrograms(userId);
      expect(stored.sessions, ['t3', 't2', 't4']);
    });

    test('templates carry their program and note through the mirror', () async {
      await local.storeTemplates([
        Template.fromJson({'id': 't1', 'name': 'Push', 'order': 0, 'programId': 'p1', 'note': 'chest first'}),
      ], userId: userId);

      final [template] = (await local.getTemplates(userId)).toList();
      expect((template.programId, template.note), ('p1', 'chest first'));
    });

    test('what the server is owed is kept per row, in the order written', () async {
      await local.owePrograms(userId, (row: 'program', id: 'p1', programId: 'p1', change: 'created'));
      await local.owePrograms(userId, (row: 'action', id: 'a1', programId: 'p1', change: 'created'));
      await local.owePrograms(userId, (row: 'action', id: 'a1', programId: 'p1', change: 'deleted'));
      await local.owePrograms('someone else', (row: 'base', id: 'b1', programId: 'p9', change: 'created'));

      expect(await local.getProgramsOwed(userId), [
        (row: 'program', id: 'p1', programId: 'p1', change: 'created'),
        (row: 'action', id: 'a1', programId: 'p1', change: 'deleted'),
      ]);

      await local.settleProgram('program', 'p1');
      expect((await local.getProgramsOwed(userId)).map((each) => each.id), ['a1']);
    });

    test('a full read replaces the programs, and one the server lost takes its history along', () async {
      await local.storeProgram(program(id: 'p1'), userId);
      await local.storeProgram(program(id: 'p2'), userId);
      await local.storeProgramAction(
        ProgramAction(id: 'a1', programId: 'p2', kind: .pause, at: DateTime.utc(2026, 10, 3)),
      );

      await local.storePrograms([program(id: 'p1')], userId);

      expect((await local.getPrograms(userId)).map((each) => each.id), ['p1']);
      expect(await local.getProgramActions(userId), isEmpty);
    });

    test('deleting a program takes its sessions, unless they are kept, and lets its workouts go', () async {
      await local.storeTemplates([session('t1'), session('t2', programId: 'p2')], userId: userId);
      await local.storeProgram(program(id: 'p1', sessions: ['t1']), userId);
      await local.storeProgram(program(id: 'p2', sessions: ['t2']), userId);
      await workout('w1', templateId: 't1');

      await local.deleteProgram('p1', keepTemplates: false);
      await local.deleteProgram('p2', keepTemplates: true);

      expect(await local.getPrograms(userId), isEmpty);
      final [kept] = (await local.getTemplates(userId)).toList();
      expect((kept.id, kept.programId), ('t2', null));
      final [row] = await db.query('workouts');
      expect((row['template_id'], row['program_id']), (null, null));
    });
  });

  group('marks', () {
    test('only finished workouts of the program mark it', () async {
      await local.storeProgram(program(), userId);
      await workout('w1', templateId: 't1', start: DateTime.utc(2026, 10, 2));
      await workout('w2', templateId: 't2', start: DateTime.utc(2026, 10, 4), done: false);
      await workout('w3', templateId: 't3', programId: 'p9');

      final marks = await local.getProgramMarks(userId, 'p1');

      expect(marks.map((mark) => (mark.templateId, mark.at, mark.isWorkout)), [
        ('t1', DateTime.utc(2026, 10, 2), true),
      ]);
    });

    test("a program's workouts are its finished ones, oldest first (#350)", () async {
      await local.storeProgram(program(), userId);
      await workout('w2', templateId: 't1', start: DateTime.utc(2026, 10, 4));
      await workout('w1', templateId: 't1', start: DateTime.utc(2026, 10, 2));
      await workout('w3', templateId: 't2', start: DateTime.utc(2026, 10, 6), done: false);
      await workout('w4', templateId: 't3', programId: 'p9');

      final workouts = await local.getProgramWorkouts(userId, 'p1');

      expect(workouts.map((workout) => workout.id), ['w1', 'w2']);
    });

    test('a shallow copy keeps the links, a whole one may let them go', () async {
      await workout('w1', templateId: 't1');

      // a list page: no exercises, no links
      await local.storeWorkoutHistory([
        Workout.fromJson({'id': 'w1', 'start': '2026-10-02T08:00:00.000Z', 'end': '2026-10-02T09:00:00.000Z'}),
      ], userId);
      var [row] = await db.query('workouts');
      expect((row['template_id'], row['program_id']), ('t1', 'p1'));

      // the whole workout, its links gone on the server
      await local.startWorkout(
        Workout.fromJson({'id': 'w1', 'start': '2026-10-02T08:00:00.000Z', 'end': '2026-10-02T09:00:00.000Z'}),
        userId,
      );
      [row] = await db.query('workouts');
      expect((row['template_id'], row['program_id']), (null, null));
    });

    test('a workout reads back what it was started from', () async {
      await workout('w1', templateId: 't1');

      final read = await local.getWorkout(userId, 'w1');

      expect((read?.templateId, read?.programId), ('t1', 'p1'));
    });
  });

  group('actions and bases', () {
    final at = DateTime.utc(2026, 10, 5);

    setUp(() => local.storeProgram(program(), userId));

    test('a full read replaces the program\'s actions, oldest first', () async {
      await local.storeProgramAction(ProgramAction(id: 'old', programId: 'p1', kind: .pause, at: at));

      await local.storeProgramActions('p1', [
        ProgramAction(id: 'a2', programId: 'p1', kind: .replay, week: 2, at: at.add(const Duration(days: 1))),
        ProgramAction(id: 'a1', programId: 'p1', kind: .repeat, at: at),
      ]);

      final actions = await local.getProgramActions(userId, programId: 'p1');
      expect(actions.map((each) => (each.id, each.kind, each.week)), [
        ('a1', ProgramActionKind.repeat, null),
        ('a2', ProgramActionKind.replay, 2),
      ]);
    });

    test('undoing an action takes the bases it moved', () async {
      await local.storeProgramAction(ProgramAction(id: 'a1', programId: 'p1', kind: .replay, week: 1, at: at));
      await local.storeProgramBase(
        ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench, value: 90, actionId: 'a1', at: at),
      );
      await local.storeProgramBase(ProgramBase(id: 'b0', programId: 'p1', exerciseId: bench, value: 100, at: at));

      await local.deleteProgramAction('a1');

      expect(await local.getProgramActions(userId), isEmpty);
      final [base] = await local.getProgramBases(userId);
      expect((base.id, base.value, base.isManual), ('b0', 100, true));
    });

    test('deleting a workout takes the bump it caused', () async {
      await workout('w1');
      await local.storeProgramBase(
        ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench, value: 102.5, workoutId: 'w1', at: at),
      );

      await local.deleteWorkout('w1');

      expect(await local.getProgramBases(userId, programId: 'p1'), isEmpty);
    });

    test('a full read replaces the program\'s bases', () async {
      await local.storeProgramBase(ProgramBase(id: 'b0', programId: 'p1', exerciseId: bench, value: 100, at: at));

      await local.storeProgramBases('p1', [
        ProgramBase(id: 'b1', programId: 'p1', exerciseId: squat, value: 140, at: at),
      ]);

      final [base] = await local.getProgramBases(userId);
      expect((base.id, base.exerciseId, base.value), ('b1', squat, 140));
    });
  });

  group('an exercise moving', () {
    test('takes its program rule and bases along, and the target keeps its own rule', () async {
      const press = '019a0000-0000-7000-8000-00000000000d';
      await local.storeProgram(
        program(
          rules: {bench: const AddWeight(step: 2.5), squat: const Longer(step: 5), press: const AddWeight(step: 1)},
        ),
        userId,
      );
      final at = DateTime.utc(2026, 10, 5);
      await local.storeProgramBase(ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench, value: 100, at: at));

      // bench onto an exercise without a rule; squat onto one with its own
      const incline = '019a0000-0000-7000-8000-00000000000e';
      await local.moveExerciseHistory(sourceId: bench, targetId: incline, userId: userId, deleteSource: false);
      await local.mergeExercise(userId, from: squat, to: press);

      final [stored] = await local.getPrograms(userId);
      expect(stored.rules, {incline: const AddWeight(step: 2.5), press: const AddWeight(step: 1)});
      final [base] = await local.getProgramBases(userId);
      expect(base.exerciseId, incline);
    });
  });

  test('erasing a user takes their programs and everything under them', () async {
    await local.storeProgram(program(), userId);
    await local.storeProgramAction(
      ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 5)),
    );
    await local.storeProgramBase(
      ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench, value: 100, at: DateTime.utc(2026, 10, 5)),
    );

    await local.eraseUser(userId);

    for (final table in ['programs', 'program_actions', 'program_bases']) {
      expect(await db.query(table), isEmpty, reason: table);
    }
  });

  test('rekeying a user moves their programs, actions and bases with them', () async {
    await local.storeProgram(program(), userId);
    await local.storeProgramAction(
      ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: DateTime.utc(2026, 10, 5)),
    );

    await local.rekeyUser(userId, 'user-2');

    expect(await local.getPrograms(userId), isEmpty);
    expect((await local.getPrograms('user-2')).single.id, 'p1');
    expect(await local.getProgramActions('user-2'), hasLength(1));
  });
}
