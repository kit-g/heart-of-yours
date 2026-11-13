import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

// what the server answered in heart-api's own run of the routes (#555)
const _deviceId = '01a1b7d4-bdd4-7e28-a0cd-b45015ff37b3';
const _device = {
  'id': _deviceId,
  'userId': 'CoachDanaUid551191',
  'identityKey': 'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA=',
  'signingKey': 'AgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4fICE=',
  'fallbackKey': 'AwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISI=',
  'createdAt': '2026-11-07T21:05:35.192711Z',
};

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  List<Object?> sentTo(String path) {
    return verify(
      client.post(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
    ).captured.map((body) => jsonDecode(body as String)).toList();
  }

  group('devices', () {
    test('publishCryptoDevice sends the three public keys and reads the device back', () async {
      respond(client: client, method: 'POST', path: Router.cryptoDevices, statusCode: 201, body: _device);

      final device = await api.publishCryptoDevice(
        id: _deviceId,
        identityKey: _device['identityKey']!,
        signingKey: _device['signingKey']!,
        fallbackKey: _device['fallbackKey']!,
      );

      expect(sentTo(Router.cryptoDevices).single, {
        'id': _deviceId,
        'identityKey': _device['identityKey'],
        'signingKey': _device['signingKey'],
        'fallbackKey': _device['fallbackKey'],
      });
      expect(device.id, _deviceId);
      expect(device.vouchedBy, isNull);
    });

    test('publishCryptoDevice sends a vouch as its two halves', () async {
      respond(client: client, method: 'POST', path: Router.cryptoDevices, statusCode: 201, body: _device);

      await api.publishCryptoDevice(
        id: _deviceId,
        identityKey: 'i',
        signingKey: 's',
        fallbackKey: 'f',
        vouch: (signature: 'sig', vouchedBy: '01a1b7d4-bdd4-7b14-8b15-d5542d2c416f'),
      );

      expect(sentTo(Router.cryptoDevices).single, {
        'id': _deviceId,
        'identityKey': 'i',
        'signingKey': 's',
        'fallbackKey': 'f',
        'signature': 'sig',
        'vouchedBy': '01a1b7d4-bdd4-7b14-8b15-d5542d2c416f',
      });
    });

    test('publishCryptoDevice throws a removed device whole', () async {
      const refusal = {'error': 'forbidden', 'code': 'device_removed', 'reason': 'this device was removed'};
      respond(client: client, method: 'POST', path: Router.cryptoDevices, statusCode: 403, body: refusal);

      expect(
        api.publishCryptoDevice(id: _deviceId, identityKey: 'i', signingKey: 's', fallbackKey: 'f'),
        throwsA(refusal),
      );
    });

    test("getCryptoDevices reads the account's own, and someone's by id", () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.cryptoDevices,
        statusCode: 200,
        body: {
          'devices': [_device],
        },
      );
      respond(
        client: client,
        method: 'GET',
        path: Router.cryptoDevices,
        query: {'userId': 'CoachDanaUid551191'},
        statusCode: 200,
        body: {
          'devices': [_device, _device],
        },
      );

      expect(await api.getCryptoDevices(), hasLength(1));
      expect(await api.getCryptoDevices(userId: 'CoachDanaUid551191'), hasLength(2));
    });

    test('vouchForCryptoDevice sends the vouch and reads the device back', () async {
      const voucher = '01a1b7d4-bdd4-7b14-8b15-d5542d2c416f';
      final vouched = {..._device, 'signature': 'sig', 'vouchedBy': voucher};
      respond(client: client, method: 'PUT', path: Router.cryptoDeviceVouch(_deviceId), statusCode: 200, body: vouched);

      final device = await api.vouchForCryptoDevice(_deviceId, vouchedBy: voucher, signature: 'sig');

      final sent = verify(
        client.put(
          Uri.https('api.example.com', 'v1/keys/devices/$_deviceId/vouch'),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'vouchedBy': voucher, 'signature': 'sig'});
      expect((device.vouchedBy, device.signature), (voucher, 'sig'));
    });

    for (final (status, refusal) in [
      (409, {'error': 'conflict', 'code': 'already_vouched', 'reason': 'this device is already vouched for'}),
      (404, {'error': 'not found', 'code': 'not_found'}),
      (400, {'error': 'bad request', 'code': 'bad_request', 'reason': 'vouchedBy must be another device of yours'}),
    ]) {
      test('vouchForCryptoDevice throws a $status whole', () async {
        respond(
          client: client,
          method: 'PUT',
          path: Router.cryptoDeviceVouch(_deviceId),
          statusCode: status,
          body: refusal,
        );

        expect(api.vouchForCryptoDevice(_deviceId, vouchedBy: _deviceId, signature: 's'), throwsA(refusal));
      });
    }

    test('removeCryptoDevice deletes the device', () async {
      respond(client: client, method: 'DELETE', path: Router.cryptoDevice(_deviceId), statusCode: 204, body: {});

      await api.removeCryptoDevice(_deviceId);

      verify(client.delete(Uri.https('api.example.com', 'v1/keys/devices/$_deviceId'), headers: anyNamed('headers')));
    });

    test('a device id that is not a UUID never reaches a path', () {
      expect(() => Router.cryptoDevice('../accounts'), throwsArgumentError);
      expect(() => Router.keyClaims('a/../b'), throwsArgumentError);
    });
  });

  group('one-time keys', () {
    test('addOneTimeKeys sends the keys as a list of id and key, and answers the count', () async {
      respond(client: client, method: 'POST', path: Router.oneTimeKeys(_deviceId), statusCode: 200, body: {'count': 3});

      // an id the server's health guard would refuse as a field name
      final count = await api.addOneTimeKeys(_deviceId, {'AAAAAQ': 'k1', 'xHRVq': 'k2', 'sleepA': 'k3'});

      expect(count, 3);
      expect(sentTo(Router.oneTimeKeys(_deviceId)).single, {
        'keys': [
          {'id': 'AAAAAQ', 'key': 'k1'},
          {'id': 'xHRVq', 'key': 'k2'},
          {'id': 'sleepA', 'key': 'k3'},
        ],
      });
    });

    test('countOneTimeKeys reads the count', () async {
      respond(client: client, method: 'GET', path: Router.oneTimeKeys(_deviceId), statusCode: 200, body: {'count': 7});

      expect(await api.countOneTimeKeys(_deviceId), 7);
    });

    test('replaceFallbackKey puts the new key', () async {
      respond(client: client, method: 'PUT', path: Router.fallbackKey(_deviceId), statusCode: 204, body: {});

      await api.replaceFallbackKey(_deviceId, 'new');

      final sent = verify(
        client.put(
          Uri.https('api.example.com', Router.fallbackKey(_deviceId)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'key': 'new'});
    });
  });

  group('claims', () {
    test('claimKeys reads a device with its one-time key, and one with only its fallback', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.keyClaims('CoachDanaUid551191'),
        statusCode: 200,
        body: {
          'devices': [
            _device,
            {..._device, 'oneTimeKeyId': 'otk-1', 'oneTimeKey': 'FRYX'},
          ],
        },
      );

      final [fallback, oneTime] = await api.claimKeys('CoachDanaUid551191');

      expect(fallback.oneTimeKey, isNull);
      expect(oneTime.oneTimeKeyId, 'otk-1');
      expect(oneTime.oneTimeKey, 'FRYX');
    });

    test('claimKeys names the devices to claim from, and sends no names without them (heart-api#424)', () async {
      final path = Router.keyClaims('CoachDanaUid551191');
      respond(client: client, method: 'POST', path: path, statusCode: 200, body: {'devices': []});

      await api.claimKeys('CoachDanaUid551191', deviceIds: ['d1', 'd2']);
      await api.claimKeys('CoachDanaUid551191');

      final sent = verify(
        client.post(Uri.https('api.example.com', path), headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured;
      expect(sent.map((each) => jsonDecode(each as String)), [
        {
          'deviceIds': ['d1', 'd2'],
        },
        <String, dynamic>{},
      ]);
    });

    test('claimKeys refuses a claim naming none, or more than ten', () async {
      await expectLater(api.claimKeys('CoachDanaUid551191', deviceIds: []), throwsArgumentError);
      await expectLater(
        api.claimKeys('CoachDanaUid551191', deviceIds: List.generate(11, (index) => 'd$index')),
        throwsArgumentError,
      );
    });

    test('claimKeys throws the rate limit whole, with when to try again', () async {
      const refusal = {
        'error': 'too many requests',
        'code': 'rate_limited',
        'reason': 'too many key requests for this person',
        'retryAfter': 3600,
      };
      respond(
        client: client,
        method: 'POST',
        path: Router.keyClaims('CoachDanaUid551191'),
        statusCode: 429,
        body: refusal,
      );

      expect(api.claimKeys('CoachDanaUid551191'), throwsA(refusal));
    });
  });

  group('the queue', () {
    test('enqueueKeyItem sends one item', () async {
      respond(client: client, method: 'POST', path: Router.keyQueue, statusCode: 204, body: {});

      await api.enqueueKeyItem(
        id: '01a1b7d4-be25-722b-ac65-6b8b662069e7',
        recipientDeviceId: _deviceId,
        senderDeviceId: '01a1b7d4-bdd4-7877-bb95-22ef017880bf',
        kind: 'session_key',
        content: 'c2VhbGVk',
      );

      expect(sentTo(Router.keyQueue).single, {
        'id': '01a1b7d4-be25-722b-ac65-6b8b662069e7',
        'recipientDeviceId': _deviceId,
        'senderDeviceId': '01a1b7d4-bdd4-7877-bb95-22ef017880bf',
        'kind': 'session_key',
        'content': 'c2VhbGVk',
      });
    });

    test('getKeyQueue reads what waits for the device', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.keyQueue,
        query: {'deviceId': _deviceId},
        statusCode: 200,
        body: {
          'items': [
            {
              'id': '01a1b7d4-be25-722b-ac65-6b8b662069e7',
              'recipientDeviceId': _deviceId,
              'senderDeviceId': '01a1b7d4-bdd4-7877-bb95-22ef017880bf',
              'senderUserId': 'StudentSamUid551191',
              'kind': 'session_key',
              'content': 'c2VhbGVkLXNlc3Npb24ta2V5LWJ5dGVz',
              'createdAt': '2026-11-07T21:05:35.271999Z',
            },
          ],
        },
      );

      final [item] = await api.getKeyQueue(_deviceId);

      expect(item.kind, 'session_key');
      expect(item.senderDeviceId, '01a1b7d4-bdd4-7877-bb95-22ef017880bf');
      expect(item.senderUserId, 'StudentSamUid551191');
    });

    test('confirmKeyItems sends the ids in runs the server takes', () async {
      respond(client: client, method: 'POST', path: Router.keyQueueConfirmations, statusCode: 204, body: {});
      final ids = List.generate(501, (index) => 'id-$index');

      await api.confirmKeyItems(_deviceId, ids);

      final [first, second] = sentTo(Router.keyQueueConfirmations).cast<Map>();
      expect(first['deviceId'], _deviceId);
      expect(first['ids'], hasLength(500));
      expect(second['ids'], ['id-500']);
    });
  });
}
