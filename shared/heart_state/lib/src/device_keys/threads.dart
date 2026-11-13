part of '../device_keys.dart';

/// A message sealed for a thread: the [content] that goes on the wire, and
/// the franking [commitment] that travels beside it.
typedef SealedMessage = ({String content, String commitment});

/// One stored thread item, as opening it needs it: [senderId] is who the
/// server says sent it, which has to be whoever shared the key it was sealed
/// under.
typedef ThreadCiphertext = ({String id, String? senderId, String content, String commitment});

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
  /// [userId]'s, and of the account's own, that doesn't hold it yet.
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
}

/// Stored threads (Megolm) for messages (#556), in the vault beside the
/// device's own keys.
///
/// Each device seals with a key of its own per thread, and shares it, inside
/// pairwise sessions, with every device of both people. A key is shared from
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
    var record = await _serial(run, () => _ThreadRecord.read(run, threadId));
    if (fresh && record.own.every((key) => readers.every((reader) => _covers(run, key, reader)))) return;

    for (final reader in readers) {
      // only the other person's devices answer to the link's fingerprint
      final checked = switch (reader == userId) {
        true => fingerprint,
        false => null,
      };
      final peer = await devicesOf(reader, fingerprint: checked);
      if (peer.check == .mismatch) throw KeyMismatch(reader);
      final listed = {for (final each in peer.devices) each.id};
      // the other person with no device to read it on: nothing is sent yet
      if (reader == userId && listed.isEmpty) throw const KeyFailure('no_devices');
      record = await _serial(run, () => _ThreadRecord.read(run, threadId));
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
        final missing = listed.where((id) => id != run.device?.id && !key.shared.containsKey(id)).toSet();
        if (missing.isEmpty) continue;
        final reached = await deliver(
          userId: reader,
          kind: DeviceKeys.threadKeyKind,
          payload: jsonEncode({'t': threadId, 'k': key.sessionKey}),
          fingerprint: checked,
          to: (device) => missing.contains(device.id),
        );
        if (reached.isEmpty) {
          // a key none of the other person's devices holds: what it seals
          // waits; one of the account's own can catch up later
          if (reader == userId && !key.shared.containsValue(userId)) throw const KeyFailure('key_unreached');
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
    run.sharedAt[threadId] = _now();
  }

  /// Whether [key] reached every device of [reader]'s this device last read.
  bool _covers(_Run run, _OwnKey key, String reader) {
    final peer = run.peers[reader];
    if (peer == null) return false;
    return peer.devices.every((each) => each.id == run.device?.id || key.shared.containsKey(each.id));
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
