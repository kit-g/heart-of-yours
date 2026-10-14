import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Programs' second round through the mirror (#346, heart-api#227–#234): what
/// the server keeps on a program, its steps, bases and sessions, and what a
/// template plans for an exercise beyond its sets. Whatever comes in goes back
/// out the same, so a save from this device never drops it.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const squat = '019a0000-0000-7000-8000-0000000000a1';
  const front = '019a0000-0000-7000-8000-0000000000a2';
  const row = '019a0000-0000-7000-8000-0000000000a3';
  const knees = '019a0000-0000-7000-8000-0000000000a4';
  const floor = '019a0000-0000-7000-8000-0000000000a5';

  Map<String, dynamic> exercise(String id) => {
    'id': id,
    'name': 'Exercise $id',
    'category': 'Barbell',
    'target': 'Legs',
  };

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    for (final id in [squat, front, row, knees, floor]) {
      await db.insert('exercises', exercise(id));
    }
  });

  tearDown(() => db.close());

  Template session(String id, {List<Map<String, dynamic>> exercises = const [], String? joined}) {
    return Template.fromJson({
      'id': id,
      'name': 'Squat day',
      'order': 0,
      'programId': 'p1',
      'joined': ?joined,
      'exercises': exercises,
    });
  }

  Map<String, dynamic> planned(String id, String exerciseId, Map<String, dynamic> plan, {Map? target}) {
    return {
      'id': id,
      'exercise': exercise(exerciseId),
      'sets': [
        {'id': '$id-s1', 'completed': false, 'target': ?target},
      ],
      ...plan,
    };
  }

  group('a program', () {
    test('keeps its lighter cycles, phases and tests, and reads when its sessions joined', () async {
      final program = Program.fromJson({
        'id': 'p1',
        'name': 'Waves',
        'deload': {'every': 4, 'load': 0.9, 'volume': 0.5},
        'phases': [
          {
            'name': 'Find your maxes',
            'sessions': ['t1'],
            'cycles': 1,
          },
          {
            'name': 'Waves',
            'sessions': ['t2'],
          },
        ],
        'tests': {
          't1': {'share': 0.9},
        },
        'sessions': ['t1', 't2'],
        'createdAt': '2026-10-01T08:00:00.000Z',
      });
      await local.storeTemplates([
        session('t1', joined: '2026-10-01T08:00:00.000Z'),
        session('t2'),
      ], userId: user);
      await local.storeProgram(program, user);

      final [read] = await local.getPrograms(user);
      expect(read.deload?.toMap(), {'every': 4, 'load': 0.9, 'volume': 0.5});
      expect([for (final phase in read.phases) phase.toMap()], [for (final phase in program.phases) phase.toMap()]);
      expect(read.tests['t1']?.share, 0.9);
      expect(read.joined, {'t1': DateTime.utc(2026, 10, 1, 8)});
    });

    test('without them reads back without them', () async {
      await local.storeProgram(Program(id: 'p1', name: 'Plain', sessions: const []), user);

      final [read] = await local.getPrograms(user);
      expect(read.deload, isNull);
      expect([read.phases, read.tests.keys, read.joined.keys], everyElement(isEmpty));
    });

    test('an advance keeps what it moved and why, and a base its slot', () async {
      await local.storeProgram(Program(id: 'p1', name: 'Ladders', sessions: const []), user);
      final at = DateTime.utc(2026, 10, 5);
      await local.storeProgramAction(
        ProgramAction(id: 'a1', programId: 'p1', kind: .advance, from: knees, to: floor, workoutId: 'w1', at: at),
      );
      await local.storeProgramBase(
        ProgramBase(id: 'b1', programId: 'p1', exerciseId: squat, slot: 'te1', value: 120, at: at),
      );

      final [action] = await local.getProgramActions(user);
      expect((action.kind, action.from, action.to, action.workoutId), (ProgramActionKind.advance, knees, floor, 'w1'));
      final [base] = await local.getProgramBases(user);
      expect(base.slot, 'te1');
    });

    test('deleting a workout takes the advance it caused', () async {
      await local.storeProgram(Program(id: 'p1', name: 'Ladders', sessions: const []), user);
      final at = DateTime.utc(2026, 10, 5);
      await local.storeWorkoutHistory([
        Workout.fromJson({'id': 'w1', 'start': at.toIso8601String(), 'end': at.toIso8601String(), 'programId': 'p1'}),
      ], user);
      await local.storeProgramAction(
        ProgramAction(id: 'a1', programId: 'p1', kind: .advance, from: knees, to: floor, workoutId: 'w1', at: at),
      );
      await local.storeProgramAction(ProgramAction(id: 'a2', programId: 'p1', kind: .lighter, at: at));

      await local.deleteWorkout('w1');

      final [left] = await local.getProgramActions(user);
      expect(left.id, 'a2');
    });
  });

  group("a template exercise's plan", () {
    test('rest, superset, an open slot and a rep total come back as they went', () async {
      await local.storeTemplates([
        session(
          't1',
          exercises: [
            planned('te1', row, {
              'rest': 90,
              'superset': 1,
              'pattern': 'horizontal_row',
              'totalReps': {'min': 50, 'max': 100},
            }),
          ],
        ),
      ], userId: user);

      final [read] = (await local.getTemplates(user)).toList();
      final [plan] = read.toList();
      expect(
        (plan.rest, plan.superset, plan.pattern, plan.totalReps),
        (90, 1, 'horizontal_row', const TargetRange(min: 50, max: 100)),
      );
    });

    test('a key cleared stays cleared, and one never had stays out of the next save', () async {
      await local.storeTemplates([
        session(
          't1',
          exercises: [
            planned('te1', row, {'rest': null}),
          ],
        ),
      ], userId: user);

      final [read] = (await local.getTemplates(user)).toList();
      final map = read.first.toMap();
      // null clears the server's; an absent key keeps it
      expect(map, containsPair('rest', null));
      expect(map.containsKey('superset'), isFalse);
    });

    test('a total in a shape this build predates is carried as it came', () async {
      await local.storeTemplates([
        session(
          't1',
          exercises: [
            planned('te1', row, {
              'totalReps': {'per': 'side', 'min': 20},
            }),
          ],
        ),
      ], userId: user);

      final [read] = (await local.getTemplates(user)).toList();
      expect(read.first.toMap()['totalReps'], {'per': 'side', 'min': 20});
    });

    test('a workout started from the template carries its rest and superset', () async {
      final template = session(
        't1',
        exercises: [
          planned('te1', row, {'rest': 60, 'superset': 2}),
        ],
      );
      await local.startWorkout(template.toWorkout(), user);

      final active = await local.getActiveWorkout(user);
      final started = active!.first;
      expect((started.rest, started.superset), (60, 2));
    });
  });

  group('a history move', () {
    test("re-keys a ladder's rungs and its advances, and the share targets that name it", () async {
      await local.storeTemplates([
        session(
          't1',
          exercises: [
            planned(
              'te1',
              front,
              {},
              target: {
                'reps': {'min': 5, 'max': 5},
                'share': 0.55,
                'of': squat,
              },
            ),
          ],
        ),
      ], userId: user);
      await local.storeProgram(
        Program.fromJson({
          'id': 'p1',
          'name': 'Ladders',
          'rules': {
            knees: {
              'kind': 'ladder',
              'rungs': [knees, floor, squat],
              'top': 12,
              'bottom': 8,
            },
          },
          'sessions': ['t1'],
        }),
        user,
      );
      final at = DateTime.utc(2026, 10, 5);
      await local.storeProgramAction(
        ProgramAction(id: 'a1', programId: 'p1', kind: .advance, from: squat, to: knees, workoutId: 'w1', at: at),
      );

      await local.moveExerciseHistory(sourceId: squat, targetId: row, userId: user, deleteSource: false);

      final [program] = await local.getPrograms(user);
      expect((program.rules[knees] as Ladder).rungs, [knees, floor, row]);
      final [action] = await local.getProgramActions(user);
      expect((action.from, action.to), (row, knees));
      final [template] = (await local.getTemplates(user)).toList();
      expect(template.first.first.target?.of, row);
    });

    test('drops a ladder left with one rung', () async {
      await local.storeProgram(
        Program.fromJson({
          'id': 'p1',
          'name': 'Ladders',
          'rules': {
            knees: {
              'kind': 'ladder',
              'rungs': [knees, floor],
              'top': 12,
              'bottom': 8,
            },
            squat: {'kind': 'addWeight', 'step': 2.5},
          },
          'sessions': const [],
        }),
        user,
      );

      await local.moveExerciseHistory(sourceId: floor, targetId: knees, userId: user, deleteSource: false);

      final [program] = await local.getPrograms(user);
      expect(program.rules.keys, [squat]);
    });
  });
}
