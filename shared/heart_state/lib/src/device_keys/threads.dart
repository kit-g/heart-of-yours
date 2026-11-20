part of '../device_keys.dart';

/// A message sealed for a thread: the [content] that goes on the wire, and
/// the franking [commitment] that travels beside it.
typedef SealedMessage = ({String content, String commitment});

/// One stored thread item, as opening it needs it: [senderId] is who the
/// server says sent it, which has to be whoever shared the key it was sealed
/// under.
typedef ThreadCiphertext = ({String id, String? senderId, String content, String commitment});

/// A device asked this one for keys it made for [threadId]: [deviceId] is
/// the device that asked and [userId] whose it is, already known to be one
/// whom this device's keys for the thread reached; [sessions] the keys it
/// lacks, of those this device made.
typedef KeyRequest = ({String threadId, String userId, String deviceId, Set<String> sessions});

/// Answers whether [KeyRequest] was dealt with, answered or turned down for
/// good; false keeps it on the device to be handed over again later.
typedef KeyRequestHandler = Future<bool> Function(KeyRequest request);

/// What became of opening one thread item.
sealed class OpenedMessage {
  const new();
}

/// Opened: the words, and what a report needs to show they were said.
final class Opened extends OpenedMessage {
  final String text;

  /// The key that proves [text] against the item's commitment.
  final String frankingKey;

  const new({required this.text, required this.frankingKey});
}

/// Sealed under a key that hasn't reached this device yet: it opens once it
/// arrives.
final class Locked extends OpenedMessage {
  const new();
}

/// Never opens here: not a sealed message, sealed under a key its sender
/// didn't share, words that don't match their commitment, or a second message
/// at a position another already took.
final class Refused extends OpenedMessage {
  const new();
}

/// What messages want of encryption (#556): sealing to a thread, sharing its
/// key with whoever reads it, and opening what is stored there.
abstract interface class ThreadCipher {
  /// Seals [text] for [threadId] under this device's current key for it,
  /// which it makes the first time. Needs no network.
  Future<SealedMessage> seal(String threadId, String text);

  /// Hands every key this device made for [threadId] to each device of
  /// [userId]'s, and of the account's own that this device trusts, that
  /// doesn't hold it yet.
  ///
  /// Refuses with [KeyMismatch] when [userId]'s devices don't match
  /// [fingerprint].
  Future<void> share(String threadId, {required String userId, String? fingerprint});

  /// Opens [items], in the server's order: the first item at a position wins
  /// it, and a later one there is [Refused].
  Future<List<OpenedMessage>> open(String threadId, List<ThreadCiphertext> items);

  /// Reads what waits for this device, thread keys among it: what a thread
  /// shown [Locked] asks for when no push said a key was there.
  Future<void> receive();

  /// The thread whose key just arrived, so what was [Locked] can open.
  Stream<String> get threadKeys;

  /// Asks whoever sealed [items] for the keys this device lacks to open them,
  /// once in a while per key, however often it is called. The other person's
  /// devices are checked against [fingerprint]. Never throws: what fails is
  /// reported, and asked again later.
  Future<void> ask(String threadId, List<ThreadCiphertext> items, {String? fingerprint});

  /// Who decides whether a request for keys is answered: what reads the
  /// threads. Until there is one, requests wait on the device.
  set onKeyRequest(KeyRequestHandler? handler);

  /// Hands the keys [request] names to the device that asked, when it is one
  /// this device shares with: the other person's checked against
  /// [fingerprint], the account's own once trusted. Refuses with [KeyMismatch]
  /// as [share] does.
  Future<void> answer(KeyRequest request, {String? fingerprint});
}

/// Stored threads (Megolm) for messages (#556), in the vault beside the
/// device's own keys.
///
/// Each device seals with a key of its own per thread, and shares it, inside
/// pairwise sessions, with every device of the other person's, and with the
/// account's own devices this one trusts: pinned, which a compared code
/// makes them, or vouched for from one that is. A key is shared from
/// its first message, so a device that comes later reads the whole session.
/// A key is replaced after [_messagesPerKey] messages, after [_keyLife], when
/// one of the devices it reached is removed, and when its saved state turns
/// out older than its counter: a state restored from somewhere would seal at
/// positions already used.
extension _Threads on DeviceKeys {
  static const _messagesPerKey = 100;
  static const _keyLife = Duration(days: 7);

  /// How long a share that reached everyone holds before devices are read
  /// again, unless one of them changed meanwhile.
  static const _shareLife = Duration(minutes: 10);

  /// How long before a key asked for and still missing is asked for again.
  static const _askAgain = Duration(minutes: 15);

  /// The most keys one request names: it travels in a single queue item.
  static const _keysPerAsk = 4;

  Future<SealedMessage> _seal(String threadId, String text) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    await _local(run);
    return _serial(run, () async {
      final franked = Sealbox.frank(text);
      final record = await _ThreadRecord.read(run, threadId);
      // a second try under a new key, when the first finds its state stale
      final sealed =
          await _sealOnce(run, threadId, record, franked.inner) ??
          await _sealOnce(run, threadId, record, franked.inner) ??
          (throw const KeyFailure('stale_thread_key'));
      return (content: sealed, commitment: franked.commitment);
    });
  }

  /// Seals [inner] under [record]'s current key, made or replaced when due,
  /// and answers the content to send. Null when the key's state is older than
  /// its counter: it would seal at a position already used, so the key is
  /// dropped for the next try to replace.
  Future<String?> _sealOnce(_Run run, String threadId, _ThreadRecord record, String inner) async {
    final current = switch (record.current) {
      final _Outbound out when !out.due(_now(), _messagesPerKey, _keyLife) => out,
      _ => await _newKey(run, threadId, record),
    };
    final sealed = _guard(() => run.sealbox.sealToThread(current.outbound, inner));
    final counter = await run.read('thread.$threadId.next.${sealed.sessionId}');
    if (sealed.messageIndex < (int.tryParse(counter ?? '') ?? 0)) {
      record.current = null;
      return null;
    }
    // saved before it travels: an older state would reuse the position
    record.current = current.copyWith(outbound: sealed.outbound, count: sealed.messageIndex + 1);
    await record.save(run);
    await run.write('thread.$threadId.next.${sealed.sessionId}', '${sealed.messageIndex + 1}');
    return _ThreadEnvelope(sessionId: sealed.sessionId, ciphertext: sealed.ciphertext).encode();
  }

  /// A new key for [threadId], joined at once so this device reads its own.
  Future<_Outbound> _newKey(_Run run, String threadId, _ThreadRecord record) async {
    final made = _guard(run.sealbox.newThread);
    final joined = _guard(() => run.sealbox.joinThread(made.sessionKey));
    final inbound = await _InboundKeys.read(run, threadId);
    inbound.keys[joined.sessionId] = (inbound: joined.inbound, from: run.userId);
    await inbound.save(run);
    await run.addThread(threadId);
    final out = _Outbound(outbound: made.outbound, sessionId: made.sessionId, createdAt: _now(), count: 0);
    record
      ..current = out
      ..own.add(_OwnKey(sessionId: made.sessionId, sessionKey: made.sessionKey, shared: {}));
    await record.save(run);
    return out;
  }

  Future<void> _share(String threadId, {required String userId, String? fingerprint}) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    final readers = {userId, run.userId};
    final fresh = switch (run.sharedAt[threadId]) {
      final DateTime at => _now().difference(at) < _shareLife,
      null => false,
    };
    final record = await _serial(run, () => _ThreadRecord.read(run, threadId));
    if (fresh && record.own.every((key) => readers.every((reader) => _covers(run, key, reader)))) return;

    await _sharing(run, threadId, () async {
      for (final reader in readers) {
        // only the other person's devices answer to the link's fingerprint
        final checked = switch (reader == userId) {
          true => fingerprint,
          false => null,
        };
        final peer = await devicesOf(reader, fingerprint: checked);
        if (peer.check == .mismatch) throw KeyMismatch(reader);
        // the other person with no device to read it on: nothing is sent yet
        if (reader == userId && peer.devices.isEmpty) throw const KeyFailure('no_devices');
        await _shareWith(run, threadId, peer, fingerprint: checked, other: reader == userId);
      }
    });
    run.sharedAt[threadId] = _now();
  }

  /// Runs [step], one of [threadId]'s shares, after any other under way: each
  /// reads whom the keys reached, and two at once would both send them.
  Future<void> _sharing(_Run run, String threadId, Future<void> Function() step) {
    final done = (run.sharing[threadId] ?? Future<void>.value()).then((_) {
      run.check();
      return step();
    });
    run.sharing[threadId] = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  /// Hands every key this device made for [threadId] to [peer]'s devices
  /// that get them and don't hold them yet. A key that reached none of the
  /// [other] person's devices throws: what it seals would wait.
  ///
  /// [resend] names keys a device asked for, which it gets again even when
  /// they reached it before: they never opened there.
  Future<void> _shareWith(
    _Run run,
    String threadId,
    Peer peer, {
    String? fingerprint,
    required bool other,
    ({String deviceId, Set<String> sessions})? resend,
  }) async {
    final reader = peer.userId;
    final listed = {for (final each in peer.devices) each.id};
    final receiving = {
      for (final each in peer.devices)
        if (_receives(run, peer, each)) each.id,
    };
    final record = await _serial(run, () => _ThreadRecord.read(run, threadId));
    // a device that held the current key and is gone: the next message
    // seals under a new one
    if (record.own.lastOrNull case final _OwnKey last when record.current?.sessionId == last.sessionId) {
      final gone = last.shared.entries.where((each) => each.value == reader && !listed.contains(each.key));
      if (gone.isNotEmpty) {
        await _serial(run, () async {
          final latest = await _ThreadRecord.read(run, threadId);
          latest.current = null;
          await latest.save(run);
        });
      }
    }
    for (final key in record.own) {
      final again = switch (resend) {
        (:final deviceId, :final sessions) when sessions.contains(key.sessionId) => deviceId,
        _ => null,
      };
      final missing = receiving
          .where((id) => id != run.device?.id && (!key.shared.containsKey(id) || id == again))
          .toSet();
      if (missing.isEmpty) continue;
      final reached = await deliver(
        userId: reader,
        kind: DeviceKeys.threadKeyKind,
        payload: jsonEncode({'t': threadId, 'k': key.sessionKey}),
        fingerprint: fingerprint,
        to: (device) => missing.contains(device.id),
      );
      if (reached.isEmpty) {
        // a key none of the other person's devices holds: what it seals
        // waits; one of the account's own can catch up later
        if (other && !key.shared.containsValue(reader)) throw const KeyFailure('key_unreached');
        continue;
      }
      await _serial(run, () async {
        final latest = await _ThreadRecord.read(run, threadId);
        for (final each in latest.own.where((each) => each.sessionId == key.sessionId)) {
          each.shared.addAll({for (final id in reached) id: reader});
        }
        await latest.save(run);
      });
    }
  }

  /// Hands the keys of every thread this device made one for to the
  /// account's devices it trusts and that don't hold them yet: a device just
  /// let in reads what was said before it, without waiting for the next
  /// message.
  Future<void> _shareThreadsWithOwn(_Run run) async {
    final threads = await _serial(run, run.threads);
    if (threads.isEmpty) return;
    final own = run.peers[run.userId] ?? await devicesOf(run.userId);
    for (final threadId in threads) {
      await _sharing(run, threadId, () => _shareWith(run, threadId, own, other: false));
    }
  }

  /// Whether [key] reached every device of [reader]'s this device last read
  /// and shares with.
  bool _covers(_Run run, _OwnKey key, String reader) {
    final peer = run.peers[reader];
    if (peer == null) return false;
    return peer.devices.every(
      (each) => each.id == run.device?.id || !_receives(run, peer, each) || key.shared.containsKey(each.id),
    );
  }

  /// Whether [device], one of [peer]'s, gets this device's thread keys. The
  /// account's own, and the other person's once a fingerprint anchored them,
  /// only once trusted: one the server merely lists could be anyone's, and
  /// gets its keys once a code is compared with it or a trusted one vouches.
  /// With no fingerprint known (a coach's side towards a student, or a link
  /// opened some other way) there is no anchor to trust from, so every device
  /// listed gets them, as the thread says.
  bool _receives(_Run run, Peer peer, PeerDevice device) {
    return switch ((peer.userId == run.userId, peer.check)) {
      (true, _) || (false, .matched) => device.trusted,
      (false, .nothingToCheck || .noDevices || .mismatch) => true,
    };
  }

  Future<List<OpenedMessage>> _openThread(String threadId, List<ThreadCiphertext> items) async {
    final run = _run;
    if (run == null) return [for (final _ in items) const Locked()];
    await _local(run);
    final inbound = await _serial(run, () => _InboundKeys.read(run, threadId));
    // (session, position) → the item that took it
    final taken = <(String, int), String>{};
    return [
      for (final item in items) _openOne(run, inbound, item, taken),
    ];
  }

  OpenedMessage _openOne(_Run run, _InboundKeys inbound, ThreadCiphertext item, Map<(String, int), String> taken) {
    final envelope = _ThreadEnvelope.decode(item.content);
    if (envelope == null) return const Refused();
    final key = inbound.keys[envelope.sessionId];
    if (key == null) return const Locked();
    // sealed under a key someone else shared: not what its sender said
    if (key.from != item.senderId) return const Refused();
    try {
      final opened = run.sealbox.openFromThread(key.inbound, envelope.ciphertext);
      final position = (opened.sessionId, opened.messageIndex);
      if (taken[position] case final String other when other != item.id) return const Refused();
      taken[position] = item.id;
      final franked = Sealbox.openFranked(inner: opened.plaintext, commitment: item.commitment);
      return Opened(text: franked.plaintext, frankingKey: franked.frankingKey);
    } on SealboxException catch (error) {
      return switch (error.code) {
        // a key that starts past this message: an earlier one may still come
        'not_known' => const Locked(),
        _ => const Refused(),
      };
    }
  }

  /// Asks the senders of [items] for the keys this device lacks, one request
  /// to each sender's devices: only the device that made a key answers it.
  /// Each key is asked for once in [_askAgain], kept across launches, whether
  /// the request went or failed.
  Future<void> _ask(String threadId, List<ThreadCiphertext> items, String? fingerprint) async {
    final run = _run;
    if (run == null || !_remote.allowed || !(run.device?.published ?? false)) return;
    final (inbound, asked) = await _serial(run, () async {
      return (await _InboundKeys.read(run, threadId), await _Asked.read(run, threadId));
    });
    final now = _now();
    bool wants(String sessionId) {
      if (inbound.keys.containsKey(sessionId)) return false;
      return switch (asked.at[sessionId]) {
        final DateTime at => now.difference(at) >= _askAgain,
        null => true,
      };
    }

    // sender → the keys of theirs this device lacks and hasn't asked for lately
    final wanted = {
      for (final sender in items.map((item) => item.senderId).nonNulls.toSet())
        sender: {
          for (final item in items)
            if ((item.senderId, _ThreadEnvelope.decode(item.content))
                case (
                  final String from,
                  _ThreadEnvelope(:final sessionId),
                )
                when from == sender && wants(sessionId))
              sessionId,
        },
    }..removeWhere((_, sessions) => sessions.isEmpty);
    for (final MapEntry(key: sender, value: sessions) in wanted.entries) {
      final own = sender == run.userId;
      for (final batch in _batches(sessions.toList(), _keysPerAsk)) {
        final asked = await _askOnce(run, sender, threadId, batch, own ? null : fingerprint, own: own);
        // a request that reached no device, as when none of the account's own
        // is trusted yet, is asked again as soon as one could answer it
        if (!asked) continue;
        await _serial(run, () async {
          final latest = await _Asked.read(run, threadId);
          latest.at.removeWhere((_, at) => now.difference(at) >= _askAgain);
          latest.at.addAll({for (final session in batch) session: now});
          await latest.save(run);
        });
      }
    }
  }

  /// Sends one request for [sessions] to [sender]'s devices: answers whether it
  /// counts as asked, which is when it reached a device or failed. A failure is
  /// reported, unless [sender] can no longer be reached at all.
  Future<bool> _askOnce(
    _Run run,
    String sender,
    String threadId,
    List<String> sessions,
    String? fingerprint, {
    required bool own,
  }) async {
    try {
      final reached = await deliver(
        userId: sender,
        kind: DeviceKeys.threadKeyRequestKind,
        payload: jsonEncode({'t': threadId, 's': sessions}),
        fingerprint: fingerprint,
        // only a device whose keys this one would take could have made them:
        // the account's own once trusted, the other person's once the
        // fingerprint anchored them, and any of theirs without one
        to: (device) => device.trusted || (!own && fingerprint == null),
      );
      return reached.isNotEmpty;
    } on NetworkException catch (refusal, stacktrace) {
      switch (refusal) {
        // someone this account can no longer reach, as under a block or after
        // their account went: nothing to report
        case NetworkException(isRefusal: true, body: {'code': 'forbidden' || 'not_found' || 'bad_request'}):
          break;
        default:
          _report(refusal, stacktrace);
      }
      return true;
    } on _Stopped {
      rethrow;
    } catch (error, stacktrace) {
      _report(error, stacktrace);
      return true;
    }
  }

  /// Takes a request for keys: handed to [DeviceKeys.onKeyRequest] when this
  /// device made one of them and whoever asked is one its keys for the thread
  /// reached, or the account itself; dropped otherwise. Kept on the device
  /// until it is dealt with.
  Future<void> _takeKeyRequest(KeyDelivery delivery) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    final (threadId, sessions) = switch (_decodeMap(delivery.payload)) {
      {'t': final String threadId, 's': final List sessions} => (threadId, sessions.whereType<String>().toSet()),
      _ => (null, const <String>{}),
    };
    if (threadId == null) {
      _report(const KeyFailure('unreadable_key_request'));
      return;
    }
    final record = await _serial(run, () => _ThreadRecord.read(run, threadId));
    final made = {for (final key in record.own) key.sessionId}.intersection(sessions);
    if (made.isEmpty) return;
    final readers = {run.userId, for (final key in record.own) ...key.shared.values};
    if (!readers.contains(delivery.fromUserId)) return;
    final handler = _onKeyRequest;
    if (handler == null) throw const _Held();
    final request = (threadId: threadId, userId: delivery.fromUserId, deviceId: delivery.fromDeviceId, sessions: made);
    if (!await handler(request)) throw const _Held();
  }

  Future<void> _answer(KeyRequest request, String? fingerprint) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    final own = request.userId == run.userId;
    final checked = switch (own) {
      true => null,
      false => fingerprint,
    };
    await _sharing(run, request.threadId, () async {
      final peer = await devicesOf(request.userId, fingerprint: checked);
      if (peer.check == .mismatch) throw KeyMismatch(request.userId);
      await _shareWith(
        run,
        request.threadId,
        peer,
        fingerprint: checked,
        other: false,
        resend: (deviceId: request.deviceId, sessions: request.sessions),
      );
    });
  }

  /// Takes a thread key another device shared.
  Future<void> _takeThreadKey(KeyDelivery delivery) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    final (threadId, sessionKey) = switch (_decodeMap(delivery.payload)) {
      {'t': final String threadId, 'k': final String sessionKey} => (threadId, sessionKey),
      // nothing will ever open it: taken, and dropped
      _ => (null, null),
    };
    if (threadId == null || sessionKey == null) {
      _report(const KeyFailure('unreadable_thread_key'));
      return;
    }
    // a key from the account's own devices only from one this device trusts:
    // kept until it is, and taken then
    if (delivery.fromUserId == run.userId) await _fromTrusted(run, delivery);
    final taken = await _serial(run, () async {
      final ({String inbound, String sessionId, int firstKnownIndex}) joined;
      try {
        joined = _guard(() => run.sealbox.joinThread(sessionKey));
      } on KeyFailure catch (failure) {
        // a key the library refuses opens nothing, however often it is handed
        // again: taken, and dropped
        _report(failure);
        return false;
      }
      final inbound = await _InboundKeys.read(run, threadId);
      // the first one kept: a second share of the same key reaches no further back
      inbound.keys.putIfAbsent(joined.sessionId, () => (inbound: joined.inbound, from: delivery.fromUserId));
      await inbound.save(run);
      return true;
    });
    if (taken && !_threadKeys.isClosed) _threadKeys.add(threadId);
  }
}

Map? _decodeMap(String json) {
  try {
    return switch (jsonDecode(json)) {
      final Map map => map,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// What travels as a thread item's content: the key's session, which the
/// ciphertext doesn't name, and the ciphertext. `m1.<session>.<ciphertext>`.
class _ThreadEnvelope {
  final String sessionId;
  final String ciphertext;

  const new({required this.sessionId, required this.ciphertext});

  static const _version = 'm1';

  String encode() => [_version, sessionId, ciphertext].join('.');

  static _ThreadEnvelope? decode(String content) {
    return switch (content.split('.')) {
      [_version, final String sessionId, final String ciphertext] when sessionId.isNotEmpty && ciphertext.isNotEmpty =>
        _ThreadEnvelope(sessionId: sessionId, ciphertext: ciphertext),
      _ => null,
    };
  }
}

/// This device's current key for sealing to a thread.
class _Outbound {
  final String outbound;
  final String sessionId;
  final DateTime createdAt;

  /// Messages sealed under it.
  final int count;

  const new({required this.outbound, required this.sessionId, required this.createdAt, required this.count});

  bool due(DateTime now, int most, Duration life) => count >= most || now.difference(createdAt) >= life;

  _Outbound copyWith({String? outbound, int? count}) {
    return _Outbound(
      outbound: outbound ?? this.outbound,
      sessionId: sessionId,
      createdAt: createdAt,
      count: count ?? this.count,
    );
  }

  Map<String, Object> toMap() => {
    'outbound': outbound,
    'sessionId': sessionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'count': count,
  };

  static _Outbound? of(Object? json) {
    return switch (json) {
      {
        'outbound': final String outbound,
        'sessionId': final String sessionId,
        'createdAt': final String createdAt,
        'count': final int count,
      } =>
        switch (DateTime.tryParse(createdAt)) {
          final DateTime at => _Outbound(outbound: outbound, sessionId: sessionId, createdAt: at, count: count),
          null => null,
        },
      _ => null,
    };
  }
}

/// A key this device made for a thread, and the devices it reached, each with
/// whose it is.
class _OwnKey {
  final String sessionId;
  final String sessionKey;
  final Map<String, String> shared;

  const new({required this.sessionId, required this.sessionKey, required this.shared});

  Map<String, Object> toMap() => {'sessionId': sessionId, 'sessionKey': sessionKey, 'shared': shared};

  static _OwnKey? of(Object? json) {
    return switch (json) {
      {'sessionId': final String sessionId, 'sessionKey': final String sessionKey, 'shared': final Map shared} =>
        _OwnKey(
          sessionId: sessionId,
          sessionKey: sessionKey,
          shared: {for (final MapEntry(:key, :value) in shared.entries) '$key': '$value'},
        ),
      _ => null,
    };
  }
}

/// What this device keeps of its own keys for one thread.
class _ThreadRecord {
  final String threadId;
  _Outbound? current;
  final List<_OwnKey> own;

  new(this.threadId, {this.current, List<_OwnKey>? own}) : own = own ?? [];

  static Future<_ThreadRecord> read(_Run run, String threadId) async {
    return switch (_Run._decode(await run.read('thread.$threadId'))) {
      {'own': final List own} && final map => _ThreadRecord(
        threadId,
        current: _Outbound.of(map['current']),
        own: [...own.map(_OwnKey.of).nonNulls],
      ),
      _ => _ThreadRecord(threadId),
    };
  }

  Future<void> save(_Run run) {
    return run.write(
      'thread.$threadId',
      jsonEncode({
        'current': ?current?.toMap(),
        'own': [for (final each in own) each.toMap()],
      }),
    );
  }
}

/// The keys this device reads a thread with, by session, each with whose it is.
class _InboundKeys {
  final String threadId;
  final Map<String, ({String inbound, String from})> keys;

  const new(this.threadId, this.keys);

  static Future<_InboundKeys> read(_Run run, String threadId) async {
    return switch (_Run._decode(await run.read('thread.$threadId.in'))) {
      final Map map => _InboundKeys(threadId, {
        for (final MapEntry(:key, :value) in map.entries)
          if (value case {'inbound': final String inbound, 'from': final String from})
            '$key': (inbound: inbound, from: from),
      }),
      null => _InboundKeys(threadId, {}),
    };
  }

  Future<void> save(_Run run) {
    return run.write(
      'thread.$threadId.in',
      jsonEncode({
        for (final MapEntry(:key, :value) in keys.entries) key: {'inbound': value.inbound, 'from': value.from},
      }),
    );
  }
}

/// When each key of a thread this device lacks was last asked for, by
/// session: kept in the vault, so a relaunch doesn't ask again at once.
class _Asked {
  final String threadId;
  final Map<String, DateTime> at;

  const new(this.threadId, this.at);

  static Future<_Asked> read(_Run run, String threadId) async {
    return switch (_Run._decode(await run.read('thread.$threadId.asked'))) {
      final Map map => _Asked(threadId, {
        for (final MapEntry(:key, :value) in map.entries)
          if (value case final String value)
            if (DateTime.tryParse(value) case final DateTime at) '$key': at,
      }),
      null => _Asked(threadId, {}),
    };
  }

  Future<void> save(_Run run) {
    return run.write(
      'thread.$threadId.asked',
      jsonEncode({for (final MapEntry(:key, :value) in at.entries) key: value.toUtc().toIso8601String()}),
    );
  }
}
