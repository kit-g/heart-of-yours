import 'dart:async';
import 'dart:convert';

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
      server.refuseNext['publish'] = {'error': 'conflict', 'code': 'device_limit'};
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

  group('stopping', () {
    test('a stop while a refresh is on its way ends it there', () async {
      final vault = _Vault();
      final coach = device('dana', vault: vault);
      await coach.start('dana');
      // enough claimed that the refresh would restock
      server.oneTimeKeys[coach.deviceId]!.removeRange(0, 30);
      final hold = server.holds['queue'] = Completer();
      server.calls.clear();
      final refreshing = coach.refresh();
      await server.called('queue');

      coach.stop();
      final stored = {...vault.entries};
      hold.complete();
      await refreshing;

      expect(server.calls, ['queue dana']);
      expect(server.oneTimeKeys[server.devices.keys.single], hasLength(20));
      expect(vault.entries, stored);
      expect(coach.deviceId, isNull);
      expect(coach.status, DeviceKeysStatus.off);
      expect(errors, isEmpty);
    });

    test('the next account to sign in gets its own device, never the last one', () async {
      final vault = _Vault();
      var who = 'dana';
      final phone = DeviceKeys(
        service: server.signedIn(() => who),
        vault: vault,
        remote: RemoteAccess(hasToken: () => true)..account = true,
        onError: (error, {stacktrace}) => errors.add(error),
      );
      await phone.start('dana');
      final dana = phone.deviceId!;
      final hold = server.holds['queue'] = Completer();
      final refreshing = phone.refresh();
      await server.called('queue');

      phone.onSignOut();
      Map<String, String> danas() => {
        for (final MapEntry(:key, :value) in vault.entries.entries)
          if (key.startsWith('keys.dana.')) key: value,
      };
      final stored = danas();
      who = 'sam';
      final starting = phone.start('sam');
      hold.complete();
      await refreshing;
      await starting;

      expect(phone.deviceId, isNot(dana));
      expect(server.devices[phone.deviceId]!.userId, 'sam');
      expect(phone.status, DeviceKeysStatus.published);
      // dana's queued restock never ran, as dana or on sam's keys
      expect(danas(), stored);
      expect(errors, isEmpty);
    });
  });

  group('fingerprint', () {
    test('is read while the network is busy, without waiting for it', () async {
      final coach = device('dana');
      await coach.start('dana');
      final hold = server.holds['devices'] = Completer();
      final reading = coach.devicesOf('sam');
      await server.called('devices');

      final fingerprint = await coach.fingerprint().timeout(const Duration(seconds: 1));

      expect(fingerprint, hasLength(22));
      hold.complete();
      await reading;
    });

    test('asked while the keys are first made, names the one device made and published', () async {
      final vault = _Vault();
      final coach = device('dana', vault: vault);

      final starting = coach.start('dana');
      final fingerprints = await Future.wait([coach.fingerprint(), coach.fingerprint()]);
      await starting;

      final published = server.devices.values.single;
      expect(published.id, coach.deviceId);
      expect(
        fingerprints,
        everyElement(
          Sealbox.fingerprint(
            identityKey: published.identityKey,
            signingKey: published.signingKey,
            context: DeviceKeys.fingerprintContext,
          ),
        ),
      );
    });

    test('is null while keys are off', () async {
      expect(await device('dana').fingerprint(), isNull);
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
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k');
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
        student.deliver(userId: 'dana', kind: 'sample', payload: 'k', fingerprint: fingerprint),
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
      final vouched = await phone.vouchFor(server.devices[tablet.deviceId]!);
      // the phone's signature, over another device's keys
      server.vouch(stranger.deviceId!, by: phone.deviceId!, signature: vouched.signature!);

      final peer = await student.devicesOf('dana', fingerprint: await phone.fingerprint());
      final trust = {for (final each in peer.devices) each.id: each.trust};

      expect(trust, {
        phone.deviceId: DeviceTrust.pinned,
        tablet.deviceId: DeviceTrust.vouched,
        stranger.deviceId: DeviceTrust.unverified,
      });
    });

    test('a vouch reaches the server once, and a different one after it is refused', () async {
      final phone = device('dana');
      final tablet = device('dana');
      final laptop = device('dana');
      await phone.start('dana');
      await tablet.start('dana');
      await laptop.start('dana');
      await phone.devicesOf('dana');
      final fresh = server.devices[tablet.deviceId]!;

      final vouched = await phone.vouchFor(fresh);

      expect((vouched.vouchedBy, server.devices[tablet.deviceId]!.vouchedBy), (phone.deviceId, phone.deviceId));
      expect(phone.peer('dana')!.devices.firstWhere((each) => each.id == tablet.deviceId).trust, DeviceTrust.vouched);
      // the same again, as after a lost answer: the device as it is
      expect((await phone.vouchFor(fresh)).signature, vouched.signature);
      await expectLater(laptop.vouchFor(fresh), throwsA({'error': 'conflict', 'code': 'already_vouched'}));
      expect(server.devices[tablet.deviceId]!.vouchedBy, phone.deviceId);
    });

    test('a device vouches only once it is published, and never for itself', () async {
      server.refuseNext['publish'] = {'error': 'conflict', 'code': 'device_limit'};
      final phone = device('dana');
      final tablet = device('dana');
      await phone.start('dana');
      await tablet.start('dana');
      server.calls.clear();

      await expectLater(phone.vouchFor(server.devices[tablet.deviceId]!), throwsStateError);
      await phone.refresh();
      await expectLater(tablet.vouchFor(server.devices[tablet.deviceId]!), throwsStateError);
      expect(server.calls.where((each) => each.startsWith('vouch')), isEmpty);
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
        await keys.on('sample', (delivery) async {
          (received[name] ??= []).add('${delivery.fromUserId}: ${delivery.payload}');
        });
      }

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'the key to a thread');
      // the server holds sealed text only
      expect(server.queue.map((each) => each.content), everyElement(isNot(contains('the key to a thread'))));
      await phone.receive();
      await tablet.receive();
      await phone.deliver(userId: 'sam', kind: 'sample', payload: 'one back');
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
      // what messages (#556) send: a stored thread's key, with the thread's id
      final thread = Sealbox(Sealbox.newNoteKey()).newThread();
      final payload = jsonEncode({'t': '01a1b7d4-be57-7a8e-aad3-42e570245e85', 'k': thread.sessionKey});

      await student.deliver(userId: 'dana', kind: DeviceKeys.threadKeyKind, payload: payload);

      expect(server.queue.single.content.length, lessThan(1024));
    });

    test('a session is started once: later items need no claim', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final payloads = <String>[];
      await coach.on('sample', (delivery) async => payloads.add(delivery.payload));

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'one');
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'two');
      await coach.receive();
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'three');
      await coach.receive();

      expect(server.calls.where((each) => each == 'claim sam dana'), hasLength(1));
      expect(payloads, ['one', 'two', 'three']);
    });

    test('a send to someone who added a device spends a key on that device alone (heart-api#424)', () async {
      final phone = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await student.start('sam');
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'one');
      final tablet = device('dana');
      await tablet.start('dana');
      final phoneKeys = server.oneTimeKeys[phone.deviceId]!.length;

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'two');

      expect(server.claims, [
        [phone.deviceId],
        [tablet.deviceId],
      ]);
      expect(server.oneTimeKeys[phone.deviceId], hasLength(phoneKeys));
      expect(server.queue.map((each) => each.recipientDeviceId), [phone.deviceId, phone.deviceId, tablet.deviceId]);
      expect(errors, isEmpty);
    });

    test('a device a send leaves out is not claimed from', () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await student.start('sam');

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k', to: (each) => each.id == phone.deviceId);

      expect(server.claims, [
        [phone.deviceId],
      ]);
      expect(server.oneTimeKeys[tablet.deviceId], hasLength(Sealbox.maxOneTimeKeys));
    });

    test('more than ten devices are claimed from ten at a time', () async {
      final coach = List.generate(11, (_) => device('dana'));
      for (final each in coach) {
        await each.start('dana');
      }
      final student = device('sam');
      await student.start('sam');

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k');

      expect(server.claims.map((each) => each?.length), [10, 1]);
      expect(server.queue, hasLength(11));
    });

    test('a device gone between the list and the claim gets nothing now, and is reported', () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await student.start('sam');
      final hold = server.holds['claim'] = Completer<void>();

      final sending = student.deliver(userId: 'dana', kind: 'sample', payload: 'k');
      await server.called('claim');
      server.remove(tablet.deviceId!);
      hold.complete();
      await sending;

      expect(server.queue.map((each) => each.recipientDeviceId), [phone.deviceId]);
      expect(errors.single, isA<KeysUnclaimed>().having((error) => error.count, 'count', 1));
    });

    test("the account's own id reaches its other devices", () async {
      final phone = device('dana');
      final tablet = device('dana');
      await phone.start('dana');
      await tablet.start('dana');
      final payloads = <String>[];
      await tablet.on('sample', (delivery) async => payloads.add(delivery.payload));

      await phone.deliver(userId: 'dana', kind: 'sample', payload: 'mine');
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

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'later');
      await coach.receive();
      expect(server.queue, isEmpty);

      // a later launch: the item opened once, and is still there
      final relaunched = device('dana', vault: vault);
      await relaunched.start('dana');
      final payloads = <String>[];
      await relaunched.on('sample', (delivery) async => payloads.add(delivery.payload));

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
      await coach.on('sample', (delivery) async {
        if (fail) throw StateError('not yet');
        payloads.add(delivery.payload);
      });

      await student.deliver(userId: 'dana', kind: 'sample', payload: 'again');
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
        return coach.deliver(userId: delivery.fromUserId, kind: 'sample', payload: 'asked for');
      });
      final payloads = <String>[];
      await student.on('sample', (delivery) async => payloads.add(delivery.payload));

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
          senderUserId: 'sam',
          kind: 'sample',
          content: 'v1.0.AAAA',
          createdAt: DateTime.now(),
        ),
      );

      await coach.receive();

      expect(server.queue, isEmpty);
      expect(errors.single, isA<KeyFailure>().having((error) => error.code, 'code', 'unknown_sender'));
    });

    test("whose it is comes from the server, and that account's list has to name the device", () async {
      final coach = device('dana');
      final student = device('sam');
      server.connect('dana', 'riley');
      await coach.start('dana');
      await student.start('sam');
      final from = <String>[];
      await coach.on('sample', (delivery) async => from.add(delivery.fromUserId));
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'one');
      await coach.receive();
      expect(from, ['sam']);

      // the same device, said to be someone else's
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'two');
      final [item] = server.queue;
      server.queue[0] = _sentBy(item, 'riley');
      await coach.receive();

      expect(server.queue, isEmpty);
      expect(from, ['sam']);
      expect(errors.single, isA<KeyFailure>().having((error) => error.code, 'code', 'unknown_sender'));
    });

    test("an item whose sender's account is gone can't be checked, and is dropped", () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final payloads = <String>[];
      await coach.on('sample', (delivery) async => payloads.add(delivery.payload));
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k');
      server.queue[0] = _sentBy(server.queue.single, null);
      server.calls.clear();

      await coach.receive();

      expect(server.queue, isEmpty);
      expect(payloads, isEmpty);
      expect(server.calls.where((each) => each.startsWith('devices')), isEmpty);
      expect(errors.single, isA<KeyFailure>().having((error) => error.code, 'code', 'unknown_sender'));
    });

    test("a wake naming this device reads its queue, and one naming another device doesn't", () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await student.start('sam');
      final payloads = <String>[];
      await phone.on('sample', (delivery) async => payloads.add(delivery.payload));
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k', to: (each) => each.id == phone.deviceId);
      server.calls.clear();

      await phone.queueWaiting(tablet.deviceId!);
      expect(server.calls, isEmpty);

      await phone.queueWaiting(phone.deviceId!);
      expect(payloads, ['k']);
      expect(server.queue, isEmpty);
    });

    test('a wake that finds the server out leaves the item for the next read, and is reported', () async {
      final coach = device('dana');
      await coach.start('dana');
      server.refuseNext['queue'] = TimeoutException('no answer');

      await coach.queueWaiting(coach.deviceId!);

      expect(errors.single, isA<TimeoutException>());
    });

    for (final (why, failure) in [
      ('a rate limit', {'error': 'too many requests', 'code': 'rate_limited', 'retryAfter': 60}),
      ('the server failing', {'error': 'internal server error', 'code': 'internal'}),
      ('no network', TimeoutException('no answer')),
    ]) {
      test("$why reading the sender's devices leaves the item for the next receive", () async {
        final coach = device('dana');
        final student = device('sam');
        await coach.start('dana');
        await student.start('sam');
        final payloads = <String>[];
        await coach.on('sample', (delivery) async => payloads.add(delivery.payload));
        await student.deliver(userId: 'dana', kind: 'sample', payload: 'one');
        await student.deliver(userId: 'dana', kind: 'sample', payload: 'two');

        server.refuseNext['devices'] = failure;
        await coach.receive();

        // both wait, in order, rather than the second opening without the first
        expect(server.queue, hasLength(2));
        expect(payloads, isEmpty);
        expect(errors, [failure]);

        await coach.receive();

        expect(payloads, ['one', 'two']);
        expect(server.queue, isEmpty);
      });
    }

    test('an item from someone the account can no longer read keys of is dropped', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      await student.deliver(userId: 'dana', kind: 'sample', payload: 'k');
      server.disconnect('dana', 'sam');

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
          senderUserId: 'sam',
          kind: 'sample',
          content: 'v1.0.not-a-message',
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
  group('threads (#556)', () {
    const thread = 'thread-1';

    ThreadCiphertext item(String id, SealedMessage sealed, String senderId) {
      return (id: id, senderId: senderId, content: sealed.content, commitment: sealed.commitment);
    }

    String sessionOf(SealedMessage sealed) => sealed.content.split('.')[1];

    test("a message opens on every device of both people's, and the server sees none of it", () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      for (final (keys, user) in [(phone, 'dana'), (tablet, 'dana'), (student, 'sam')]) {
        await keys.start(user);
      }

      final sealed = await student.seal(thread, 'my knee hurts');
      await student.share(thread, userId: 'dana');
      await phone.receive();
      await tablet.receive();

      expect(sealed.content, isNot(contains('knee')));
      expect(server.queue.map((each) => each.content), everyElement(isNot(contains('knee'))));
      for (final keys in [student, phone, tablet]) {
        final opened = await keys.open(thread, [item('m1', sealed, 'sam')]);
        expect((opened.single as Opened).text, 'my knee hurts');
      }
      expect(errors, isEmpty);
    });

    test('the franking key proves the words against the commitment', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');

      final sealed = await coach.seal(thread, 'squats today');
      await coach.share(thread, userId: 'sam');
      await student.receive();
      final opened = (await student.open(thread, [item('m1', sealed, 'dana')])).single as Opened;

      expect(
        Sealbox.verifyFranked(
          frankingKey: opened.frankingKey,
          plaintext: 'squats today',
          commitment: sealed.commitment,
        ),
        isTrue,
      );
    });

    test("one sealed under a key that hasn't arrived is locked, and opens once it does", () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final arrived = <String>[];
      final listening = student.threadKeys.listen(arrived.add);
      addTearDown(listening.cancel);

      final sealed = await coach.seal(thread, 'hello');
      expect((await student.open(thread, [item('m1', sealed, 'dana')])).single, isA<Locked>());

      await coach.share(thread, userId: 'sam');
      await student.receive();
      await pumpEventQueue();

      expect(arrived, [thread]);
      expect((await student.open(thread, [item('m1', sealed, 'dana')])).single, isA<Opened>());
    });

    test('a key reaches a device only once, and a device added later reads the whole key', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final first = await student.seal(thread, 'one');
      await student.share(thread, userId: 'dana');
      await coach.receive();
      server.calls.clear();

      await student.share(thread, userId: 'dana');
      expect(
        server.calls.where((each) => each.startsWith('enqueue')),
        isEmpty,
        reason: 'shared a moment ago, to every device it knew of',
      );

      final tablet = device('dana');
      await tablet.start('dana');
      await student.devicesChanged('dana');
      final second = await student.seal(thread, 'two');
      await student.share(thread, userId: 'dana');
      await tablet.receive();

      final opened = await tablet.open(thread, [item('m1', first, 'sam'), item('m2', second, 'sam')]);
      expect(opened.map((each) => (each as Opened).text), ['one', 'two']);
    });

    test('a second message at a position another took is refused', () async {
      final vault = _Vault();
      final coach = device('dana', vault: vault);
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      // the whole vault as it was, as a backup put back would have it
      final before = await coach.seal(thread, 'zero');
      final snapshot = {...vault.entries};
      final one = await coach.seal(thread, 'one');
      vault.entries
        ..clear()
        ..addAll(snapshot);
      final restarted = device('dana', vault: vault);
      await restarted.start('dana');
      final forged = await restarted.seal(thread, 'something else');
      expect(sessionOf(forged), sessionOf(one), reason: 'the same key, at the same position');
      await restarted.share(thread, userId: 'sam');
      await student.receive();

      final opened = await student.open(thread, [
        item('m0', before, 'dana'),
        item('m1', one, 'dana'),
        item('m2', forged, 'dana'),
      ]);

      expect(opened[1], isA<Opened>());
      expect(opened[2], isA<Refused>());
    });

    test('state older than its counter starts a new key rather than reuse a position', () async {
      final vault = _Vault();
      final coach = device('dana', vault: vault);
      await coach.start('dana');
      await coach.seal(thread, 'zero');
      final record = vault.entries['keys.dana.thread.$thread']!;
      final one = await coach.seal(thread, 'one');
      // the key's state put back, its counter not
      vault.entries['keys.dana.thread.$thread'] = record;

      final two = await coach.seal(thread, 'two');

      expect(sessionOf(two), isNot(sessionOf(one)));
    });

    test("a message under a key someone else shared, or with words that don't match, is refused", () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final sealed = await coach.seal(thread, 'hello');
      await coach.share(thread, userId: 'sam');
      await student.receive();
      final other = await coach.seal(thread, 'other words');

      final opened = await student.open(thread, [
        item('m1', sealed, 'riley'),
        (id: 'm2', senderId: 'dana', content: sealed.content, commitment: other.commitment),
        (id: 'm3', senderId: 'dana', content: 'not a message', commitment: sealed.commitment),
      ]);

      expect(opened, everyElement(isA<Refused>()));
    });

    test('a device removed after holding the key: the next message seals under a new one it never gets', () async {
      final phone = device('dana');
      final tablet = device('dana');
      final student = device('sam');
      await phone.start('dana');
      await tablet.start('dana');
      await student.start('sam');
      final first = await student.seal(thread, 'before');
      await student.share(thread, userId: 'dana');
      await tablet.receive();

      server.remove(tablet.deviceId!);
      await student.devicesChanged('dana');
      await student.share(thread, userId: 'dana');
      final second = await student.seal(thread, 'after');
      await student.share(thread, userId: 'dana');
      await phone.receive();

      expect(sessionOf(second), isNot(sessionOf(first)));
      final opened = await phone.open(thread, [item('m1', first, 'sam'), item('m2', second, 'sam')]);
      expect(opened.map((each) => (each as Opened).text), ['before', 'after']);
    });

    test('someone with no device to read it on is shared nothing, so what waits for it stays back', () async {
      final student = device('sam');
      await student.start('sam');
      await student.seal(thread, 'hello');

      expect(student.share(thread, userId: 'dana'), throwsA(isA<KeyFailure>()));
    });

    test('a thread key the library refuses is dropped, not handed again on every read', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      final arrived = <String>[];
      final listening = student.threadKeys.listen(arrived.add);
      addTearDown(listening.cancel);

      await coach.deliver(
        userId: 'sam',
        kind: DeviceKeys.threadKeyKind,
        payload: jsonEncode({'t': thread, 'k': 'garbage'}),
      );
      await student.receive();
      await student.receive();
      await pumpEventQueue();

      expect(errors.whereType<KeyFailure>(), hasLength(1));
      expect(arrived, isEmpty);
    });

    test('a mismatched fingerprint shares nothing', () async {
      final coach = device('dana');
      final student = device('sam');
      await coach.start('dana');
      await student.start('sam');
      await student.seal(thread, 'hello');

      expect(student.share(thread, userId: 'dana', fingerprint: 'AAAAAAAAAAAAAAAAAAAAAA'), throwsA(isA<KeyMismatch>()));
    });
  });
}

/// [item], as the server would read it with [senderUserId] for the sending
/// account: null once that account is deleted.
QueuedItem _sentBy(QueuedItem item, String? senderUserId) {
  return QueuedItem(
    id: item.id,
    recipientDeviceId: item.recipientDeviceId,
    senderDeviceId: item.senderDeviceId,
    senderUserId: senderUserId,
    kind: item.kind,
    content: item.content,
    createdAt: item.createdAt,
  );
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

  /// The devices each claim named, in order: null for one that named none.
  final claims = <List<String>?>[];

  /// What the next call of a name throws, once: a refusal, or no network.
  final refuseNext = <String, Object>{};

  /// Calls of a name wait here until it completes.
  final holds = <String, Completer<void>>{};

  void connect(String a, String b) => _pairs
    ..add((a, b))
    ..add((b, a));

  /// As under a block: neither can read the other's keys any more.
  void disconnect(String a, String b) => _pairs
    ..remove((a, b))
    ..remove((b, a));

  bool _shares(String reader, String owner) => reader == owner || _pairs.contains((reader, owner));

  void remove(String deviceId) {
    devices.remove(deviceId);
    removed.add(deviceId);
    oneTimeKeys.remove(deviceId);
  }

  CryptoDevice vouch(String deviceId, {required String by, required String signature}) {
    final device = devices[deviceId]!;
    return devices[deviceId] = CryptoDevice(
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

  RemoteKeyService as(String userId) => _As(this, () => userId);

  /// Whoever is signed in when a call is made, as the app's `Api` is.
  RemoteKeyService signedIn(String Function() who) => _As(this, who);

  /// Until [name] is called; what is held stays held.
  Future<void> called(String name) async {
    while (!calls.any((each) => each.startsWith('$name '))) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _As implements RemoteKeyService {
  final _Server server;
  final String Function() _who;

  const new(this.server, this._who);

  String get me => _who();

  Future<void> _answer(String name) async {
    if (server.holds[name] case final Completer<void> hold) await hold.future;
    if (server.refuseNext.remove(name) case final Object refusal) throw refusal;
  }

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
    await _answer('publish');
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
    await _answer('devices');
    if (!server._shares(me, owner)) throw {'error': 'forbidden', 'code': 'forbidden'};
    return [...server.devices.values.where((each) => each.userId == owner)];
  }

  @override
  Future<CryptoDevice> vouchForCryptoDevice(
    String deviceId, {
    required String vouchedBy,
    required String signature,
  }) async {
    server.calls.add('vouch $me');
    await _answer('vouch');
    final device = _mine(deviceId);
    if (vouchedBy == deviceId || server.devices[vouchedBy]?.userId != me) {
      throw {'error': 'bad request', 'code': 'bad_request'};
    }
    return switch ((device.vouchedBy, device.signature)) {
      (null, _) => server.vouch(deviceId, by: vouchedBy, signature: signature),
      (final by, final said) when by == vouchedBy && said == signature => device,
      _ => throw {'error': 'conflict', 'code': 'already_vouched'},
    };
  }

  @override
  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys) async {
    server.calls.add('add $me');
    await _answer('add');
    _mine(deviceId);
    final held = server.oneTimeKeys[deviceId] ??= [];
    held.addAll(keys.entries);
    if (held.length > 50) throw {'error': 'bad request', 'code': 'bad_request'};
    return held.length;
  }

  @override
  Future<int> countOneTimeKeys(String deviceId) async {
    server.calls.add('count $me');
    await _answer('count');
    _mine(deviceId);
    return server.oneTimeKeys[deviceId]?.length ?? 0;
  }

  @override
  Future<void> replaceFallbackKey(String deviceId, String key) async {
    server.calls.add('fallback $me');
    await _answer('fallback');
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
  Future<List<CryptoDevice>> claimKeys(String userId, {List<String>? deviceIds}) async {
    server.calls.add('claim $me $userId');
    server.claims.add(deviceIds);
    await _answer('claim');
    if (!server._shares(me, userId)) throw {'error': 'forbidden', 'code': 'forbidden'};
    if (deviceIds case final ids? when ids.isEmpty || ids.length > 10) {
      throw {'error': 'bad request', 'code': 'bad_request'};
    }
    // a named device that isn't theirs, or was removed, is left out
    final named = server.devices.values.where(
      (each) => each.userId == userId && (deviceIds?.contains(each.id) ?? true),
    );
    return [
      for (final device in named)
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
    await _answer('enqueue');
    _mine(senderDeviceId);
    final recipient = server.devices[recipientDeviceId];
    if (recipient == null || !server._shares(me, recipient.userId)) throw {'error': 'not found', 'code': 'not_found'};
    if (content.length > 1024) throw {'error': 'bad request', 'code': 'bad_request'};
    server.queue.add(
      QueuedItem(
        id: id,
        recipientDeviceId: recipientDeviceId,
        senderDeviceId: senderDeviceId,
        // the account the server knows sent it, from the sending device's row
        senderUserId: me,
        kind: kind,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<QueuedItem>> getKeyQueue(String deviceId) async {
    server.calls.add('queue $me');
    await _answer('queue');
    _mine(deviceId);
    return [...server.queue.where((each) => each.recipientDeviceId == deviceId)];
  }

  @override
  Future<void> confirmKeyItems(String deviceId, List<String> ids) async {
    server.calls.add('confirm $me');
    await _answer('confirm');
    _mine(deviceId);
    server.queue.removeWhere((each) => each.recipientDeviceId == deviceId && ids.contains(each.id));
  }
}
