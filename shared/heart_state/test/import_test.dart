// Importing the app's own JSON export (#329): the file the export writes, read
// back into a store held in memory behind the same interfaces the database
// implements. What is pinned is identity: the file's ids are the rows', so a
// second import and an import into the store the file came from write nothing.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

const _user = 'u1';

Exercise _exercise(String id, String name, {String category = 'Barbell', String target = 'Chest', bool own = false}) {
  return Exercise.fromJson({'id': id, 'name': name, 'category': category, 'target': target, 'own': own});
}

final _bench = _exercise('ex-bench', 'Bench Press (Barbell)');
final _run = _exercise('ex-run', 'Run', category: 'Cardio', target: 'Cardio');
final _custom = _exercise('ex-custom', 'Muffin pull-up', category: 'Reps Only', target: 'Back', own: true);

Workout _workout(String id, List<(Exercise, List<Map<String, Object>>)> exercises) {
  return Workout.fromJson({
    'id': id,
    'name': 'Session $id',
    'start': '2026-03-01T10:00:00.000Z',
    'end': '2026-03-01T11:00:00.000Z',
    'exercises': [
      for (final (index, (exercise, sets)) in exercises.indexed)
        {
          'id': '$id-we-$index',
          'order': index,
          'exercise': exercise.toMap(),
          'sets': [
            for (final (n, set) in sets.indexed) {'id': '$id-$index-s$n', 'completed': 1, ...set},
          ],
        },
    ],
  });
}

final _folder = TemplateFolder.fromJson({'id': 'f1', 'name': 'Push', 'order': 0});

/// What an export of the store below holds: two workouts, a template filed in
/// a folder, a custom exercise with a unit override, and a goal on it.
ExportSnapshot _snapshot() {
  return ExportSnapshot(
    workouts: [
      _workout('w1', [
        (
          _bench,
          [
            {'weight': 60, 'reps': 8},
            {'weight': 62.5, 'reps': 6},
          ],
        ),
        (
          _custom,
          [
            {'reps': 10},
          ],
        ),
      ]),
      _workout('w2', [
        (
          _run,
          [
            {'distance': 5, 'duration': 1500},
          ],
        ),
      ]),
    ],
    templates: [
      Template.fromJson({
        'id': 't1',
        'name': 'Push day',
        'order': 0,
        'folder': _folder.toMap(),
        'exercises': [
          {
            'id': 't1-0',
            'order': 0,
            'exercise': _bench.toMap(),
            'sets': [
              {'id': 't1-0-s0', 'weight': 60, 'reps': 8},
            ],
          },
        ],
      }),
    ],
    folders: [_folder],
    exercises: [_custom],
    weightUnit: .metric,
    distanceUnit: .metric,
    exerciseUnits: {_custom.id: .imperial},
    goals: [
      Goal.fromJson({
        'id': 'g1',
        'metric': 'totalReps',
        'exerciseId': _custom.id,
        'stages': [
          {'id': 'g1-s1', 'target': 50},
        ],
      }),
    ],
  );
}

String _file({int? schemaVersion}) {
  final json = _snapshot().toJson(exportedAt: DateTime.utc(2026, 3, 2));
  return switch (schemaVersion) {
    null => json,
    final int version => jsonEncode({...jsonDecode(json) as Map, 'schemaVersion': version}),
  };
}

/// One user's store, in memory, answering the way the database does: by id,
/// a write over an existing row replaces it.
class _Store {
  final exercises = <String, Exercise>{};
  final workouts = <String, Workout>{};
  final templates = <String, Template>{};
  final folders = <String, TemplateFolder>{};
  final goals = <String, Goal>{};
  final units = <String, MeasurementUnit>{};

  /// Every write, in order, by kind.
  final writes = <String>[];

  new({Iterable<Exercise> catalog = const []}) {
    for (final each in catalog) {
      exercises[each.id] = each;
    }
  }

  void wire({
    required MockExerciseService exerciseService,
    required MockWorkoutService workoutService,
    required MockTemplateService templateService,
    required MockLocalTemplateFolderService folderService,
    required MockLocalGoalService goalService,
  }) {
    when(exerciseService.getExercises(userId: _user)).thenAnswer((_) async => (null, exercises.values.toList()));
    when(exerciseService.storeExercises(any, userId: _user)).thenAnswer((call) async {
      for (final Exercise each in call.positionalArguments.first) {
        exercises[each.id] = each;
        writes.add('exercise ${each.name}');
      }
    });
    when(exerciseService.getExerciseUnits(_user)).thenAnswer((_) async => Map.of(units));
    when(
      exerciseService.setExerciseUnit(exerciseName: anyNamed('exerciseName'), userId: _user, unit: anyNamed('unit')),
    ).thenAnswer((call) async {
      units[call.namedArguments[#exerciseName] as String] = call.namedArguments[#unit] as MeasurementUnit;
      writes.add('unit');
    });
    when(workoutService.getWorkoutHistory(_user)).thenAnswer((_) async => workouts.values.toList());
    when(workoutService.finishWorkout(any, _user)).thenAnswer((call) async {
      final Workout workout = call.positionalArguments.first;
      workouts[workout.id] = workout;
      writes.add('workout ${workout.id}');
    });
    when(templateService.getTemplates(_user)).thenAnswer((_) async => templates.values.toList());
    when(templateService.storeTemplates(any, userId: _user)).thenAnswer((call) async {
      for (final Template each in call.positionalArguments.first) {
        templates[each.id] = each;
        writes.add('template ${each.id}');
      }
    });
    when(folderService.getFolders(_user)).thenAnswer((_) async => folders.values.toList());
    when(folderService.storeFolder(any, _user)).thenAnswer((call) async {
      final TemplateFolder folder = call.positionalArguments.first;
      folders[folder.id!] = folder;
      writes.add('folder ${folder.id}');
    });
    when(
      goalService.getTargetUserGoals(requesterId: _user, targetUserId: _user, archived: anyNamed('archived')),
    ).thenAnswer((call) async {
      final archived = call.namedArguments[#archived] as bool;
      return goals.values.where((each) => each.archived == archived).toList();
    });
    when(goalService.createGoal(any, _user)).thenAnswer((call) async {
      final Goal goal = call.positionalArguments.first;
      goals[goal.id!] = goal;
      writes.add('goal ${goal.id}');
      return goal;
    });
  }
}

void main() {
  late MockExerciseService exercises;
  late MockWorkoutService workouts;
  late MockTemplateService templates;
  late MockLocalTemplateFolderService folders;
  late MockLocalGoalService goals;
  late DataImport sut;

  setUp(() {
    exercises = MockExerciseService();
    workouts = MockWorkoutService();
    templates = MockTemplateService();
    folders = MockLocalTemplateFolderService();
    goals = MockLocalGoalService();
    sut = DataImport(
      workouts: workouts,
      templates: templates,
      folders: folders,
      exercises: exercises,
      goals: goals,
    );
  });

  _Store wire(_Store store) {
    store.wire(
      exerciseService: exercises,
      workoutService: workouts,
      templateService: templates,
      folderService: folders,
      goalService: goals,
    );
    return store;
  }

  group('into a store that has none of it', () {
    test('the preview counts what is there and writes nothing', () async {
      final store = wire(_Store(catalog: [_bench, _run]));

      final preview = await sut.preview(_file(), _user);

      expect(preview.workoutsFound, 2);
      expect(preview.workoutsAlreadyHere, 0);
      expect(preview.setsFound, 4);
      expect(preview.exercisesUnmatched, isEmpty);
      expect(preview.templates, 1);
      expect(preview.folders, 1);
      expect(preview.goals, 1);
      expect(store.writes, isEmpty);
    });

    test('everything lands, references first, and every workout is left unsynced', () async {
      final store = wire(_Store(catalog: [_bench, _run]));

      final report = await sut.import(_file(), _user);

      expect(report.workoutsCreated, 2);
      expect(report.setsCreated, 4);
      expect(report.setsSkipped, 0);
      expect(report.templates, 1);
      expect(report.folders, 1);
      expect(report.goals, 1);
      expect(store.writes, [
        'exercise Muffin pull-up',
        'folder f1',
        'template t1',
        'workout w1',
        'workout w2',
        'unit',
        'goal g1',
      ]);
      expect(store.exercises[_custom.id]?.isMine, isTrue);
      expect(store.units, {_custom.id: MeasurementUnit.imperial});
      expect(store.templates['t1']?.folderId, 'f1');
      expect(store.workouts['w1']?.map((each) => each.exercise.id), [_bench.id, _custom.id]);
      // a finished workout from the file is local work, for the upsync to carry
      verify(workouts.finishWorkout(any, _user)).called(2);
      verifyNever(workouts.storeWorkoutHistory(any, any));
    });

    test('a second import of the same file writes nothing', () async {
      final store = wire(_Store(catalog: [_bench, _run]));
      await sut.import(_file(), _user);
      final afterFirst = [...store.writes];

      final report = await sut.import(_file(), _user);

      expect(store.writes, afterFirst);
      expect(report.workoutsCreated, 0);
      expect(report.workoutsSkipped, 2);
      expect((report.templates, report.folders, report.goals), (0, 0, 0));
    });
  });

  test('into the store it came from, nothing changes', () async {
    final store = wire(_Store(catalog: [_bench, _run]));
    final snapshot = _snapshot();
    store
      ..exercises[_custom.id] = _custom
      ..folders['f1'] = _folder
      ..templates.addEntries(snapshot.templates.map((each) => MapEntry(each.id, each)))
      ..workouts.addEntries(snapshot.workouts.map((each) => MapEntry(each.id, each)))
      ..goals.addEntries(snapshot.goals.map((each) => MapEntry(each.id!, each)))
      // changed since the export: the store's choice stands
      ..units[_custom.id] = .metric;

    final preview = await sut.preview(_file(), _user);
    final report = await sut.import(_file(), _user);

    expect(preview.workoutsAlreadyHere, 2);
    expect(store.writes, isEmpty);
    expect(report.workoutsCreated, 0);
    expect(store.units[_custom.id], MeasurementUnit.metric);
  });

  test('a custom and a folder the store has by name are the ones the file means', () async {
    final theirs = _exercise('ex-theirs', 'muffin Pull-Up', category: 'Reps Only', target: 'Back', own: true);
    final filing = TemplateFolder.fromJson({'id': 'f-theirs', 'name': 'push', 'order': 0});
    final store = wire(_Store(catalog: [_bench, _run, theirs]))..folders['f-theirs'] = filing;

    await sut.import(_file(), _user);

    expect(store.exercises.keys, isNot(contains(_custom.id)), reason: 'no second custom by that name');
    expect(store.workouts['w1']?.map((each) => each.exercise.id), [_bench.id, theirs.id]);
    expect(store.goals['g1']?.exerciseId, theirs.id);
    expect(store.units, {theirs.id: MeasurementUnit.imperial});
    expect(store.folders.keys, ['f-theirs']);
    expect(store.templates['t1']?.folderId, 'f-theirs');
  });

  group('a name this device does not know', () {
    // the catalog is in another language now: the file's "Run" resolves to
    // nothing here
    _Store catalogWithoutRun() => wire(
      _Store(
        catalog: [
          _bench,
          _exercise('ex-run', 'Correr', category: 'Cardio'),
        ],
      ),
    );

    test('is the consent step\'s question, with the sets riding on it', () async {
      catalogWithoutRun();

      final preview = await sut.preview(_file(), _user);

      expect(preview.exercisesUnmatched, [(name: 'Run', sets: 1)]);
    });

    test('declined, its sets stay behind and are counted', () async {
      final store = catalogWithoutRun();

      final report = await sut.import(_file(), _user, createCustom: const []);

      expect(report.exercisesSkipped, ['Run']);
      expect(report.setsSkipped, 1);
      expect(report.setsCreated, 3);
      expect(store.workouts.keys, ['w1'], reason: 'a workout with nothing left in it is not one');
      expect(report.workoutsSkipped, 0, reason: 'and it was not already here either');
    });

    test('approved, it becomes a custom shaped by what its sets record', () async {
      final store = catalogWithoutRun();

      final report = await sut.import(_file(), _user);

      expect(report.exercisesCreated, ['Run']);
      final created = store.exercises.values.singleWhere((each) => each.name == 'Run');
      expect(created.isMine, isTrue);
      expect(created.category, Category.cardio);
      expect(created.id, isNot('ex-run'), reason: 'a fresh id, not the catalog row the file meant');
      expect(store.workouts['w2']?.single.exercise.id, created.id);
    });
  });

  test('schema 1, which wrote the whole exercise, resolves by id', () async {
    final store = wire(
      _Store(
        catalog: [
          _bench,
          _exercise('ex-run', 'Correr', category: 'Cardio'),
        ],
      ),
    );
    final v2 = jsonDecode(_file()) as Map;
    final v1 = {
      ...v2,
      'schemaVersion': 1,
      'workouts': [
        for (final Map workout in v2['workouts'])
          {
            ...workout,
            'exercises': [
              for (final Map entry in workout['exercises'])
                {
                  ...entry,
                  'exercise': switch (entry['exercise']) {
                    'Run' => _run.toMap(),
                    'Bench Press (Barbell)' => _bench.toMap(),
                    _ => _custom.toMap(),
                  },
                },
            ],
          },
      ],
    };

    final preview = await sut.preview(jsonEncode(v1), _user);
    await sut.import(jsonEncode(v1), _user);

    expect(preview.exercisesUnmatched, isEmpty);
    expect(store.workouts['w2']?.single.exercise.id, 'ex-run');
  });

  group('a file this build cannot read is refused, and nothing is written', () {
    Matcher refused(UnreadableExportReason reason) {
      return throwsA(isA<UnreadableExport>().having((e) => e.reason, 'reason', reason));
    }

    for (final (label, file, reason) in [
      ('not JSON', 'Date,Workout Name\n2024-01-01,Push', UnreadableExportReason.notHeart),
      ('someone else\'s JSON', '{"workouts": []}', UnreadableExportReason.notHeart),
      ('a list', '[1, 2]', UnreadableExportReason.notHeart),
      ('a newer layout', _file(schemaVersion: exportSchemaVersion + 1), UnreadableExportReason.newer),
    ]) {
      test(label, () async {
        final store = wire(_Store(catalog: [_bench, _run]));

        await expectLater(sut.import(file, _user), refused(reason));
        expect(store.writes, isEmpty);
      });
    }
  });

  group('a program in the file', () {
    final at = DateTime.utc(2026, 3, 1);

    String file() {
      final snapshot = _snapshot();
      return ExportSnapshot(
        workouts: [
          for (final workout in snapshot.workouts)
            Workout.fromJson({...workout.toMap(), if (workout.id == 'w1') 'programId': 'p1'}),
        ],
        templates: [
          for (final template in snapshot.templates) Template.fromJson({...template.toMap(), 'programId': 'p1'}),
        ],
        folders: snapshot.folders,
        exercises: snapshot.exercises,
        weightUnit: .metric,
        distanceUnit: .metric,
        exerciseUnits: snapshot.exerciseUnits,
        goals: snapshot.goals,
        programs: [
          Program(
            id: 'p1',
            name: 'Upper / Lower',
            sessions: const ['t1'],
            createdAt: at,
            deload: const Deload(every: 4),
            phases: const [
              ProgramPhase(name: 'Base', sessions: ['t1']),
            ],
            tests: const {'t1': ProgramTest(share: 0.9)},
          ),
        ],
        programActions: [
          ProgramAction(id: 'a1', programId: 'p1', kind: .pause, at: at),
          ProgramAction(
            id: 'a2',
            programId: 'p1',
            kind: .advance,
            from: _custom.id,
            to: _bench.id,
            workoutId: 'w1',
            at: at,
          ),
        ],
        programBases: [
          ProgramBase(id: 'b1', programId: 'p1', exerciseId: _custom.id, slot: 'te1', value: 40, at: at),
        ],
        skips: [
          TrainingSkip(id: 'k1', at: at, reason: 'sore', templateId: 't1', programId: 'p1'),
          // a program the file doesn't carry: the skip comes, naming none
          TrainingSkip(id: 'k2', at: at, templateId: 't9', programId: 'p9'),
        ],
      ).toJson(exportedAt: DateTime.utc(2026, 3, 2));
    }

    test('comes over with its history, and what names it still does', () async {
      final store = wire(_Store(catalog: [_bench, _run]));
      final programs = _Programs();
      final sut = DataImport(
        workouts: workouts,
        templates: templates,
        folders: folders,
        exercises: exercises,
        goals: goals,
        programs: programs,
      );

      await sut.import(file(), _user);

      expect(programs.writes, ['program p1', 'action a1', 'action a2', 'base b1', 'skip k1', 'skip k2']);
      expect(programs.skips.map((each) => (each.id, each.reason, each.programId)), [
        ('k1', 'sore', 'p1'),
        ('k2', null, null),
      ]);
      expect(store.templates['t1']?.programId, 'p1');
      expect(store.workouts['w1']?.programId, 'p1');

      // the second round's fields come with it (#346)
      final [program] = programs.programs;
      expect((program.deload?.every, program.phases.single.name, program.tests['t1']?.share), (4, 'Base', 0.9));
      final [base] = programs.bases;
      expect(base.slot, 'te1');
      final advance = programs.actions.last;
      // the advance's exercises, as they are called here, like the base's
      expect((advance.from, advance.to, advance.workoutId), (base.exerciseId, _bench.id, 'w1'));

      // and a second time, nothing
      await sut.import(file(), _user);
      expect(programs.writes, hasLength(6));
    });

    test('with nowhere to keep it, what names it is filed under nothing', () async {
      final store = wire(_Store(catalog: [_bench, _run]));

      await sut.import(file(), _user);

      expect(store.templates['t1']?.programId, isNull);
      expect(store.workouts['w1']?.programId, isNull);
    });
  });
}

/// Programs, in memory: what [DataImport] reads and writes of them.
class _Programs extends Fake implements LocalProgramService {
  final programs = <Program>[];
  final actions = <ProgramAction>[];
  final bases = <ProgramBase>[];
  final writes = <String>[];

  @override
  Future<List<Program>> getPrograms(String userId) async => [...programs];

  @override
  Future<void> storeProgram(Program program, String userId) async {
    programs.add(program);
    writes.add('program ${program.id}');
  }

  @override
  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId}) async => [...actions];

  @override
  Future<void> storeProgramAction(ProgramAction action) async {
    actions.add(action);
    writes.add('action ${action.id}');
  }

  @override
  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId}) async => [...bases];

  @override
  Future<void> storeProgramBase(ProgramBase base) async {
    bases.add(base);
    writes.add('base ${base.id}');
  }

  final skips = <TrainingSkip>[];

  @override
  Future<List<TrainingSkip>> getSkips(String userId) async => [...skips];

  @override
  Future<void> storeSkip(TrainingSkip skip, String userId) async {
    skips.add(skip);
    writes.add('skip ${skip.id}');
  }
}
