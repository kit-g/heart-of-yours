import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_api/src/programs.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group("starting a coach's copy (#557)", () {
    const id = '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c';

    test('a 204 is started', () async {
      respond(client: client, method: 'POST', path: Router.programStart(id), statusCode: 204, body: {});
      await api.startProgram(id);
      verify(
        client.post(
          Uri.https('api.example.com', Router.programStart(id)),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    test("someone else's is a refusal, typed", () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.programStart(id),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'program_not_found'},
      );
      expect(
        () => api.startProgram(id),
        throwsA(isA<ProgramRefused>().having((e) => e.reason, 'reason', ProgramRefusal.programNotFound)),
      );
    });
  });

  group('programs', () {
    const bench = '019a0000-0000-7000-8000-00000000000b';
    final program = Program(
      id: '019a0000-0000-7000-8000-0000000000a1',
      name: 'Getting stronger',
      perWeek: 3,
      rules: {bench: const AddWeight(step: 2.5)},
      sessions: const ['019a0000-0000-7000-8000-0000000000b1'],
      createdAt: DateTime.utc(2026, 10, 14),
    );
    final session = Template.fromJson({
      'id': '019a0000-0000-7000-8000-0000000000b1',
      'name': 'Day A',
      'order': 0,
      'programId': program.id,
    });

    Future<(Uri, Object?)> sent(String method) async {
      final captured = switch (method) {
        'POST' => verify(
          client.post(captureAny, headers: anyNamed('headers'), body: captureAnyNamed('body')),
        ).captured,
        'PUT' => verify(client.put(captureAny, headers: anyNamed('headers'), body: captureAnyNamed('body'))).captured,
        _ => [verify(client.delete(captureAny, headers: anyNamed('headers'))).captured.single, null],
      };
      return (
        captured.first as Uri,
        switch (captured.last) {
          final String body => jsonDecode(body),
          _ => null,
        },
      );
    }

    test('the list is read whole', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.programs,
        statusCode: 200,
        body: {
          'programs': [program.toMap()],
        },
      );

      final [read] = await api.getPrograms();

      expect(read.rules, {bench: const AddWeight(step: 2.5)});
      expect(read.sessions, program.sessions);
    });

    test('a create carries its sessions as templates, and says whether it made the program', () async {
      respond(client: client, method: 'POST', path: Router.programs, statusCode: 201, body: program.toMap());

      final (:row, :created) = await api.replayProgram(program, sessions: [session]);

      expect((row.id, created), (program.id, true));
      final (_, body as Map) = await sent('POST');
      expect(body['sessions'], [
        {...session.toMap()},
      ]);
      // the server owns these on a create
      expect(body.keys, isNot(containsAll(['archived', 'createdAt'])));
      expect(body['rules'], {
        bench: {'kind': 'addWeight', 'step': 2.5},
      });
    });

    test('a repeated create answers the program already there', () async {
      respond(client: client, method: 'POST', path: Router.programs, statusCode: 200, body: program.toMap());

      final (:row, :created) = await api.replayProgram(program, sessions: [session]);

      expect((row.id, created), (program.id, false));
    });

    test('deleting keeps the sessions only when asked to', () async {
      respond(
        client: client,
        method: 'DELETE',
        path: Router.program(program.id!),
        query: {'keepTemplates': 'true'},
        statusCode: 204,
        body: {},
      );

      await api.deleteProgram(program.id!, keepTemplates: true);

      final (uri, _) = await sent('DELETE');
      expect(uri.queryParameters, {'keepTemplates': 'true'});
    });

    test('taking a template out of its program spells the null out', () async {
      final detached = Template.fromJson({...session.toMap()..remove('programId')});
      respond(
        client: client,
        method: 'PUT',
        path: Router.template(session.id),
        statusCode: 200,
        body: detached.toMap(),
      );

      final saved = await api.setTemplateProgram(session, programId: null);

      expect(saved.programId, isNull);
      final (_, body as Map) = await sent('PUT');
      expect(body, containsPair('programId', null));
    });

    test('actions and bases post under their program', () async {
      final action = ProgramAction(
        id: '019a0000-0000-7000-8000-0000000000c1',
        programId: program.id,
        kind: .replay,
        week: 2,
        at: DateTime.utc(2026, 10, 14),
      );
      respond(
        client: client,
        method: 'POST',
        path: Router.programActions(program.id!),
        statusCode: 201,
        body: action.toMap(),
      );
      final (row: savedAction, created: _) = await api.replayProgramAction(action);
      expect((savedAction.kind, savedAction.week), (ProgramActionKind.replay, 2));

      final base = ProgramBase(
        id: '019a0000-0000-7000-8000-0000000000d1',
        programId: program.id,
        exerciseId: bench,
        value: 100,
        at: DateTime.utc(2026, 10, 14),
      );
      respond(
        client: client,
        method: 'POST',
        path: Router.programBases(program.id!),
        statusCode: 200,
        body: base.toMap(),
      );
      final (row: savedBase, :created) = await api.replayProgramBase(base);
      expect((savedBase.value, created), (100, false));
    });

    test('the named refusals are typed, anything else comes as it was', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.programs,
        statusCode: 400,
        body: {'error': 'bad request', 'code': 'program_limit', 'reason': 'at most 100'},
      );
      await expectLater(
        api.replayProgram(program, sessions: const []),
        throwsA(isA<ProgramRefused>().having((e) => e.reason, 'reason', ProgramRefusal.programLimit)),
      );

      respond(
        client: client,
        method: 'GET',
        path: Router.programActions(program.id!),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'program_not_found'},
      );
      await expectLater(
        api.getProgramActions(program.id!),
        throwsA(isA<ProgramRefused>().having((e) => e.reason, 'reason', ProgramRefusal.programNotFound)),
      );

      respond(client: client, method: 'GET', path: Router.programs, statusCode: 500, body: {'error': 'boom'});
      await expectLater(api.getPrograms(), throwsA(isA<Map>()));
    });
  });

  group('skips', () {
    Map<String, dynamic> skip(String id) {
      return {'id': id, 'at': '2026-10-03T07:00:00.000Z', 'templateId': 't2', 'programId': 'p1'};
    }

    test('a read follows every page, and a skip goes up safe to repeat (#312)', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.skips,
        query: {'limit': 100},
        statusCode: 200,
        body: {
          'skips': [skip('s2')],
          'cursor': 's2',
        },
      );
      respond(
        client: client,
        method: 'GET',
        path: Router.skips,
        query: {'limit': 100, 'cursor': 's2'},
        statusCode: 200,
        body: {
          'skips': [skip('s1')],
          'cursor': null,
        },
      );

      final skips = await api.getSkips();
      expect(skips.map((each) => (each.id, each.templateId, each.programId)), [
        ('s2', 't2', 'p1'),
        ('s1', 't2', 'p1'),
      ]);

      respond(client: client, method: 'POST', path: Router.skips, statusCode: 200, body: skip('s1'));
      final (:row, :created) = await api.replaySkip(TrainingSkip.fromJson(skip('s1')));
      expect((row.id, created), ('s1', false));
    });

    test('the cap is a typed refusal', () async {
      respond(client: client, method: 'POST', path: Router.skips, statusCode: 400, body: {'code': 'skip_limit'});
      await expectLater(
        api.replaySkip(TrainingSkip.fromJson(skip('s1'))),
        throwsA(isA<ProgramRefused>().having((e) => e.reason, 'reason', ProgramRefusal.skipLimit)),
      );
    });
  });
}
