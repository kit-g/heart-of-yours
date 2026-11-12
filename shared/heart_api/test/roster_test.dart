import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

/// A coach's roster and feed (#559), against what the server answered in
/// heart-api's own run of these routes.
void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  const connectionId = '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f';
  final sam = <String, dynamic>{
    'connectionId': connectionId,
    'studentId': 'StudentSamUid551191',
    'name': 'sam_551191',
    'status': 'active',
    'acceptedAt': '2026-11-07T21:05:34.981347Z',
    'programId': '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c',
    'programName': 'Strength block v2',
    'programWeek': 1,
    'programWeeks': 6,
    'recent': ['2026-11-07T20:15:36.267487Z', '2026-11-07T19:05:36.219752Z'],
    'lastTrainedAt': '2026-11-07T20:15:36.267487Z',
    'reasons': ['lighter', 'note'],
  };

  group('the roster', () {
    test('the first page asks nothing more, and reads every row with its reasons', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.coachClients,
        statusCode: 200,
        body: {
          'clients': [sam],
          'cursor': 'c1',
        },
      );

      final (:items, :cursor) = await api.getClients();

      expect(cursor, 'c1');
      final [client_] = items;
      expect(client_.name, 'sam_551191');
      expect(client_.programWeek, 1);
      expect(client_.recent, hasLength(2));
      expect(client_.reasons, ['lighter', 'note']);
    });

    test('a reason, the former ones and a cursor all go on the query', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.coachClients,
        query: {'reason': 'note', 'former': 'true', 'cursor': 'c1'},
        statusCode: 200,
        body: {'clients': []},
      );

      final (:items, :cursor) = await api.getClients(reason: 'note', former: true, cursor: 'c1');

      expect(items, isEmpty);
      expect(cursor, isNull);
    });

    test('a row this build cannot read costs that row, not the page', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.coachClients,
        statusCode: 200,
        body: {
          'clients': [
            sam,
            {'connectionId': 'x', 'studentId': 'y', 'status': 'active', 'recent': 'not a list'},
          ],
        },
      );

      final (:items, cursor: _) = await api.getClients();

      expect(items.map((each) => each.connectionId), [connectionId]);
    });

    test('a bad cursor is a refusal, thrown whole', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.coachClients,
        query: {'cursor': 'zzz'},
        statusCode: 400,
        body: {'error': 'bad request', 'code': 'invalid_cursor'},
      );

      expect(() => api.getClients(cursor: 'zzz'), throwsA(containsPair('code', 'invalid_cursor')));
    });
  });

  group('marking a client looked at', () {
    test('now sends nothing, a time sends it in UTC', () async {
      final path = Router.coachClientReviewed(connectionId);
      respond(client: client, method: 'PUT', path: path, statusCode: 204, body: {});

      await api.markReviewed(connectionId);
      await api.markReviewed(connectionId, at: DateTime.utc(2026, 11, 7, 21));

      final sent = verify(
        client.put(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured;
      expect(
        [for (final each in sent) jsonDecode(each as String)],
        [
          <String, dynamic>{},
          {'at': '2026-11-07T21:00:00.000Z'},
        ],
      );
    });

    test("someone else's connection is a 404, thrown whole", () async {
      final path = Router.coachClientReviewed('nobody');
      respond(client: client, method: 'PUT', path: path, statusCode: 404, body: {'code': 'not_found'});

      expect(() => api.markReviewed('nobody'), throwsA(containsPair('code', 'not_found')));
    });
  });

  test('the feed reads a skip without a title and a workout with one, and pages', () async {
    respond(
      client: client,
      method: 'GET',
      path: Router.coachFeed,
      query: {'cursor': 'c1'},
      statusCode: 200,
      body: {
        'items': [
          {
            'kind': 'skip',
            'id': '01a1b7d4-c1ed-7e23-9f63-5ed786b834fc',
            'studentId': 'StudentSamUid551191',
            'name': 'sam_551191',
            'at': '2026-11-07T21:05:36.237217Z',
          },
          {
            'kind': 'workout',
            'id': '01a1b7d4-c20b-758e-a558-3ff0360bd95b',
            'studentId': 'StudentSamUid551191',
            'name': 'sam_551191',
            'at': '2026-11-07T21:00:36.267495Z',
            'title': 'Day B, in the gym with Dana',
          },
        ],
        'cursor': 'c2',
      },
    );

    final (:items, :cursor) = await api.getCoachFeed(cursor: 'c1');

    expect(items.map((each) => (each.kind, each.title)), [('skip', null), ('workout', 'Day B, in the gym with Dana')]);
    expect(cursor, 'c2');
  });

  group("a client's own record", () {
    const studentId = 'StudentSamUid551191';
    const workoutId = '01a1b7d4-c1db-7eba-8005-c926c367acf8';

    test('their workouts page by cursor, with their notes', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.clientWorkouts(studentId),
        query: {'cursor': 'w1'},
        statusCode: 200,
        body: {
          'workouts': [
            {
              'id': workoutId,
              'name': 'Day A',
              'start': '2026-11-07T19:05:36.219752Z',
              'end': '2026-11-07T20:05:36.219838Z',
              'note': 'Last set was a grind',
              'pauses': [],
              'programId': '01a1b7d4-bd28-7e4b-9307-80fbe12ecd6c',
              'exercises': [],
              'images': [],
            },
          ],
          'cursor': 'w2',
        },
      );

      final (:items, :cursor) = await api.getClientWorkouts(studentId, cursor: 'w1');

      expect(items.single.note, 'Last set was a grind');
      expect(cursor, 'w2');
    });

    test('their skips say when, never why', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.clientSkips(studentId),
        statusCode: 200,
        body: {
          'skips': [
            {'id': 's1', 'at': '2026-11-07T21:05:36.237217Z', 'programId': 'p1'},
          ],
        },
      );

      final [skip] = await api.getClientSkips(studentId);

      expect(skip.programId, 'p1');
      expect(skip.reason, isNull);
    });

    test("a workout's plan, and none for a workout without one", () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.clientWorkoutPlan(studentId, workoutId),
        statusCode: 200,
        body: {
          'plan': {
            'exercises': [
              {
                'sets': [
                  {'setId': 's1', 'weight': 110},
                ],
              },
            ],
          },
        },
      );
      expect((await api.getClientWorkoutPlan(studentId, workoutId))?.plan['exercises'], hasLength(1));

      respond(
        client: client,
        method: 'GET',
        path: Router.clientWorkoutPlan(studentId, 'w-none'),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'not_found', 'message': 'Plan #w-none not found'},
      );
      expect(await api.getClientWorkoutPlan(studentId, 'w-none'), isNull);
    });

    test('an ended connection is refused whole', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.clientWorkouts(studentId),
        statusCode: 403,
        body: {
          'error': 'forbidden',
          'code': 'forbidden',
          'reason': 'You do not have permission to view these workouts.',
        },
      );

      expect(api.getClientWorkouts(studentId), throwsA(containsPair('code', 'forbidden')));
    });
  });
}
