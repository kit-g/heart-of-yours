import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Heart's ready-made programs (#352). The fixture is three programs of the
/// real file, rendered by heart-api's `scripts/programs_content.py` and
/// trimmed to `en` and `es`.
void main() {
  final fixture = File('test/fixtures/programs.json').readAsStringSync();
  final content = LibraryContent.read(jsonDecode(fixture))!;
  LibraryProgram fromFile(String key) => content.programs.firstWhere((each) => each.key == key);

  Exercise exercise(String key) {
    return Exercise.fromJson({
      'id': 'id-$key',
      'key': key,
      'own': false,
      'name': key,
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
      'validated': false,
    });
  }

  Exercise? everything(String key) => exercise(key);

  group('reading the file', () {
    test('every program, with who it is for and what it needs', () {
      expect(content.programs.map((each) => each.key), ['first_steps', 'full_body_muscle', 'strength_waves']);
      final first = fromFile('first_steps');
      expect(first.audience, LibraryAudience.startingOut);
      expect(first.equipment, LibraryEquipment.none);
      expect((first.perWeek, first.minutes, first.weeks), (2, 30, 8));
      expect(fromFile('strength_waves').weeks, isNull);
      expect(fromFile('full_body_muscle').deload, isA<Deload>());
    });

    test('copy in the language asked for, falling back to its language, then English', () {
      final name = fromFile('first_steps').name;
      expect(name.of('en'), 'First steps');
      expect(name.of('es'), 'Primeros pasos');
      expect(name.of('es-MX'), 'Primeros pasos');
      expect(name.of('en-CA'), 'First steps');
      // trimmed out of the fixture
      expect(name.of('fr'), 'First steps');
    });

    test('research with where it sits, sources and safety notes by key', () {
      final first = fromFile('first_steps');
      expect(first.claimsAbout('grows'), isNotEmpty);
      expect(first.claimsAbout('rule', exercise: 'plank').single.sources, ['lee_mcgill_2015']);
      expect(first.claimsAbout('rule', exercise: 'no-such-exercise'), isEmpty);
      expect(content.sources['kotarsky_2018']?.url, Uri.parse('https://library.ndsu.edu/ir/handle/10365/28060'));
      expect(content.sources['kotarsky_2018']?.year, 2018);
      expect(first.safety, ['start', 'stop_if', 'discomfort']);
      expect(content.safety['stop_if']?.text.of('es'), startsWith('Para y descansa'));
    });

    test('phases and tests name sessions by their ids in the file', () {
      final waves = fromFile('strength_waves');
      expect(waves.phases, hasLength(2));
      expect(waves.phases.first.cycles, 1);
      expect(waves.phases.last.cycles, isNull);
      expect(waves.tests.keys, waves.phases.first.sessions);
      expect(waves.sessions.map((session) => session.id), containsAll(waves.tests.keys));
    });

    test('what this build does not know costs an entry, never the file', () {
      final read = LibraryContent.read({
        'version': 3,
        'programs': [
          'not a program',
          {'key': 'nameless', 'sessions': []},
          {
            'key': 'new_things',
            'name': 'New things',
            'audience': 'astronauts',
            'equipment': 'spaceship',
            'somethingNew': {'a': 1},
            'deload': {'every': 1000},
            'rules': {
              'squat-barbell': {'kind': 'teleport', 'how': 'fast'},
            },
            'sessions': [
              {
                'id': 's1',
                'name': 'Day',
                'exercises': [
                  {
                    'id': 'e1',
                    'exercise': {'key': 'squat-barbell'},
                    'sets': [
                      {
                        'id': 'x1',
                        'target': {
                          'reps': {'min': 5},
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
        'sources': {
          'broken': {'no': 'title'},
        },
      })!;

      final [only] = read.programs;
      expect(only.key, 'new_things');
      expect((only.audience, only.equipment, only.deload), (null, null, null));
      expect(read.sources, isEmpty);
      // an unknown kind travels to the copy, which carries it as it came
      final copied = only.copy(resolve: everything, tag: 'en')!;
      expect(copied.program.unreadRules.keys, ['id-squat-barbell']);
    });

    test('nothing readable is no library', () {
      expect(LibraryContent.read({'programs': []}), isNull);
      expect(LibraryContent.read('[]'), isNull);
    });
  });

  group('a preview', () {
    test("shows the session's exercises and targets, under the file's own ids", () {
      final session = fromFile('first_steps').sessions.first;
      final template = session.preview(resolve: everything, tag: 'es');
      expect(template.id, session.id);
      expect(template.name, 'Día A');
      expect(template.first.exercise.key, 'sit-to-stand');
      expect(template.first.first.target, isNotNull);
    });

    test('leaves out an exercise the catalog does not know', () {
      final session = fromFile('first_steps').sessions.first;
      final template = session.preview(resolve: (key) => key == 'sit-to-stand' ? null : exercise(key), tag: 'en');
      expect(template.map((each) => each.exercise.key), isNot(contains('sit-to-stand')));
      expect(template, isNotEmpty);
    });
  });

  group('a copy', () {
    test('is the user\'s own: fresh ids throughout, and the library program as its source', () {
      final waves = fromFile('strength_waves');
      final (:program, :sessions) = waves.copy(resolve: everything, tag: 'en')!;
      final fileIds = {
        for (final session in waves.sessions) session.id,
      };

      expect(program.source, 'strength_waves');
      expect(program.name, waves.name.of('en'));
      expect(program.id, isNull, reason: 'Programs.create mints it');
      expect(sessions, hasLength(waves.sessions.length));
      for (final session in sessions) {
        expect(fileIds, isNot(contains(session.id)));
        for (final exercise in session) {
          expect(exercise.exercise.id, 'id-${exercise.exercise.key}');
        }
      }

      final again = waves.copy(resolve: everything, tag: 'en')!;
      expect(
        again.sessions.map((session) => session.id).toSet().intersection(sessions.map((session) => session.id).toSet()),
        isEmpty,
      );
      expect(
        again.sessions.first.first.first.id,
        isNot(sessions.first.first.first.id),
        reason: 'sets get their own ids too',
      );
    });

    test('phases and tests follow the sessions to their new ids', () {
      final waves = fromFile('strength_waves');
      final (:program, :sessions) = waves.copy(resolve: everything, tag: 'es')!;
      final ids = sessions.map((session) => session.id).toSet();
      expect(program.phases, hasLength(2));
      expect(program.phases.first.name, 'Encuentra tus máximos');
      expect(program.phases.expand((phase) => phase.sessions).toSet(), ids);
      expect(program.tests.keys.toSet(), program.phases.first.sessions.toSet());
    });

    test('rules and a ladder\'s rungs go by the ids the catalog has', () {
      final (:program, sessions: _) = fromFile('first_steps').copy(resolve: everything, tag: 'en')!;
      final ladder = program.rules['id-wall-push-up'];
      expect(ladder, isA<Ladder>());
      expect((ladder! as Ladder).rungs.first, 'id-wall-push-up');
      expect(program.rules['id-plank'], isA<Longer>());
      expect(program.unreadRules, isEmpty);
    });

    test('a rung the catalog does not know is left out, and so is a ladder left with one', () {
      final first = fromFile('first_steps');
      final (:program, sessions: _) = first.copy(
        resolve: (key) => switch (key) {
          'push-up' || 'decline-push-up' => null,
          _ => exercise(key),
        },
        tag: 'en',
      )!;
      expect((program.rules['id-wall-push-up']! as Ladder).rungs, isNot(contains('id-push-up')));

      final (program: bare, sessions: _) = first.copy(
        resolve: (key) => switch (key) {
          'incline-push-up' || 'push-up-knees' || 'push-up' || 'decline-push-up' => null,
          _ => exercise(key),
        },
        tag: 'en',
      )!;
      expect(bare.rules, isNot(contains('id-wall-push-up')));
    });

    test("a share of another lift's max goes by that lift's id, and without it is no share at all", () {
      final read = LibraryContent.read({
        'programs': [
          {
            'key': 'shares',
            'name': 'Shares',
            'sessions': [
              {
                'id': 's1',
                'name': 'Day',
                'exercises': [
                  {
                    'id': 'e1',
                    'exercise': {'key': 'front-squat-barbell'},
                    'sets': [
                      {
                        'id': 'x1',
                        'target': {
                          'share': 0.55,
                          'of': 'squat-barbell',
                          'reps': {'min': 5, 'max': 5},
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      })!;
      final shares = read.programs.single;

      final known = shares.copy(resolve: everything, tag: 'en')!;
      final target = known.sessions.single.first.first.target!;
      expect(target.toMap(), containsPair('of', 'id-squat-barbell'));
      expect(target.toMap(), containsPair('share', 0.55));

      final unknown = shares.copy(resolve: (key) => key == 'squat-barbell' ? null : exercise(key), tag: 'en')!;
      final bare = unknown.sessions.single.first.first.target!.toMap();
      expect(bare, isNot(contains('of')));
      expect(bare, isNot(contains('share')));
      expect(bare, contains('reps'));
    });

    test('an exercise the catalog does not know is left out, and a session left with none goes too', () {
      final first = fromFile('first_steps');
      final keys = first.sessions.first.exerciseKeys.toSet();
      final (:program, :sessions) = first.copy(
        resolve: (key) => keys.contains(key) ? null : exercise(key),
        tag: 'en',
      )!;
      expect(sessions, hasLength(first.sessions.length - 1));
      expect(program.name, 'First steps');

      expect(first.copy(resolve: (_) => null, tag: 'en'), isNull);
    });

    test('sessions are filed under the folder given, numbered from the order given', () {
      final folder = TemplateFolder(id: 'f1', name: 'First steps', order: 0);
      final (program: _, :sessions) = fromFile('first_steps').copy(
        resolve: everything,
        tag: 'en',
        folder: folder,
        order: 7,
      )!;
      expect(sessions.map((session) => session.folderId), everyElement('f1'));
      expect(sessions.map((session) => session.order), [7, 8]);
    });
  });

  group('the library', () {
    late List<String?> asked;
    late Map<String, ({String body, String? etag})> kept;
    late List<Object> errors;

    ProgramLibrary library(Future<({String body, String? etag})?> Function(String? etag) fetch) {
      asked = [];
      errors = [];
      return ProgramLibrary(
        fetch: ({etag}) {
          asked.add(etag);
          return fetch(etag);
        },
        read: (key) async => kept[key],
        store: (key, {required body, etag}) async => kept[key] = (body: body, etag: etag),
        onError: (error, {stacktrace}) => errors.add(error),
      );
    }

    setUp(() => kept = {});

    test('a first read fetches the file and keeps it with its ETag', () async {
      final programs = library((_) async => (body: fixture, etag: '"v1"'));
      await programs.ensure();
      expect(programs.available, isTrue);
      expect(programs.lookup('first_steps')?.name.of('en'), 'First steps');
      expect(programs.source('kotarsky_2018')?.title, isNotEmpty);
      expect(programs.safety('stop_if'), isNotNull);
      expect(asked, [null]);
      expect(kept['static/programs'], (body: fixture, etag: '"v1"'));
    });

    test('the kept copy shows at once, and the CDN is asked for a newer one by its ETag', () async {
      kept['static/programs'] = (body: fixture, etag: '"v1"');
      final programs = library((_) async => null);
      await programs.ensure();
      expect(programs.available, isTrue);
      expect(asked, ['"v1"']);
    });

    test('a newer file replaces the kept one', () async {
      kept['static/programs'] = (body: fixture, etag: '"v1"');
      final newer = jsonEncode({
        'programs': [
          {
            'key': 'only',
            'name': 'Only',
            'sessions': [
              {'id': 's1', 'name': 'Day', 'exercises': []},
            ],
          },
        ],
      });
      final programs = library((_) async => (body: newer, etag: '"v2"'));
      await programs.ensure();
      expect(programs.programs.map((each) => each.key), ['only']);
      expect(kept['static/programs']?.etag, '"v2"');
    });

    test('a file not published yet is no library, and no error', () async {
      final programs = library((_) async => throw Exception('403'));
      await programs.ensure();
      expect(programs.available, isFalse);
      expect(errors, isEmpty);
    });

    test('offline, the kept copy stands', () async {
      kept['static/programs'] = (body: fixture, etag: '"v1"');
      final programs = library((_) async => throw Exception('offline'));
      await programs.ensure();
      expect(programs.available, isTrue);
    });

    test('a file that is not a library is reported, and changes nothing', () async {
      final programs = library((_) async => (body: '<html>', etag: null));
      await programs.ensure();
      expect(programs.available, isFalse);
      expect(errors.single, isA<FormatException>());
      expect(kept, isEmpty);
    });

    test('read once a launch, however many ask', () async {
      final programs = library((_) async => (body: fixture, etag: null));
      await Future.wait([programs.ensure(), programs.ensure()]);
      await programs.ensure();
      expect(asked, hasLength(1));
    });
  });
}
