import 'dart:convert';

import 'package:heart_api/src/api.dart';
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

  group('connections (#552)', () {
    // what the server answered in heart-api's own run of these routes
    final coach = <String, dynamic>{
      'targetId': 'CoachDanaUid551191',
      'role': 'student',
      'domain': 'fitness',
      'status': 'active',
      'createdAt': '2026-11-07T21:05:34.981347Z',
      'connectionId': '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f',
      'acceptedAt': '2026-11-07T21:05:34.981347Z',
      'shares': ['history'],
    };
    const id = '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f';

    test('getConnections reads the id every route takes, the acceptance and the shares', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.connections,
        statusCode: 200,
        body: {
          'connections': [coach],
        },
      );

      final connection = (await api.getConnections()).single;

      expect(connection.connectionId, '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f');
      expect(connection.role, ConnectionRole.student);
      expect(connection.domain, ConnectionDomain.fitness);
      expect(connection.status, ConnectionStatus.active);
      expect(connection.acceptedAt, DateTime.parse('2026-11-07T21:05:34.981347Z'));
      expect(connection.shares, ['history']);
    });

    test('getConnections drops a connection this build cannot read and keeps the rest', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.connections,
        statusCode: 200,
        body: {
          'connections': [
            {...coach, 'domain': 'climbing'},
            coach,
          ],
        },
      );
      expect((await api.getConnections()).single.domain, ConnectionDomain.fitness);
    });

    test('setConnectionShares sends the whole list and reads the connection back', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.connectionShares(id),
        statusCode: 200,
        body: {
          ...coach,
          'shares': ['history', 'goals'],
        },
      );

      final connection = await api.setConnectionShares(id, {'history', 'goals'});

      expect(connection.shares, ['history', 'goals']);
      final sent = verify(
        client.put(
          Uri.https('api.example.com', Router.connectionShares(id)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {
        'shares': ['history', 'goals'],
      });
    });

    test("setConnectionShares throws the coach's refusal whole", () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.connectionShares(id),
        statusCode: 403,
        body: {
          'error': 'forbidden',
          'code': 'forbidden',
          'reason': 'Only the student of a live coaching connection chooses what it shares.',
        },
      );
      expect(api.setConnectionShares(id, {'history'}), throwsA(containsPair('code', 'forbidden')));
    });

    test('setConnectionStatus sends the status by name', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.connection(id),
        statusCode: 200,
        body: {
          ...coach,
          'status': 'paused',
        },
      );

      expect((await api.setConnectionStatus(id, .paused)).status, ConnectionStatus.paused);
      final sent = verify(
        client.put(
          Uri.https('api.example.com', Router.connection(id)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'status': 'paused'});
    });

    test('endConnection is a 204', () async {
      respond(client: client, method: 'DELETE', path: Router.connection(id), statusCode: 204, body: {});
      await api.endConnection(id);
    });

    test('hiding, listing and unhiding a workout', () async {
      const workoutId = '01a1b7d4-c1db-7eba-8005-c926c367acf8';
      final at = DateTime.utc(2026, 11, 7, 21, 5, 36);
      respond(client: client, method: 'PUT', path: Router.workoutHidden(workoutId), statusCode: 204, body: {});
      respond(client: client, method: 'DELETE', path: Router.workoutHidden(workoutId), statusCode: 204, body: {});
      respond(
        client: client,
        method: 'GET',
        path: Router.hiddenWorkouts,
        statusCode: 200,
        body: {
          'workouts': [
            {'id': workoutId, 'at': '2026-11-07T21:05:36.378380Z'},
          ],
        },
      );

      await api.hideWorkout(workoutId, at: at);
      final sent = verify(
        client.put(
          Uri.https('api.example.com', Router.workoutHidden(workoutId)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'at': '2026-11-07T21:05:36.000Z'});

      expect((await api.getHiddenWorkouts()).single.id, workoutId);
      await api.unhideWorkout(workoutId);
    });

    test('hiding an unknown workout throws the 404 whole', () async {
      const workoutId = '01a1b7d4-c280-7e72-aabf-db3af0b7e145';
      respond(
        client: client,
        method: 'PUT',
        path: Router.workoutHidden(workoutId),
        statusCode: 404,
        body: {
          'error': 'not found',
          'code': 'not_found',
          'message': 'Workout #$workoutId not found',
        },
      );
      expect(api.hideWorkout(workoutId), throwsA(containsPair('code', 'not_found')));
    });
  });
}
