import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:sealbox/sealbox.dart';

/// Device keys and key delivery (#555), through the real encryption library
/// and a server that behaves as heart-api's routes do.
void main() {
  late _Server server;
  late List<Object> errors;

  DeviceKeys device(String userId, {_Vault? vault, RemoteAccess? remote, DateTime Function()? now}) {
    return DeviceKeys(
      service: server.as(userId),
      vault: vault ?? _Vault(),
      remote: remote ?? (RemoteAccess(hasToken: () => true)..account = true),
      onError: (error, {stacktrace}) => errors.add(error),
      now: now,
    );
  }

  setUp(() {
    server = _Server()..connect('dana', 'sam');
    errors = [];
  });

  group('publishing', () {
    test('a start makes the keys, publishes them and stocks single-use keys', () async {
      final phone = device('dana');

      await phone.start('dana');

      expect(phone.status, DeviceKeysStatus.published);
      expect(server.devices.keys, [phone.deviceId]);
      expect(server.oneTimeKeys[phone.deviceId], hasLength(Sealbox.maxOneTimeKeys));
      expect(errors, isEmpty);
    });

    test('nothing is made or sent before a start, nor without a vault', () async {
      final vault = _Vault();
      device('dana', vault: vault);
      final noVault = DeviceKeys(service: server.as('dana'), vault: null);

      await noVault.start('dana');

      expect(vault.entries, isEmpty);
      expect(server.calls, isEmpty);
      expect(noVault.status, DeviceKeysStatus.off);
    });

    test('nothing goes over the wire without an account behind the session', () async {
      final phone = device('dana', remote: RemoteAccess(allowed: false));

      await phone.start('dana');

      expect(server.calls, isEmpty);
    });

    test('a stop forgets nothing on the device, and the next start is the same device', () async {
      final vault = _Vault();
      final phone = device('dana', vault: vault);
      await phone.start('dana');
      final id = phone.deviceId;

      phone.stop();
      expect(phone.status, DeviceKeysStatus.off);
      expect(phone.deviceId, isNull);
      server.calls.clear();
      await phone.start('dana');

      expect(phone.deviceId, id);
      expect(server.calls.where((each) => each.startsWith('publish')), isEmpty);
      expect(vault.entries.keys, everyElement(startsWith('keys.dana.')));
    });

    test('a device removed for good starts over under a new id', () async {
      final vault = _Vault();
      final phone = device('dana', vault: vault);
      await phone.start('dana');
      final old = phone.deviceId!;
      server.remove(old);

      // the vault says published, the server says removed: the next publish is
      // a new device, as a phone restored over a removed one would be
      final again = device('dana', vault: vault..unpublish('dana'));
      await again.start('dana');

      expect(again.deviceId, isNot(old));
      expect(server.devices.keys, [again.deviceId]);
      expect(again.status, DeviceKeysStatus.published);
    });

    test('a refusal leaves the keys unpublished and is reported, not thrown', () async {
      server.refuseNextPublish = {'error': 'conflict', 'code': 'device_limit'};
      final phone = device('dana');

      await phone.start('dana');

      expect(phone.status, DeviceKeysStatus.failed);
      expect(errors, [
        {'error': 'conflict', 'code': 'device_limit'},
      ]);
      await phone.refresh();
      expect(phone.status, DeviceKeysStatus.published);
    });
  });

  group('single-use keys', () {
    test('restocked once claims bring the server below half', () async {
      final phone = device('dana');
      await phone.start('dana');
      // claimed, and never used to start a session: the library still holds them
      server.oneTimeKeys[phone.deviceId]!.removeRange(0, 30);

      await phone.refresh();

      // only as many as the library has room for
      expect(server.oneTimeKeys[phone.deviceId], hasLength(20));
    });

    test('a key spent on a session makes room for a new one', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      server.oneTimeKeys[coach.deviceId]!.removeRange(0, 30);
      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'k');
      await coach.refresh();

      expect(server.oneTimeKeys[coach.deviceId], hasLength(20));
    });

    test('the fallback key is replaced after a week', () async {
      var now = DateTime.utc(2026, 11, 11);
      final phone = device('dana', now: () => now);
      await phone.start('dana');
      final first = server.devices[phone.deviceId]!.fallbackKey;

      now = now.add(const Duration(days: 8));
      await phone.refresh();

      expect(server.devices[phone.deviceId]!.fallbackKey, isNot(first));
    });
  });

  group('checking the other side', () {
    test("an invitation's fingerprint pins the coach's device", () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final fingerprint = await coach.fingerprint();

      final peer = await student.devicesOf('dana', fingerprint: fingerprint);

      expect(fingerprint, hasLength(22));
      expect(peer.check, PeerCheck.matched);
      expect(peer.devices.single.trust, DeviceTrust.pinned);
      expect(student.peer('dana'), same(peer));
    });

    test('without a fingerprint there is nothing to check against', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');

      final peer = await student.devicesOf('dana');

      expect(peer.check, PeerCheck.nothingToCheck);
      expect(peer.devices.single.trust, DeviceTrust.unverified);
    });

    test('keys that do not match the fingerprint are refused, and nothing is sent', () async {
      final coach = device('dana');
      final impostor = device('dana');
      final student = device('sam');
      await coach.start('dana');
      final fingerprint = await coach.fingerprint();
      server.remove(coach.deviceId!);
      await impostor.start('dana');
      await student.start('sam');
      server.calls.clear();

      expect((await student.devicesOf('dana', fingerprint: fingerprint)).check, PeerCheck.mismatch);
      await expectLater(
        student.deliver(userId: 'dana', kind: 'thread_key', payload: 'k', fingerprint: fingerprint),
        throwsA(isA<KeyMismatch>()),
      );
      expect(server.calls.where((each) => each.startsWith('claim') || each.startsWith('enqueue')), isEmpty);
    });

    test('someone who accepted on the web holds no keys yet', () async {
      final student = device('sam');
      await student.start('sam');

      expect((await student.devicesOf('dana')).check, PeerCheck.noDevices);
    });

    test('a device vouched for by a pinned one is trusted, a bad vouch is not', () async {
      final phone = device('dana');
      final tablet = device('dana');
      final stranger = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await stranger.start('dana');
      await student.start('sam');
      final signature = await phone.vouchFor(server.devices[tablet.deviceId]!);
      server.vouch(tablet.deviceId!, by: phone.deviceId!, signature: signature);
      // the phone's signature, over another device's keys
      server.vouch(stranger.deviceId!, by: phone.deviceId!, signature: signature);

      final peer = await student.devicesOf('dana', fingerprint: await phone.fingerprint());
      final trust = {for (final each in peer.devices) each.id: each.trust};

      expect(trust, {
        phone.deviceId: DeviceTrust.pinned,
        tablet.deviceId: DeviceTrust.vouched,
        stranger.deviceId: DeviceTrust.unverified,
      });
    });

    test('a device added after the first look is said to be new', () async {
      final phone = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await student.start('sam');
      expect((await student.devicesOf('dana')).added, isEmpty);

      final tablet = device('dana');
      await tablet.start('dana');
      await student.devicesChanged('dana');

      expect(student.peer('dana')!.added.map((each) => each.id), [tablet.deviceId]);
      expect(student.peer('dana')!.added.single.vouched, isFalse);
    });

    test("someone the account has no connection with can't be read", () async {
      final student = device('sam');
      await student.start('sam');

      await student.devicesChanged('riley');

      expect(errors.single, {'error': 'forbidden', 'code': 'forbidden'});
    });
  });

  group('delivery', () {
    test("reaches every one of the other person's devices, sealed, and back", () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await student.start('sam');
      final received = <String, List<String>>{};
      for (final (name, keys) in [('phone', phone), ('tablet', tablet), ('student', student)]) {
        await keys.on('thread_key', (delivery) async {
          (received[name] ??= []).add('${delivery.fromUserId}: ${delivery.payload}');
        });
      }

      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'the key to a thread');
      // the server holds sealed text only
      expect(server.queue.map((each) => each.content), everyElement(isNot(contains('the key to a thread'))));
      await phone.receive();
      await tablet.receive();
      await phone.deliver(userId: 'sam', kind: 'thread_key', payload: 'one back');
      await student.receive();

      expect(received, {
        'phone': ['sam: the key to a thread'],
        'tablet': ['sam: the key to a thread'],
        'student': ['dana: one back'],
      });
      expect(server.queue, isEmpty);
      expect(errors, isEmpty);
    });

    test("a thread's key fits in one item, first message and all", () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      // what messages (#556) will send: a stored thread's key, with its id
      final thread = Sealbox(Sealbox.newNoteKey()).newThread();
      final payload = '${thread.sessionId}:${thread.sessionKey}';

      await student.deliver(userId: 'dana', kind: 'thread_key', payload: payload);

      expect(server.queue.single.content.length, lessThan(1024));
    });

    test('a session is started once: later items need no claim', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final payloads = <String>[];
      await coach.on('thread_key', (delivery) async => payloads.add(delivery.payload));

      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'one');
      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'two');
      await coach.receive();
      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'three');
      await coach.receive();

      expect(server.calls.where((each) => each == 'claim sam dana'), hasLength(1));
      expect(payloads, ['one', 'two', 'three']);
    });

    test("the account's own id reaches its other devices", () async {
      final phone = device('dana');
      final tablet = device('dana');
      await phone.start('dana');
      await tablet.start('dana');
      final payloads = <String>[];
      await tablet.on('thread_key', (delivery) async => payloads.add(delivery.payload));

      await phone.deliver(userId: 'dana', kind: 'thread_key', payload: 'mine');
      await tablet.receive();

      expect(payloads, ['mine']);
      expect(server.queue, isEmpty);
    });

    test('what has no handler yet waits on the device, confirmed, until one comes', () async {
      final vault = _Vault();
      final coach = device('dana', vault: vault);
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');

      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'later');
      await coach.receive();
      expect(server.queue, isEmpty);

      // a later launch: the item opened once, and is still there
      final relaunched = device('dana', vault: vault);
      await relaunched.start('dana');
      final payloads = <String>[];
      await relaunched.on('thread_key', (delivery) async => payloads.add(delivery.payload));

      expect(payloads, ['later']);
      expect(vault.entries['keys.dana.inbox'], isNot(contains('later')));
    });

    test('a handler that fails is handed the item again', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      var fail = true;
      final payloads = <String>[];
      await coach.on('thread_key', (delivery) async {
        if (fail) throw StateError('not yet');
        payloads.add(delivery.payload);
      });

      await student.deliver(userId: 'dana', kind: 'thread_key', payload: 'again');
      await coach.receive();
      fail = false;
      await coach.receive();

      expect(payloads, ['again']);
    });

    test('a handler may send in turn', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      await coach.on('key_request', (delivery) {
        return coach.deliver(userId: delivery.fromUserId, kind: 'thread_key', payload: 'asked for');
      });
      final payloads = <String>[];
      await student.on('thread_key', (delivery) async => payloads.add(delivery.payload));

      await student.deliver(userId: 'dana', kind: 'key_request', payload: 'thread-1');
      await coach.receive();
      await student.receive();

      expect(payloads, ['asked for']);
    });

    test('an item from a device its sender does not list is dropped, and said by its code', () async {
      final coach = device('dana');
      await coach.start('dana');
      server.queue.add(
        QueuedItem(
          id: uuidV7(),
          recipientDeviceId: coach.deviceId!,
          senderDeviceId: '01a1b7d4-bdd4-7877-bb95-22ef017880bf',
          kind: 'thread_key',
          content: 'v1.0.sam.AAAA',
          createdAt: DateTime.now(),
        ),
      );

      await coach.receive();

      expect(server.queue, isEmpty);
      expect(errors.single, isA<KeyFailure>().having((error) => error.code, 'code', 'unknown_sender'));
    });

    test('words that are not a sealed message are dropped, and nothing of them is reported', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      server.queue.add(
        QueuedItem(
          id: uuidV7(),
          recipientDeviceId: coach.deviceId!,
          senderDeviceId: student.deviceId,
          kind: 'thread_key',
          content: 'v1.0.sam.not-a-message',
          createdAt: DateTime.now(),
        ),
      );

      await coach.receive();

      expect(server.queue, isEmpty);
      expect(errors.single, isA<KeyFailure>());
      expect('${errors.single}', isNot(contains('not-a-message')));
    });

    test('a sign-out stops it, and nothing goes out after', () async {
      final coach = device('dana');
      await coach.start('dana');
      server.calls.clear();

      coach.onSignOut();
      await coach.refresh();
      await coach.receive();

      expect(server.calls, isEmpty);
      expect(coach.status, DeviceKeysStatus.off);
    });
  });
}

/// The vault, in memory.
class _Vault implements KeyVault {
  final entries = <String, String>{};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);

  /// As though the last publish never reached the server.
  void unpublish(String userId) {
    entries['keys.$userId.device'] = entries['keys.$userId.device']!.replaceFirst(
      '"published":true',
      '"published":false',
    );
  }
}

/// heart-api's key routes, in memory: who shares keys with whom, single-use
/// keys taken once each, and a queue read by its recipient until confirmed.
class _Server {
  final devices = <String, CryptoDevice>{};
  final removed = <String>{};
  final oneTimeKeys = <String, List<MapEntry<String, String>>>{};
  final queue = <QueuedItem>[];
  final calls = <String>[];
  final _pairs = <(String, String)>{};
  Map<String, String>? refuseNextPublish;

  void connect(String a, String b) => _pairs
    ..add((a, b))
    ..add((b, a));

  bool _shares(String reader, String owner) => reader == owner || _pairs.contains((reader, owner));

  void remove(String deviceId) {
    devices.remove(deviceId);
    removed.add(deviceId);
    oneTimeKeys.remove(deviceId);
  }

  void vouch(String deviceId, {required String by, required String signature}) {
    final device = devices[deviceId]!;
    devices[deviceId] = CryptoDevice(
      id: device.id,
      userId: device.userId,
      identityKey: device.identityKey,
      signingKey: device.signingKey,
      fallbackKey: device.fallbackKey,
      signature: signature,
      vouchedBy: by,
      createdAt: device.createdAt,
    );
  }

  RemoteKeyService as(String userId) => _As(this, userId);
}

class _As implements RemoteKeyService {
  final _Server server;
  final String me;

  const new(this.server, this.me);

  CryptoDevice _mine(String deviceId) {
    return switch (server.devices[deviceId]) {
      final CryptoDevice device when device.userId == me => device,
      _ => throw {'error': 'not found', 'code': 'not_found'},
    };
  }

  @override
  Future<CryptoDevice> publishCryptoDevice({
    required String id,
    required String identityKey,
    required String signingKey,
    required String fallbackKey,
    ({String signature, String vouchedBy})? vouch,
  }) async {
    server.calls.add('publish $me');
    if (server.refuseNextPublish case final Map<String, String> refusal) {
      server.refuseNextPublish = null;
      throw refusal;
    }
    if (server.removed.contains(id)) throw {'error': 'forbidden', 'code': 'device_removed'};
    return server.devices[id] ??= CryptoDevice(
      id: id,
      userId: me,
      identityKey: identityKey,
      signingKey: signingKey,
      fallbackKey: fallbackKey,
      signature: vouch?.signature,
      vouchedBy: vouch?.vouchedBy,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<CryptoDevice>> getCryptoDevices({String? userId}) async {
    final owner = userId ?? me;
    server.calls.add('devices $me $owner');
    if (!server._shares(me, owner)) throw {'error': 'forbidden', 'code': 'forbidden'};
    return [...server.devices.values.where((each) => each.userId == owner)];
  }

  @override
  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys) async {
    server.calls.add('add $me');
    _mine(deviceId);
    final held = server.oneTimeKeys[deviceId] ??= [];
    held.addAll(keys.entries);
    if (held.length > 50) throw {'error': 'bad request', 'code': 'bad_request'};
    return held.length;
  }

  @override
  Future<int> countOneTimeKeys(String deviceId) async {
    server.calls.add('count $me');
    _mine(deviceId);
    return server.oneTimeKeys[deviceId]?.length ?? 0;
  }

  @override
  Future<void> replaceFallbackKey(String deviceId, String key) async {
    server.calls.add('fallback $me');
    final device = _mine(deviceId);
    server.devices[deviceId] = CryptoDevice(
      id: device.id,
      userId: device.userId,
      identityKey: device.identityKey,
      signingKey: device.signingKey,
      fallbackKey: key,
      signature: device.signature,
      vouchedBy: device.vouchedBy,
      createdAt: device.createdAt,
    );
  }

  @override
  Future<List<CryptoDevice>> claimKeys(String userId) async {
    server.calls.add('claim $me $userId');
    if (!server._shares(me, userId)) throw {'error': 'forbidden', 'code': 'forbidden'};
    return [
      for (final device in server.devices.values.where((each) => each.userId == userId))
        switch (server.oneTimeKeys[device.id]) {
          final List<MapEntry<String, String>> held when held.isNotEmpty => () {
            final key = held.removeAt(0);
            return CryptoDevice(
              id: device.id,
              userId: device.userId,
              identityKey: device.identityKey,
              signingKey: device.signingKey,
              fallbackKey: device.fallbackKey,
              createdAt: device.createdAt,
              oneTimeKeyId: key.key,
              oneTimeKey: key.value,
            );
          }(),
          _ => device,
        },
    ];
  }

  @override
  Future<void> enqueueKeyItem({
    required String id,
    required String recipientDeviceId,
    required String senderDeviceId,
    required String kind,
    required String content,
  }) async {
    server.calls.add('enqueue $me $kind');
    _mine(senderDeviceId);
    final recipient = server.devices[recipientDeviceId];
    if (recipient == null || !server._shares(me, recipient.userId)) throw {'error': 'not found', 'code': 'not_found'};
    if (content.length > 1024) throw {'error': 'bad request', 'code': 'bad_request'};
    server.queue.add(
      QueuedItem(
        id: id,
        recipientDeviceId: recipientDeviceId,
        senderDeviceId: senderDeviceId,
        kind: kind,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<QueuedItem>> getKeyQueue(String deviceId) async {
    server.calls.add('queue $me');
    _mine(deviceId);
    return [...server.queue.where((each) => each.recipientDeviceId == deviceId)];
  }

  @override
  Future<void> confirmKeyItems(String deviceId, List<String> ids) async {
    server.calls.add('confirm $me');
    _mine(deviceId);
    server.queue.removeWhere((each) => each.recipientDeviceId == deviceId && ids.contains(each.id));
  }
}
