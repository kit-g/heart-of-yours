import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

const _connectionId = '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f';
const _noteId = '01a1b7d4-bf38-7301-b458-4d1ee7dae674';

/// A note as heart-api's own run of the route answered it.
Map<String, dynamic> _note({String content = 'b3BhcXVl'}) => {
  'id': _noteId,
  'connectionId': _connectionId,
  'content': content,
  'updatedAt': '2026-11-07T21:05:35.547186Z',
};

/// A coach's notes (#556): ciphertext in, ciphertext out, refusals whole.
void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  test('saveNote puts the sealed words under the device\'s id', () async {
    respond(client: client, method: 'PUT', path: Router.note(_noteId), statusCode: 200, body: _note());

    final note = await api.saveNote(_noteId, connectionId: _connectionId, content: 'b3BhcXVl');

    expect(note.id, _noteId);
    expect(note.updatedAt, DateTime.utc(2026, 11, 7, 21, 5, 35, 547, 186));
    final sent = verify(
      client.put(
        Uri.https('api.example.com', Router.note(_noteId)),
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
      ),
    ).captured.single;
    expect(jsonDecode(sent as String), {'connectionId': _connectionId, 'content': 'b3BhcXVl'});
  });

  test('saveNote throws the refusal whole', () async {
    respond(
      client: client,
      method: 'PUT',
      path: Router.note(_noteId),
      statusCode: 404,
      body: {'error': 'not found', 'code': 'not_found', 'message': 'Connection #x not found'},
    );

    expect(
      api.saveNote(_noteId, connectionId: _connectionId, content: 'abc'),
      throwsA(refused('not_found')),
    );
  });

  test('getNotes reads a page, with the cursor to the next', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.notes,
      query: {'connectionId': _connectionId, 'cursor': 'c1'},
      statusCode: 200,
      body: {
        'notes': [_note()],
        'cursor': 'c2',
      },
    );

    final page = await api.getNotes(connectionId: _connectionId, cursor: 'c1');

    expect(page.notes.single.content, 'b3BhcXVl');
    expect(page.cursor, 'c2');
  });

  test('getNotes without a cursor is the last page', () async {
    respond(client: client, method: 'GET', path: Router.notes, statusCode: 200, body: {'notes': []});

    final page = await api.getNotes();

    expect(page.notes, isEmpty);
    expect(page.cursor, isNull);
  });

  test('deleteNote deletes one', () async {
    respond(client: client, method: 'DELETE', path: Router.note(_noteId), statusCode: 204, body: {});

    await api.deleteNote(_noteId);

    verify(client.delete(Uri.https('api.example.com', Router.note(_noteId)), headers: anyNamed('headers')));
  });

  test('deleteNote throws a refusal, so a note already gone is told apart', () async {
    respond(
      client: client,
      method: 'DELETE',
      path: Router.note(_noteId),
      statusCode: 404,
      body: {'error': 'not found', 'code': 'not_found', 'message': 'Note #x not found'},
    );

    expect(api.deleteNote(_noteId), throwsA(refused('not_found')));
  });
}
