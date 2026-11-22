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

/// What a handler throws to leave a delivery where it is, unreported, for a
/// later dispatch: one it can't take yet, and will.
class _Held implements Exception {
  const new();
}

/// Reading the queue, opening what is on it, and handing it over.
extension _Arrivals on DeviceKeys {
  /// Reads what waits for [run]'s device and opens it. What opened is kept,
  /// then confirmed; what can never be opened is confirmed and dropped; what
  /// can't be opened just now stays on the server for the next receive.
  ///
  /// A [polled] one hands deliveries over only when something arrived: what is
  /// held here would otherwise be tried again, network and all, at each poll.
  /// [report] is told what went wrong, [_report] when not given.
  Future<void> _receive(_Run run, {bool polled = false, void Function(Object, [StackTrace?])? report}) async {
    final arrived = await _serial(run, () async {
      final device = run.device;
      if (device == null || !device.published || !_remote.allowed) return false;
      // with a deadline: every step waits for this one, so a read that hung
      // would hold up what this device has to send
      final items = await run.service.getKeyQueue(device.id).timeout(_readTime);
      if (items.isEmpty) return false;
      final inbox = await run.inbox();
      final kept = {for (final each in inbox) each.id};
      // whose devices sent what, read once per sender
      final senders = <String, List<CryptoDevice>?>{};
      final later = <String>{};
      for (final item in items.where((each) => !kept.contains(each.id))) {
        switch (await _open(run, item, senders, report ?? _report)) {
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
      if (confirmed.isNotEmpty) await run.service.confirmKeyItems(device.id, confirmed).timeout(_readTime);
      return confirmed.isNotEmpty;
    });
    if (arrived || !polled) await _dispatch(run);
  }

  /// What a read of the queue, or of a sender's devices on the way, may take.
  static const _readTime = Duration(seconds: 10);

  Future<_Arrival> _open(
    _Run run,
    QueuedItem item,
    Map<String, List<CryptoDevice>?> senders,
    void Function(Object, [StackTrace?]) report,
  ) async {
    final device = run.device!;
    final envelope = _Envelope.decode(item.content);
    if (envelope == null) {
      report(const KeyFailure('unreadable_item'));
      return _Unreadable();
    }
    // the server says whose account sent it, never the item; with that
    // account deleted, there is no list left to check the device against
    final (senderId, from) = (item.senderDeviceId, item.senderUserId);
    if (senderId == null || from == null) {
      report(const KeyFailure('unknown_sender'));
      return _Unreadable();
    }
    // that account's own list has to name the sending device
    final listed = switch (senders.containsKey(from)) {
      true => senders[from],
      false => senders[from] = await _senderDevices(run, from, report),
    };
    if (listed == null) return _Later();
    final sender = listed.where((each) => each.id == senderId).firstOrNull;
    if (sender == null) {
      report(const KeyFailure('unknown_sender'));
      return _Unreadable();
    }
    final message = envelope.message;
    final existing = await run.session(senderId);
    final spare = await run.spareSession(senderId);
    try {
      // a first message starts a new session, unless it is one this device
      // already holds, whose sender hasn't heard back yet
      final named = switch (message.type) {
        0 => Sealbox.sessionIdOf(message),
        _ => null,
      };
      final opened = switch ((named, existing)) {
        (final String id, _) when id != existing?.sessionId && id != spare?.sessionId => _accept(
          run,
          device,
          sender,
          message,
        ),
        (final String id, _) when id == spare?.sessionId => _decrypt(run, spare!, message),
        (_, final _Session existing) => _decryptEither(run, existing, spare, message),
        (_, null) => null,
      };
      if (opened == null) {
        // a reply on a session this device no longer holds: the sender sent
        // it only after hearing back on that session, and nothing brings the
        // session back, so waiting would not open it either
        report(const KeyFailure('no_session'));
        return _Unreadable();
      }
      // the single-use key a new session took is spent: saved before anything else
      if (opened.account case final String account) await run.saveDevice(device.copyWith(account: account));
      // the one it takes the place of is kept, for what the other side may
      // still send on it
      if (existing case final _Session replaced when replaced.sessionId != opened.session.sessionId) {
        await run.saveSpareSession(senderId, replaced);
      }
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
      if (envelope.message.type == 1) await run.forgetSessions(senderId);
      report(KeyFailure(error.code));
      return _Unreadable();
    }
  }

  /// [from]'s devices: none for someone this account can't read keys of, and
  /// null when they can't be read just now.
  Future<List<CryptoDevice>?> _senderDevices(
    _Run run,
    String from,
    void Function(Object, [StackTrace?]) report,
  ) async {
    // they can't be read just now
    List<CryptoDevice>? unreachable(Object error, StackTrace stacktrace) {
      report(error, stacktrace);
      return null;
    }

    try {
      return await _listed(run, from).timeout(_readTime);
    } on ServerRefusal catch (refusal, stacktrace) {
      return switch (refusal.code) {
        // someone this account can't read keys of, as under a block: what they
        // sent never opens here
        'forbidden' || 'not_found' || 'bad_request' => const [],
        // a rate limit: tried again on the next receive
        _ => unreachable(refusal, stacktrace),
      };
    } on Exception catch (error, stacktrace) {
      // no network, no answer, or the server failing
      return unreachable(error, stacktrace);
    }
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

  /// [message] on [existing], or else on [spare]: a later message doesn't name
  /// its session.
  _Opened _decryptEither(_Run run, _Session existing, _Session? spare, PairwiseMessage message) {
    if (spare == null) return _decrypt(run, existing, message);
    try {
      return _decrypt(run, existing, message);
    } on SealboxException {
      return _decrypt(run, spare, message);
    }
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
          // another account signed in meanwhile: a handler reads the current
          // one, and this one's deliveries wait for its next start
          if (!identical(_run, run)) throw _Stopped();
          final handler = _handlers[delivery.kind];
          if (handler == null) continue;
          try {
            await handler(delivery);
            handled.add(delivery.id);
          } on _Held {
            // not yet: kept, and handed again once it can be taken
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

  /// Hands over again what waits, without waiting for it: something a handler
  /// held may be taken now.
  void _redispatch(_Run run) {
    unawaited(
      _dispatch(run).catchError((Object error, StackTrace stacktrace) {
        // kept on the device for the next run
        _report(error, stacktrace);
      }),
    );
  }

  /// Throws [_Held] unless [delivery] came from this device or one of the
  /// account's this one trusts: a key from a device the server merely lists
  /// could be anyone's, and waits until a code is compared with it, or one
  /// that is trusted vouches for it.
  Future<void> _fromTrusted(_Run run, KeyDelivery delivery) async {
    bool trusts(Peer? own) {
      return own?.devices.any((each) => each.id == delivery.fromDeviceId && each.trusted) ?? false;
    }

    if (delivery.fromDeviceId == run.device?.id || trusts(run.peers[run.userId])) return;
    // read again only for a device not known yet: one known and not trusted
    // waits for the word that trust changed, which hands it over again
    final known = run.peers[run.userId]?.devices.any((each) => each.id == delivery.fromDeviceId) ?? false;
    if (!known && trusts(await devicesOf(run.userId))) return;
    throw const _Held();
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
