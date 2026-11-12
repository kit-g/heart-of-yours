part of '../device_keys.dart';

/// One item that arrived for this device, opened.
class KeyDelivery {
  /// The queue's id for it.
  final String id;

  /// What it is, in the sender's words, such as a thread key.
  final String kind;

  final String payload;

  /// Whose device sent it: the account the server knows sent it, whose own
  /// device list names the sending device.
  final String fromUserId;

  final String fromDeviceId;

  const new({
    required this.id,
    required this.kind,
    required this.payload,
    required this.fromUserId,
    required this.fromDeviceId,
  });

  Map<String, String> toMap() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'fromUserId': fromUserId,
    'fromDeviceId': fromDeviceId,
  };

  static KeyDelivery? of(Object? json) {
    return switch (json) {
      {
        'id': final String id,
        'kind': final String kind,
        'payload': final String payload,
        'fromUserId': final String fromUserId,
        'fromDeviceId': final String fromDeviceId,
      } =>
        KeyDelivery(id: id, kind: kind, payload: payload, fromUserId: fromUserId, fromDeviceId: fromDeviceId),
      _ => null,
    };
  }
}

/// Takes one delivered item. Done when it returns: the item is forgotten.
typedef KeyDeliveryHandler = Future<void> Function(KeyDelivery delivery);

/// Reading the queue, opening what is on it, and handing it over.
extension _Arrivals on DeviceKeys {
  /// Reads what waits for [run]'s device and opens it. What opened is kept,
  /// then confirmed; what can never be opened is confirmed and dropped; what
  /// can't be opened just now stays on the server for the next receive.
  Future<void> _receive(_Run run) async {
    await _serial(run, () async {
      final device = run.device;
      if (device == null || !device.published || !_remote.allowed) return;
      final items = await run.service.getKeyQueue(device.id);
      if (items.isEmpty) return;
      final inbox = await run.inbox();
      final kept = {for (final each in inbox) each.id};
      // whose devices sent what, read once per sender
      final senders = <String, List<CryptoDevice>?>{};
      final later = <String>{};
      for (final item in items.where((each) => !kept.contains(each.id))) {
        switch (await _open(run, item, senders)) {
          case _Delivered(:final delivery):
            // kept before it is confirmed: a pairwise message opens once
            await run.saveInbox([...inbox, delivery]);
            inbox.add(delivery);
          case _Unreadable():
            // confirmed with the rest: no later receive opens it either
            break;
          case _Later():
            later.add(item.id);
        }
      }
      final confirmed = [
        for (final each in items)
          if (!later.contains(each.id)) each.id,
      ];
      if (confirmed.isNotEmpty) await run.service.confirmKeyItems(device.id, confirmed);
    });
    await _dispatch(run);
  }

  Future<_Arrival> _open(_Run run, QueuedItem item, Map<String, List<CryptoDevice>?> senders) async {
    final device = run.device!;
    final envelope = _Envelope.decode(item.content);
    if (envelope == null) {
      _report(const KeyFailure('unreadable_item'));
      return _Unreadable();
    }
    // the server says whose account sent it, never the item; with that
    // account deleted, there is no list left to check the device against
    final (senderId, from) = (item.senderDeviceId, item.senderUserId);
    if (senderId == null || from == null) {
      _report(const KeyFailure('unknown_sender'));
      return _Unreadable();
    }
    // that account's own list has to name the sending device
    final listed = switch (senders.containsKey(from)) {
      true => senders[from],
      false => senders[from] = await _senderDevices(run, from),
    };
    if (listed == null) return _Later();
    final sender = listed.where((each) => each.id == senderId).firstOrNull;
    if (sender == null) {
      _report(const KeyFailure('unknown_sender'));
      return _Unreadable();
    }
    final message = envelope.message;
    final existing = await run.session(senderId);
    try {
      // a first message starts a new session, unless it is the one this
      // device already holds, whose sender hasn't heard back yet
      final starts = message.type == 0 && Sealbox.sessionIdOf(message) != existing?.sessionId;
      final opened = switch ((starts, existing)) {
        (true, _) => _accept(run, device, sender, message),
        (false, final _Session existing) => _decrypt(run, existing, message),
        (false, null) => null,
      };
      if (opened == null) {
        // a reply on a session this device no longer holds: the sender sent
        // it only after hearing back on that session, and nothing brings the
        // session back, so waiting would not open it either
        _report(const KeyFailure('no_session'));
        return _Unreadable();
      }
      // the single-use key a new session took is spent: saved before anything else
      if (opened.account case final String account) await run.saveDevice(device.copyWith(account: account));
      await run.saveSession(senderId, opened.session);
      return _Delivered(
        KeyDelivery(
          id: item.id,
          kind: item.kind,
          payload: opened.plaintext,
          fromUserId: from,
          fromDeviceId: senderId,
        ),
      );
    } on SealboxException catch (error) {
      // a session that can't open what came on it is stale: the next send
      // starts a new one, and the sender asks again for what it misses
      if (envelope.message.type == 1) await run.forget('session.$senderId');
      _report(KeyFailure(error.code));
      return _Unreadable();
    }
  }

  /// [from]'s devices: none for someone this account can't read keys of, and
  /// null when they can't be read just now.
  Future<List<CryptoDevice>?> _senderDevices(_Run run, String from) async {
    try {
      return await _listed(run, from);
    } on Map catch (refusal) {
      return switch (refusal) {
        // someone this account can't read keys of, as under a block: what they
        // sent never opens here
        {'code': 'forbidden' || 'not_found' || 'bad_request'} => const [],
        // a rate limit, or the server failing: tried again on the next receive
        _ => _unreachable(refusal),
      };
    } on Exception catch (error, stacktrace) {
      // no network, or no answer
      return _unreachable(error, stacktrace);
    }
  }

  List<CryptoDevice>? _unreachable(Object error, [StackTrace? stacktrace]) {
    _report(error, stacktrace);
    return null;
  }

  _Opened _accept(_Run run, _Device device, CryptoDevice sender, PairwiseMessage message) {
    final accepted = run.sealbox.acceptSession(
      account: device.account,
      identityKey: sender.identityKey,
      message: message,
    );
    return (
      account: accepted.account,
      session: (session: accepted.session, sessionId: accepted.sessionId, identityKey: sender.identityKey),
      plaintext: accepted.plaintext,
    );
  }

  _Opened _decrypt(_Run run, _Session existing, PairwiseMessage message) {
    final decrypted = run.sealbox.decrypt(existing.session, message);
    return (
      account: null,
      session: (session: decrypted.session, sessionId: existing.sessionId, identityKey: existing.identityKey),
      plaintext: decrypted.plaintext,
    );
  }

  /// Hands what waits to the handlers for its kinds, outside the lock, so a
  /// handler may send in turn. One run at a time, so nothing is handed twice.
  Future<void> _dispatch(_Run run) {
    final done = _dispatching.then((_) async {
      try {
        final waiting = await _serial(run, run.inbox);
        final handled = <String>{};
        for (final delivery in waiting) {
          final handler = _handlers[delivery.kind];
          if (handler == null) continue;
          try {
            await handler(delivery);
            handled.add(delivery.id);
          } catch (error, stacktrace) {
            // kept, and handed again on the next run
            _report(error, stacktrace);
          }
        }
        if (handled.isEmpty) return;
        await _serial(run, () async {
          final inbox = await run.inbox();
          await run.saveInbox(inbox.where((each) => !handled.contains(each.id)).toList());
        });
      } on _Stopped {
        // stopped on the way: what is left waits on the device for the next start
      }
    });
    _dispatching = done.then<void>((_) {}, onError: (_) {});
    return done;
  }
}

/// What became of one item on the queue.
sealed class _Arrival;

/// Opened, and kept on the device.
final class _Delivered extends _Arrival {
  final KeyDelivery delivery;

  new(this.delivery);
}

/// Never opens on this device: confirmed, and dropped.
final class _Unreadable extends _Arrival;

/// Can't be opened just now: left on the server for the next receive.
final class _Later extends _Arrival;

/// What opening one message gave: the session moved on, the words, and the
/// account when a new session spent one of its single-use keys.
typedef _Opened = ({String? account, _Session session, String plaintext});

/// What travels in a queue item: the pairwise message, and nothing of who
/// sent it, which the server says (`senderUserId`) and the item could only
/// claim. `v1.<type>.<body>`, kept short because an item carries at most
/// 1 KB, and the server sees it as text and nothing more.
class _Envelope {
  final PairwiseMessage message;

  const new(this.message);

  static const _version = 'v1';

  String encode() => [_version, message.type, message.body].join('.');

  static _Envelope? decode(String content) {
    return switch (content.split('.')) {
      [_version, final String type, final String body] when body.isNotEmpty => switch (int.tryParse(type)) {
        final int type when type == 0 || type == 1 => _Envelope((type: type, body: body)),
        _ => null,
      },
      _ => null,
    };
  }
}
