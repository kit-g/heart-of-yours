import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

const _connectionId = '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f';
const _threadId = '01a1b7d4-be57-7a8e-aad3-42e570245e85';
const _itemId = '01a1b7d4-be62-7542-9be9-6fedfe6de62a';

/// An item as heart-api's own run of the route answered it.
Map<String, dynamic> _item({String? cursor}) => {
  'id': _itemId,
  'threadId': _threadId,
  'senderId': 'CoachDanaUid551191',
  'kind': 'message',
  'content': 'b3BhcXVl',
  'commitment': '3MzaZHhlPgCHV0EbLjJa9EQQVFptgwOEbh7pOAs6QgM=',
  'tag': 'ecP07Dp2C+qXMIHrXFg61rG4zmmxJbj3h/InkRXixMs=',
  'tagKey': 'k2026a',
  'at': '2026-11-07T21:05:35.330669Z',
  'createdAt': '2026-11-07T21:05:35.334Z',
  'cursor': ?cursor,
};

/// The thread routes (#556): ciphertext in, ciphertext out, refusals whole.
void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  test('openThread opens the connection\'s one thread', () async {
    respond(
      client: client,
      method: 'POST',
      path: Router.connectionThread(_connectionId),
      statusCode: 200,
      body: {
        'id': _threadId,
        'connectionId': _connectionId,
        'otherId': 'StudentSamUid551191',
        'otherName': 'sam_551191',
        'unread': 0,
      },
    );

    final thread = await api.openThread(_connectionId);

    expect(thread.id, _threadId);
    expect(thread.otherName, 'sam_551191');
  });

  test('getThreads reads the inbox, cleared threads too', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.threads,
      statusCode: 200,
      body: {
        'threads': [
          {
            'id': _threadId,
            'connectionId': _connectionId,
            'otherId': 'sam',
            'unread': 1,
            'lastAt': '2026-11-07T21:05:35.355Z',
          },
          {'id': 'other', 'unread': 0, 'clearedAt': '2026-11-07T21:05:36.985488Z', 'clearedBy': 'sam'},
        ],
        'unread': 1,
      },
    );

    final threads = await api.getThreads();

    expect(threads.map((each) => each.id), [_threadId, 'other']);
    expect(threads.first.unread, 1);
    expect(threads.last.clearedBy, 'sam');
  });

  test('getThreads reads the inbox whole or not at all: it replaces the one on the device', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.threads,
      statusCode: 200,
      body: {
        'threads': [
          {'id': _threadId, 'unread': 0},
          {'id': 'unreadable', 'unread': 'many'},
        ],
      },
    );

    await expectLater(api.getThreads(), throwsA(anything));
  });

  test('postThreadItem sends a message with its commitment, and reads back the server\'s tag', () async {
    respond(client: client, method: 'POST', path: Router.threadItems(_threadId), statusCode: 201, body: _item());

    final item = await api.postThreadItem(
      _threadId,
      id: _itemId,
      content: 'b3BhcXVl',
      commitment: '3MzaZHhlPgCHV0EbLjJa9EQQVFptgwOEbh7pOAs6QgM=',
      at: DateTime.utc(2026, 11, 7, 21, 5, 35),
    );

    final sent = verify(
      client.post(
        Uri.https('api.example.com', Router.threadItems(_threadId)),
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
      ),
    ).captured.single;
    expect(jsonDecode(sent as String), {
      'id': _itemId,
      'kind': 'message',
      'content': 'b3BhcXVl',
      'commitment': '3MzaZHhlPgCHV0EbLjJa9EQQVFptgwOEbh7pOAs6QgM=',
      'at': '2026-11-07T21:05:35.000Z',
    });
    expect((item.tag, item.tagKey), ('ecP07Dp2C+qXMIHrXFg61rG4zmmxJbj3h/InkRXixMs=', 'k2026a'));
  });

  test('a retry of the same id answers 200 with the stored item', () async {
    respond(client: client, method: 'POST', path: Router.threadItems(_threadId), statusCode: 200, body: _item());

    final item = await api.postThreadItem(_threadId, id: _itemId, content: 'x', commitment: 'y', at: DateTime.now());

    expect(item.id, _itemId);
  });

  test('a closed thread and a rate limit are thrown whole', () async {
    const closed = {
      'error': 'forbidden',
      'code': 'thread_closed',
      'reason': 'This thread takes no new messages from you.',
    };
    respond(client: client, method: 'POST', path: Router.threadItems(_threadId), statusCode: 403, body: closed);

    expect(
      api.postThreadItem(_threadId, id: _itemId, content: 'x', commitment: 'y', at: DateTime.now()),
      throwsA(closed),
    );
  });

  test('getThreadItems reads a page since a cursor, with the page\'s own cursor when more follow', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.threadItems(_threadId),
      query: {'since': 'c0', 'limit': '50'},
      statusCode: 200,
      body: {
        'items': [_item(cursor: 'c1')],
        'cursor': 'c1',
      },
    );

    final page = await api.getThreadItems(_threadId, since: 'c0', limit: 50);

    expect(page.items.single.cursor, 'c1');
    expect(page.cursor, 'c1');
  });

  test('getThreadItems without a cursor asks for the newest, and a last page has none', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.threadItems(_threadId),
      statusCode: 200,
      body: {'items': <Object>[]},
    );

    final page = await api.getThreadItems(_threadId);

    expect(page.items, isEmpty);
    expect(page.cursor, isNull);
  });

  test('markThreadRead sends the cursor', () async {
    respond(client: client, method: 'PUT', path: Router.threadRead(_threadId), statusCode: 204, body: {});

    await api.markThreadRead(_threadId, 'c1');

    final sent = verify(
      client.put(
        Uri.https('api.example.com', Router.threadRead(_threadId)),
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
      ),
    ).captured.single;
    expect(jsonDecode(sent as String), {'cursor': 'c1'});
  });

  test('clearThread deletes the conversation for both', () async {
    respond(client: client, method: 'DELETE', path: Router.threadItems(_threadId), statusCode: 204, body: {});

    await api.clearThread(_threadId);

    verify(client.delete(Uri.https('api.example.com', Router.threadItems(_threadId)), headers: anyNamed('headers')));
  });

  test('fileReport sends the person, the reason, and each message with its proof', () async {
    respond(client: client, method: 'POST', path: Router.reports, statusCode: 204, body: {});

    await api.fileReport(
      reportedId: 'CoachDanaUid551191',
      connectionId: _connectionId,
      reason: 'harassment',
      messages: [
        (
          words: 'words',
          key: 'k',
          commitment: 'c',
          tag: 't',
          tagKey: 'k2026a',
          senderId: 'CoachDanaUid551191',
          recipientId: 'StudentSamUid551191',
          createdAt: DateTime.utc(2026, 11, 7, 21, 5, 35),
        ),
      ],
    );

    final sent = verify(
      client.post(
        Uri.https('api.example.com', Router.reports),
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
      ),
    ).captured.single;
    expect(jsonDecode(sent as String), {
      'reportedId': 'CoachDanaUid551191',
      'connectionId': _connectionId,
      'reason': 'harassment',
      'messages': [
        {
          'words': 'words',
          'key': 'k',
          'commitment': 'c',
          'tag': 't',
          'tagKey': 'k2026a',
          'senderId': 'CoachDanaUid551191',
          'recipientId': 'StudentSamUid551191',
          'createdAt': '2026-11-07T21:05:35.000Z',
        },
      ],
    });
  });

  test('a stale cursor is thrown whole', () async {
    const stale = {'error': 'bad request', 'code': 'stale_cursor', 'reason': 'read again without it'};
    respond(client: client, method: 'PUT', path: Router.threadRead(_threadId), statusCode: 400, body: stale);

    expect(api.markThreadRead(_threadId, 'garbage'), throwsA(stale));
  });
}
