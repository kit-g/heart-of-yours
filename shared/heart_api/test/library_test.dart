import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

/// A coach's library and sending (#557), against what the server answered in
/// heart-api's own run of these routes.
void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  const programId = '01a1b7d4-bc29-70bb-866b-6549c07024bf';
  const connectionId = '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f';
  final body = <String, dynamic>{
    'name': 'Strength block',
    'note': 'Four weeks, two days a week',
    'weeks': 4,
    'perWeek': 2,
    'sessions': [
      {
        'id': '01a1b7d4-bc59-7ad7-9994-c01207b8fb92',
        'name': 'Day A',
        'exercises': [
          {
            'id': '01a1b7d4-bc59-7012-afde-89362ab6aca6',
            'exercise': '01a1b7d4-bc15-7c90-8607-4d602129522a',
            'sets': [
              {'id': '01a1b7d4-bc59-79c7-9550-874a8fd0647e', 'reps': 5, 'weight': 100},
            ],
          },
        ],
      },
    ],
  };
  final saved = <String, dynamic>{
    'id': programId,
    'name': 'Strength block',
    'version': 1,
    'body': body,
    'updatedAt': '2026-11-07T21:05:34.812995Z',
  };

  test('the library reads a page without bodies, and its cursor', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.libraryPrograms,
      statusCode: 200,
      body: {
        'programs': [
          {...saved}..remove('body'),
        ],
        'cursor': 'c1',
      },
    );

    final (:items, :cursor) = await api.getLibraryPrograms();

    expect(cursor, 'c1');
    final [program] = items;
    expect(program.name, 'Strength block');
    expect(program.version, 1);
    expect(program.body, isNull);
  });

  test('the next page goes by the cursor, and a bad one is thrown whole', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.libraryPrograms,
      query: {'cursor': 'abc'},
      statusCode: 400,
      body: {'error': 'bad request', 'code': 'bad_request'},
    );

    expect(() => api.getLibraryPrograms(cursor: 'abc'), throwsA(containsPair('code', 'bad_request')));
  });

  test('one program comes with its body', () async {
    respond(client: client, method: 'GET', path: Router.libraryProgram(programId), statusCode: 200, body: saved);

    final program = await api.getLibraryProgram(programId);

    expect(program.body?['sessions'], hasLength(1));
  });

  test("someone else's is a 404, thrown whole", () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.libraryProgram(programId),
      statusCode: 404,
      body: {'code': 'not_found'},
    );

    expect(() => api.getLibraryProgram(programId), throwsA(containsPair('code', 'not_found')));
  });

  test('a save sends the body as it is, and reads the new version back', () async {
    final path = Router.libraryProgram(programId);
    respond(client: client, method: 'PUT', path: path, statusCode: 200, body: {...saved, 'version': 2});

    final program = await api.saveLibraryProgram(programId, body);

    expect(program.version, 2);
    final [sent] = verify(
      client.put(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
    ).captured;
    expect(jsonDecode(sent as String), body);
  });

  test('an id that is taken is a refusal, thrown whole', () async {
    respond(
      client: client,
      method: 'PUT',
      path: Router.libraryProgram(programId),
      statusCode: 403,
      body: {'error': 'forbidden', 'code': 'id_taken'},
    );

    expect(() => api.saveLibraryProgram(programId, body), throwsA(containsPair('code', 'id_taken')));
  });

  test('a delete is a 204, and anything else is thrown', () async {
    respond(client: client, method: 'DELETE', path: Router.libraryProgram(programId), statusCode: 204, body: {});
    respond(
      client: client,
      method: 'DELETE',
      path: Router.libraryProgram('nope'),
      statusCode: 404,
      body: {'code': 'not_found'},
    );

    await api.deleteLibraryProgram(programId);
    expect(() => api.deleteLibraryProgram('nope'), throwsA(containsPair('code', 'not_found')));
  });

  test('holders say who has which version', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.libraryHolders(programId),
      statusCode: 200,
      body: {
        'holders': [
          {
            'connectionId': connectionId,
            'studentId': 'StudentSamUid551191',
            'studentName': 'sam_551191',
            'programId': '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c',
            'version': 1,
          },
        ],
      },
    );

    final [holder] = await api.getLibraryHolders(programId);

    expect(holder.connectionId, connectionId);
    expect(holder.version, 1);
  });

  test('a send names the connections, and each answers on its own', () async {
    final path = Router.librarySend(programId);
    respond(
      client: client,
      method: 'POST',
      path: path,
      statusCode: 200,
      body: {
        'deliveries': [
          {'connectionId': connectionId, 'delivered': true, 'programId': '01a1b7d4-c17b-7362-a30e-3d5111911397'},
          {'connectionId': '01a1b7d4-c16f-7ba7-bc05-56e59722e12d', 'delivered': false, 'reason': 'not_coaching'},
        ],
      },
    );

    final deliveries = await api.sendLibraryProgram(programId, [connectionId, '01a1b7d4-c16f-7ba7-bc05-56e59722e12d']);

    expect([for (final each in deliveries) (each.delivered, each.reason)], [(true, null), (false, 'not_coaching')]);
    final [sent] = verify(
      client.post(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
    ).captured;
    expect(jsonDecode(sent as String), {
      'connectionIds': [connectionId, '01a1b7d4-c16f-7ba7-bc05-56e59722e12d'],
    });
  });
}
