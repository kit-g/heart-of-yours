import 'dart:convert';

import 'package:heart_api/src/api.dart';
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

  Object? sentBy(String path) {
    final sent = verify(
      client.post(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
    ).captured.single;
    return jsonDecode(sent as String);
  }

  group('devices (#567)', () {
    test('registerDevice sends the token, the platform and the offset', () async {
      respond(client: client, method: 'POST', path: Router.devices, statusCode: 204, body: {});

      await api.registerDevice(platform: .ios, token: 'fcm-token', utcOffsetMinutes: -300);

      expect(sentBy(Router.devices), {
        'platform': 'ios',
        'token': 'fcm-token',
        'settings': <String, dynamic>{},
        'utcOffsetMinutes': -300,
      });
    });

    test('registerDevice leaves out an offset it does not have', () async {
      respond(client: client, method: 'POST', path: Router.devices, statusCode: 204, body: {});

      await api.registerDevice(platform: .android, token: 'fcm-token');

      expect(sentBy(Router.devices), {'platform': 'android', 'token': 'fcm-token', 'settings': <String, dynamic>{}});
    });

    test('registerDevice throws a refusal whole', () async {
      const refusal = {'error': 'bad request', 'code': 'bad_request', 'reason': 'platform has an invalid value'};
      respond(client: client, method: 'POST', path: Router.devices, statusCode: 400, body: refusal);

      expect(api.registerDevice(platform: .web, token: 't'), throwsA(refusal));
    });

    test('unregisterDevice sends the token as registered (heart-api#415)', () async {
      respond(client: client, method: 'POST', path: Router.deviceRemovals, statusCode: 204, body: {});

      await api.unregisterDevice('fcm-token');

      expect(sentBy(Router.deviceRemovals), {'token': 'fcm-token'});
    });

    test('unregisterDevice throws a refusal whole', () async {
      const refusal = {'error': 'bad request', 'code': 'bad_request', 'reason': 'token is required'};
      respond(client: client, method: 'POST', path: Router.deviceRemovals, statusCode: 400, body: refusal);

      expect(api.unregisterDevice(''), throwsA(refusal));
    });
  });

  group('push settings (#554)', () {
    test('getPushSettings reads the catalog and the answers for people', () async {
      // what the server answered in heart-api's own run of the route
      respond(
        client: client,
        method: 'GET',
        path: Router.pushSettings,
        statusCode: 200,
        body: {
          'topics': [
            {
              'topic': 'coaching.message',
              'group': 'coaching',
              'name': 'Messages',
              'description': 'When someone you train with writes to you',
              'delivery': 'instant',
              'options': ['instant', 'off'],
              'perPersonAs': ['coach', 'student', 'peer'],
            },
          ],
          'forPeople': [
            {'topic': 'coaching.message', 'connectionId': '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f', 'delivery': 'off'},
          ],
        },
      );

      final settings = await api.getPushSettings();

      expect(settings.topics.single.topic, 'coaching.message');
      expect(settings.topics.single.options, ['instant', 'off']);
      expect(settings.topics.single.perPersonAs, ['coach', 'student', 'peer']);
      expect(settings.forPeople.single.connectionId, '01a1b7d4-bd0d-7eec-a569-2bc08ea3787f');
    });

    test('setPushSetting sends the delivery, and the person when there is one', () async {
      final path = Router.pushSetting('coaching.message');
      respond(client: client, method: 'PUT', path: path, statusCode: 204, body: {});

      await api.setPushSetting('coaching.message', 'off', connectionId: 'c1');
      await api.setPushSetting('coaching.message', 'instant');

      final sent = verify(
        client.put(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured;
      expect(sent.map((each) => jsonDecode(each as String)), [
        {'delivery': 'off', 'connectionId': 'c1'},
        {'delivery': 'instant'},
      ]);
    });

    test('setPushSetting throws the refusal whole', () async {
      const refusal = {
        'error': 'bad request',
        'code': 'invalid_delivery',
        'reason': 'coaching.message can be instant, off',
      };
      respond(
        client: client,
        method: 'PUT',
        path: Router.pushSetting('coaching.message'),
        statusCode: 400,
        body: refusal,
      );

      expect(api.setPushSetting('coaching.message', 'daily'), throwsA(refusal));
    });

    test('clearPushSetting names the person in the query', () async {
      final path = Router.pushSetting('coaching.message');
      respond(client: client, method: 'DELETE', path: path, statusCode: 204, body: {}, query: {'connectionId': 'c1'});
      respond(client: client, method: 'DELETE', path: path, statusCode: 204, body: {});

      await api.clearPushSetting('coaching.message', connectionId: 'c1');
      await api.clearPushSetting('coaching.message');

      verify(client.delete(Uri.https('api.example.com', path, {'connectionId': 'c1'}), headers: anyNamed('headers')));
      verify(client.delete(Uri.https('api.example.com', path), headers: anyNamed('headers')));
    });

    test('a topic that is not the server\'s shape never reaches a path', () {
      expect(() => Router.pushSetting('../accounts'), throwsArgumentError);
      expect(() => Router.pushSetting(''), throwsArgumentError);
      expect(Router.pushSetting('coaching.workout_digest'), 'v1/push/settings/coaching.workout_digest');
    });
  });
}
