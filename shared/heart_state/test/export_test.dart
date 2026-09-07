// "Export my data" (#95): both writers against one fixture store, held to
// golden files, plus the two rules the goldens cannot state on their own —
// nothing from the health contract leaves, and nothing the mirror does not
// actually hold is invented on the way out.
//
// Regenerate the goldens after a deliberate format change with
//   flutter test test/export_test.dart --dart-define=UPDATE_GOLDENS=true
// and read the diff before committing it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

const _updateGoldens = bool.fromEnvironment('UPDATE_GOLDENS');

const _user = 'u1';

Map<String, dynamic> _exercise(
  String id,
  String name, {
  required String category,
  required String target,
  bool own = false,
}) {
  return {'id': id, 'name': name, 'category': category, 'target': target, 'own': own};
}

/// The catalog's own bulk, which a workout's wire shape carries in full: the
/// instructions, the two asset links with their dimensions, the tagging. This
/// fixture exists because without it the goldens could not tell a reference
/// from a copy — and an account of 568 workouts exported to 11.2 MB before
/// anyone noticed (heart-of-yours#113).
final _bench = {
  ..._exercise('ex-bench', 'Bench Press (Barbell)', category: 'Barbell', target: 'Chest'),
  'instructions':
      'Lie back on a flat bench. Using a medium width grip, lift the bar from the rack '
      'and hold it straight over you with your arms locked. Breathe in and begin coming down '
      'slowly until the bar touches your middle chest.',
  'asset': 'https://cdn.example/exercises/bench-press.webp',
  'assetWidth': 1024,
  'assetHeight': 768,
  'thumbnail': 'https://cdn.example/exercises/bench-press-thumb.webp',
  'thumbnailWidth': 256,
  'thumbnailHeight': 192,
  'muscles': {
    'primary': {
      'ids': ['pectoralis-major'],
      'groups': ['chest'],
    },
    'secondary': {
      'ids': ['triceps-brachii'],
      'groups': ['arms'],
    },
  },
};
final _run = _exercise('ex-run', 'Run', category: 'Cardio', target: 'Cardio');
final _plank = _exercise('ex-plank', 'Plank', category: 'Duration', target: 'Core');
// a comma and quotes in the name: what the CSV writer has to escape
final _custom = _exercise('ex-custom', 'Muffin, "special" pull-up', category: 'Reps Only', target: 'Other', own: true);

/// Two finished workouts, handed over newest first so the writer has to sort,
/// and one still running, which no export may carry. The first carries the
/// two fields the health contract keeps off every wire.
List<Workout> _workouts() {
  return [
    Workout.fromJson({
      'id': 'w2',
      'name': 'Run, then plank',
      'start': '2026-03-03T07:30:00.000Z',
      'end': '2026-03-03T08:00:00.000Z',
      'exercises': [
        {
          'id': 'we-3',
          'order': 0,
          'exercise': _run,
          'sets': [
            {'id': 's4', 'distance': 5, 'duration': 1500, 'completed': 1},
          ],
        },
        {
          'id': 'we-4',
          'order': 1,
          'exercise': _plank,
          'sets': [
            {'id': 's5', 'duration': 60, 'completed': 1},
          ],
        },
      ],
      'synced': 1,
    }),
    Workout.fromJson({
      'id': 'w1',
      'name': 'Push day',
      'start': '2026-03-01T10:00:00.000Z',
      'end': '2026-03-01T11:00:00.000Z',
      'calories': 350,
      'images': [
        {'workoutId': 'w1', 'id': 'img1', 'url': 'https://cdn.example/w1/img1.jpg', 'key': 'workouts/w1/img1.jpg'},
      ],
      'exercises': [
        {
          'id': 'we-1',
          'order': 0,
          'exercise': _bench,
          'met': 4.2,
          'sets': [
            {'id': 's1', 'weight': 60, 'reps': 8, 'completed': 1},
            {'id': 's2', 'weight': 62.5, 'reps': 6, 'completed': 1},
          ],
        },
        {
          'id': 'we-2',
          'order': 1,
          'exercise': _custom,
          'note': 'one hand at a time',
          'sets': [
            {'id': 's3', 'reps': 10, 'completed': 1},
          ],
        },
      ],
      'synced': 1,
    }),
    Workout.fromJson({
      'id': 'w-active',
      'name': 'Still going',
      'start': '2026-03-05T18:00:00.000Z',
      'end': '',
      'exercises': [
        {
          'id': 'we-5',
          'order': 0,
          'exercise': _bench,
          'sets': [
            {'id': 's6', 'weight': 40, 'reps': 10, 'completed': 0},
          ],
        },
      ],
      'synced': 0,
    }),
  ];
}

/// Handed over out of order, like the workouts.
List<Template> _templates() {
  return [
    Template.fromJson({
      'id': 't2',
      'order': 1,
      'name': 'Pull',
      'exercises': [
        {
          'id': 'we-t2',
          'exercise': _custom,
          'sets': [
            {'id': 'ts2', 'reps': 8},
          ],
        },
      ],
    }),
    Template.fromJson({
      'id': 't1',
      'order': 0,
      'name': 'Push',
      'folder': {'id': 'f1', 'name': 'Split', 'order': 0},
      'exercises': [
        {
          'id': 'we-t1',
          'exercise': _bench,
          'sets': [
            {'id': 'ts1', 'weight': 80, 'reps': 5},
          ],
        },
      ],
    }),
  ];
}

List<TemplateFolder> _folders() {
  return [TemplateFolder(id: 'f1', name: 'Split', order: 0, createdAt: DateTime.utc(2026, 1, 1))];
}

Goal _live() {
  return Goal.fromJson({
    'id': 'g1',
    'metric': 'topSetWeight',
    'exerciseId': 'ex-bench',
    'stages': [
      {'id': 'gs1', 'target': 100, 'dueOn': '2026-12-25'},
    ],
    'archived': false,
    'createdAt': '2026-02-01T00:00:00.000Z',
  });
}

Goal _achieved() {
  return Goal.fromJson({
    'id': 'g2',
    'metric': 'workouts',
    'cadence': 'week',
    'stages': [
      {'id': 'gs2', 'target': 3, 'achievedAt': '2026-02-08T00:00:00.000Z', 'achievedBy': 'w1'},
    ],
    'archived': true,
    'createdAt': '2026-01-15T00:00:00.000Z',
  });
}

/// Resolves the heart_state package root whether the runner's working
/// directory is the package itself or the repository root.
Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/lib/src/export.dart').existsSync()) {
      return dir;
    }
    final nested = Directory('${dir.path}/shared/heart_state');
    if (File('${nested.path}/lib/src/export.dart').existsSync()) {
      return nested;
    }
    dir = dir.parent;
  }
  fail('could not locate the heart_state package root from ${Directory.current.path}');
}

/// Holds [actual] to the golden at `test/goldens/[name]`, or rewrites it when
/// the suite runs with `UPDATE_GOLDENS`.
void _matchesGolden(String actual, String name) {
  final file = File('${_packageRoot().path}/test/goldens/$name');
  if (_updateGoldens) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
    return;
  }
  expect(file.existsSync(), isTrue, reason: 'no golden at ${file.path} — run with --dart-define=UPDATE_GOLDENS=true');
  expect(actual, file.readAsStringSync());
}

void main() {
  late MockWorkoutService workouts;
  late MockTemplateService templates;
  late MockLocalTemplateFolderService folders;
  late MockExerciseService exercises;
  late MockGoalService goals;
  late DataExport export;

  setUp(() {
    workouts = MockWorkoutService();
    templates = MockTemplateService();
    folders = MockLocalTemplateFolderService();
    exercises = MockExerciseService();
    goals = MockGoalService();
    export = DataExport(
      workouts: workouts,
      templates: templates,
      folders: folders,
      exercises: exercises,
      goals: goals,
    );

    when(workouts.getWorkoutHistory(_user)).thenAnswer((_) async => _workouts());
    when(templates.getTemplates(_user)).thenAnswer((_) async => _templates());
    when(folders.getFolders(_user)).thenAnswer((_) async => _folders());
    when(exercises.getExercises(userId: _user)).thenAnswer(
      (_) async => (null, [_bench, _custom, _run, _plank].map(Exercise.fromJson)),
    );
    when(exercises.getExerciseUnits(_user)).thenAnswer((_) async => {'ex-run': .imperial});
    when(goals.getTargetUserGoals(requesterId: _user, targetUserId: _user)).thenAnswer((_) async => [_live()]);
    when(
      goals.getTargetUserGoals(requesterId: _user, targetUserId: _user, archived: true),
    ).thenAnswer((_) async => [_achieved()]);
  });

  Future<ExportSnapshot> read() {
    return export.read(_user, weightUnit: .imperial, distanceUnit: .metric);
  }

  group('reading the store', () {
    test('finished workouts oldest first, both goal slices, the user\'s own exercises only', () async {
      final snapshot = await read();

      expect(snapshot.workouts.map((each) => each.id), ['w1', 'w2']);
      expect(snapshot.templates.map((each) => each.id), ['t1', 't2']);
      expect(snapshot.folders.map((each) => each.id), ['f1']);
      expect(snapshot.exercises.map((each) => each.id), ['ex-custom']);
      expect(snapshot.goals.map((each) => each.id), ['g1', 'g2']);
      expect(snapshot.exerciseUnits, {'ex-run': MeasurementUnit.imperial});
    });

    test('a mirror with no history reads as empty, not as a failure', () async {
      when(workouts.getWorkoutHistory(_user)).thenAnswer((_) async => null);

      final snapshot = await read();

      expect(snapshot.workouts, isEmpty);
    });
  });

  group('the JSON envelope', () {
    test('matches its golden', () async {
      final snapshot = await read();

      _matchesGolden(snapshot.toJson(exportedAt: DateTime.utc(2026, 9, 6, 12)), 'export.json');
    });

    test('carries the schema version, the stamp and the units', () async {
      final snapshot = await read();

      final envelope = jsonDecode(snapshot.toJson(exportedAt: DateTime.utc(2026, 9, 6, 12))) as Map;

      expect(envelope['schemaVersion'], exportSchemaVersion);
      expect(envelope['exportedAt'], '2026-09-06T12:00:00.000Z');
      expect(envelope['units'], {
        'weight': 'imperial',
        'distance': 'metric',
        'exercises': {'ex-run': 'imperial'},
      });
    });

    test('nothing from the health contract, and no timestamp the mirror never held', () async {
      final snapshot = await read();

      final envelope = jsonDecode(snapshot.toJson(exportedAt: DateTime.utc(2026, 9, 6, 12))) as Map;

      for (final workout in envelope['workouts'] as List) {
        expect(workout, isNot(contains('calories')));
      }
      for (final key in ['workouts', 'templates']) {
        for (final owner in (envelope[key] as List).cast<Map>()) {
          for (final exercise in (owner['exercises'] as List).cast<Map>()) {
            expect(exercise, isNot(contains('met')));
            expect(exercise, isNot(contains('start')), reason: 'the mirror has no exercise timestamp');
            for (final set in exercise['sets'] as List) {
              expect(set, isNot(contains('started_at')), reason: 'the mirror has no set timestamp');
            }
          }
        }
      }
    });

    test('an empty store is a complete envelope with nothing in it', () async {
      when(workouts.getWorkoutHistory(_user)).thenAnswer((_) async => const []);
      when(templates.getTemplates(_user)).thenAnswer((_) async => const []);
      when(folders.getFolders(_user)).thenAnswer((_) async => const []);
      when(exercises.getExercises(userId: _user)).thenAnswer((_) async => (null, const <Exercise>[]));
      when(exercises.getExerciseUnits(_user)).thenAnswer((_) async => const {});
      when(goals.getTargetUserGoals(requesterId: _user, targetUserId: _user)).thenAnswer((_) async => const []);
      when(
        goals.getTargetUserGoals(requesterId: _user, targetUserId: _user, archived: true),
      ).thenAnswer((_) async => const []);

      final snapshot = await read();
      final envelope = jsonDecode(snapshot.toJson(exportedAt: DateTime.utc(2026, 9, 6, 12))) as Map;

      expect(envelope.keys, [
        'schemaVersion',
        'exportedAt',
        'units',
        'workouts',
        'templates',
        'folders',
        'exercises',
        'goals',
      ]);
      for (final key in ['workouts', 'templates', 'folders', 'exercises', 'goals']) {
        expect(envelope[key], isEmpty);
      }
    });
  });

  group('the catalog is named, not copied', () {
    Future<Map<String, dynamic>> envelope() async {
      final snapshot = await read();
      return jsonDecode(snapshot.toJson(exportedAt: DateTime.utc(2026, 9, 6, 12))) as Map<String, dynamic>;
    }

    test('a workout names its exercise, and that is the whole of it', () async {
      final json = await envelope();

      final entries = (json['workouts'] as List).cast<Map<String, dynamic>>().expand(
        (workout) => (workout['exercises'] as List).cast<Map<String, dynamic>>(),
      );

      expect(
        entries.map((entry) => entry['exercise']),
        // the localized display copy, which is the only part of an exercise a
        // person reading their own file is looking for
        ['Bench Press (Barbell)', 'Muffin, "special" pull-up', 'Run', 'Plank'],
      );
    });

    test('none of the catalog reaches the file through a workout', () async {
      final json = await envelope();
      final workouts = jsonEncode(json['workouts']);

      // the fields that made the file 11.2 MB: written once per exercise per
      // workout, they are the same library row thousands of times over
      for (final field in const ['instructions', 'asset', 'thumbnail', 'muscles', 'movement', 'category', 'target']) {
        expect(workouts, isNot(contains('"$field"')), reason: '$field rode along on a workout');
      }
    });

    test('a custom of the user\'s own keeps everything it has', () async {
      final json = await envelope();

      // the rule is about the *catalog*, not about the user's rows: their own
      // exercises are theirs, and the envelope carries them whole
      final own = (json['exercises'] as List).cast<Map<String, dynamic>>();
      expect(own.map((each) => each['id']), ['ex-custom']);
      expect(own.single, contains('own'));
    });

    test('the schema version says the shape changed', () async {
      final json = await envelope();

      // a reader written against v1 would find a string where an object was
      expect(json['schemaVersion'], 2);
      expect(exportSchemaVersion, 2);
    });
  });

  group('the CSV', () {
    test('matches its golden', () async {
      final snapshot = await read();

      _matchesGolden(snapshot.toCsv(), 'export.csv');
    });

    test('one row per set, in the unit the user sees, with the name escaped', () async {
      final snapshot = await read();

      final lines = const LineSplitter().convert(snapshot.toCsv());

      expect(
        lines.first,
        'workout_id,start,end,exercise_id,exercise_name,set_index,weight,unit,reps,duration,distance,notes',
      );
      expect(lines, hasLength(1 + 5), reason: 'five sets across the two finished workouts; the running one has none');
      // global weight unit is imperial: 60 kg reads as pounds
      expect(
        lines[1],
        'w1,2026-03-01T10:00:00.000Z,2026-03-01T11:00:00.000Z,ex-bench,Bench Press (Barbell),1,132.28,lb,8,,,',
      );
      expect(lines[2], contains(',2,137.79,lb,6,,,'));
      // the custom exercise: quoted name, no measurement but reps, the note along
      expect(
        lines[3],
        'w1,2026-03-01T10:00:00.000Z,2026-03-01T11:00:00.000Z,ex-custom,"Muffin, ""special"" pull-up",1,,,10,,,one hand at a time',
      );
      // the run has its own override: kilometres read as miles
      expect(lines[4], 'w2,2026-03-03T07:30:00.000Z,2026-03-03T08:00:00.000Z,ex-run,Run,1,,mi,,1500,3.11,');
      expect(lines[5], 'w2,2026-03-03T07:30:00.000Z,2026-03-03T08:00:00.000Z,ex-plank,Plank,1,,,,60,,');
    });

    test('is LF-terminated, every line', () async {
      final snapshot = await read();

      final csv = snapshot.toCsv();

      expect(csv, isNot(contains('\r')));
      expect(csv, endsWith('\n'));
    });

    test('an empty store is the header alone', () async {
      when(workouts.getWorkoutHistory(_user)).thenAnswer((_) async => const []);

      final snapshot = await read();

      expect(
        snapshot.toCsv(),
        'workout_id,start,end,exercise_id,exercise_name,set_index,weight,unit,reps,duration,distance,notes\n',
      );
    });
  });
}
