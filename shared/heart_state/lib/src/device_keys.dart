import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sealbox/sealbox.dart';

import 'remote.dart';

/// What the server does with device keys (heart-of-yours#555).
///
/// Defined here, like `RemotePushService`: the app's view of a few routes,
/// which it adapts `Api` onto.
abstract interface class RemoteKeyService {
  Future<CryptoDevice> publishCryptoDevice({
    required String id,
    required String identityKey,
    required String signingKey,
    required String fallbackKey,
    ({String signature, String vouchedBy})? vouch,
  });

  Future<List<CryptoDevice>> getCryptoDevices({String? userId});

  Future<int> addOneTimeKeys(String deviceId, Map<String, String> keys);

  Future<int> countOneTimeKeys(String deviceId);

  Future<void> replaceFallbackKey(String deviceId, String key);

  Future<List<CryptoDevice>> claimKeys(String userId);

  Future<void> enqueueKeyItem({
    required String id,
    required String recipientDeviceId,
    required String senderDeviceId,
    required String kind,
    required String content,
  });

  Future<List<QueuedItem>> getKeyQueue(String deviceId);

  Future<void> confirmKeyItems(String deviceId, List<String> ids);
}

/// Where a device keeps its keys: on this device only, out of every backup
/// and every transfer to a new phone (the Keychain's this-device-only class,
/// Android's Keystore). A phone restored from a backup would reuse keys it had
/// already used, so a restored phone has to start as a new device.
abstract interface class KeyVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// How far a device of someone else's can be trusted to be theirs.
enum DeviceTrust {
  /// Its keys match the fingerprint the person's invitation link carried, or
  /// it is this device.
  pinned,

  /// A device that is [pinned], or vouched for in turn, signed its keys.
  vouched,

  /// Nothing on this device can tell whether it is theirs.
  unverified,
}

/// What a person's devices say, checked against what this device knows.
enum PeerCheck {
  /// One device matches the fingerprint this device was given.
  matched,

  /// There was no fingerprint to check against: their link was opened some
  /// other way, or this is someone who never sent one. Comparing a code is
  /// the only check left.
  nothingToCheck,

  /// A fingerprint was given and none of their devices matches it: the keys
  /// the server handed out may not be theirs. Nothing is sent to them.
  mismatch,

  /// They hold no keys yet, as someone who accepted on the web and never
  /// opened Heart on a device.
  noDevices,
}

/// One device of a person's, and how far it is trusted.
class PeerDevice {
  final CryptoDevice device;
  final DeviceTrust trust;

  /// When this device first saw it, for a device that came after the first
  /// look at the person's devices. Null for one that was there from the start.
  final DateTime? addedAt;

  const new({required this.device, required this.trust, this.addedAt});

  String get id => device.id;

  bool get vouched => device.vouchedBy != null;
}

/// A person's devices as last read.
class Peer {
  final String userId;
  final List<PeerDevice> devices;
  final PeerCheck check;

  const new({required this.userId, required this.devices, required this.check});

  /// Devices added after the first look, newest first: what a thread says when
  /// the other person added one, and whether it was vouched for.
  Iterable<PeerDevice> get added {
    return devices.where((each) => each.addedAt != null).toList()..sort((a, b) => b.addedAt!.compareTo(a.addedAt!));
  }
}

/// One item that arrived for this device, opened.
class KeyDelivery {
  /// The queue's id for it.
  final String id;

  /// What it is, in the sender's words, such as a thread key.
  final String kind;

  final String payload;

  /// Whose device sent it, as that person's own device list says.
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

/// Thrown when a person's devices don't match the fingerprint this device was
/// given for them: nothing is sent.
class KeyMismatch implements Exception {
  final String userId;

  const new(this.userId);

  @override
  String toString() => 'KeyMismatch($userId)';
}

/// A failure inside the encryption library, by its code alone: what it says
/// beyond that never leaves the device, since it may name a key.
class KeyFailure implements Exception {
  final String code;

  const new(this.code);

  @override
  String toString() => 'KeyFailure($code)';
}

/// Where this device stands with its keys.
enum DeviceKeysStatus {
  /// Not running: no account, or both coaching switches off.
  off,

  /// Keys made and kept on the device, not yet on the server.
  local,

  /// The server holds this device's public keys.
  published,

  /// The server refused, or could not be reached; tried again on the next
  /// start or resume.
  failed,
}

/// This device's keys for end-to-end encryption, and carrying sealed items
/// between devices (heart-of-yours#555).
///
/// A device has an identity of its own (an id it chose, an identity key, a
/// signing key) and a stock of single-use keys others take to start a session
/// with it. The private halves live in a [KeyVault] and never leave the
/// device. What travels between two devices goes through a pairwise session,
/// one item at a time, through the server's queue, which sees only sealed text.
///
/// Opt-in through coaching: [start] runs only with an account and a coaching
/// switch on, and until then nothing is made and nothing goes over the wire.
/// [stop] is a switch going off: the keys stay where they are, inert, and come
/// back as they were.
///
/// What arrives is kept on the device until a handler for its kind takes it
/// ([on]): messages (#556) bring the first one, thread keys.
class DeviceKeys with ChangeNotifier implements SignOutStateSentry {
  final RemoteKeyService _service;
  final KeyVault? _vault;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final String Function() _newId;
  final DateTime Function() _now;

  new({
    required this._service,
    required this._vault,
    RemoteAccess? remote,
    this.onError,
    String Function()? newId,
    DateTime Function()? now,
  }) : _remote = remote ?? RemoteAccess(),
       _newId = newId ?? uuidV7,
       _now = now ?? DateTime.now;

  static DeviceKeys of(BuildContext context) => Provider.of<DeviceKeys>(context, listen: false);

  static DeviceKeys watch(BuildContext context) => Provider.of<DeviceKeys>(context, listen: true);

  /// Names a device's keys in a fingerprint. Part of every invitation link a
  /// coach sends, so changing it breaks the links still out there.
  static const fingerprintContext = 'heart-of.me/device-keys/v1';

  /// What one device signs to vouch for another of the same person's.
  static String vouchMessage(CryptoDevice device) {
    return [
      'heart-of.me/vouch/v1',
      device.userId,
      device.id,
      device.identityKey,
      device.signingKey,
    ].join('\n');
  }

  /// The most single-use keys a device holds, the server's and the library's
  /// limit alike.
  static const _oneTimeKeys = Sealbox.maxOneTimeKeys;

  /// Below this many on the server, more are made.
  static const _lowOneTimeKeys = _oneTimeKeys ~/ 2;

  /// How long a fallback key serves before a new one replaces it.
  static const _fallbackLife = Duration(days: 7);

  /// The most a queue item may carry.
  static const _maxItem = 1024;

  String? _userId;
  _Device? _device;
  Sealbox? _box;
  DeviceKeysStatus _status = .off;
  final _peers = <String, Peer>{};
  final _handlers = <String, KeyDeliveryHandler>{};

  /// One thing at a time: every step reads and writes the same account and
  /// sessions, and items go out one by one, in order.
  Future<void> _tail = Future.value();

  /// Handing deliveries over, one run at a time.
  Future<void> _dispatching = Future.value();

  DeviceKeysStatus get status => _status;

  /// This device's id, once it has keys.
  String? get deviceId => _device?.id;

  /// A person's devices as last read, or null before the first read.
  Peer? peer(String userId) => _peers[userId];

  /// This device's fingerprint: what a coach's invitation link carries after
  /// `#`, for the student's device to check the coach's keys against. Makes
  /// the keys first if this device has none, which needs no network. Null
  /// while keys don't run, or when the vault can't be read: a link without
  /// one still works, and the thread says there was nothing to check.
  Future<String?> fingerprint() {
    return _serial(() async {
      final userId = _userId;
      if (userId == null) return null;
      try {
        final device = await _local(userId);
        final keys = _sealbox.accountKeys(device.account);
        return Sealbox.fingerprint(
          identityKey: keys.identityKey,
          signingKey: keys.signingKey,
          context: fingerprintContext,
        );
      } catch (error, stacktrace) {
        _report(error, stacktrace);
        return null;
      }
    });
  }

  /// This device's signature over another device of the same person's, once
  /// the two have compared a code: what lets the new one in.
  Future<String> vouchFor(CryptoDevice device) {
    return _serial(() async {
      final userId = _userId;
      if (userId == null || device.userId != userId) {
        throw StateError('only a device of the same account is vouched for');
      }
      final own = await _local(userId);
      return _guard(() => _sealbox.sign(own.account, vouchMessage(device)));
    });
  }

  /// Starts keys for [userId]: makes them on the first start, publishes them
  /// until the server has them, keeps single-use keys stocked and reads what
  /// arrived. Safe to repeat.
  Future<void> start(String userId) {
    if (_vault == null) return Future.value();
    if (_userId != userId) {
      _forget();
      _userId = userId;
    }
    // a start already on its way is the one asked for again
    return _starting ??= refresh().whenComplete(() => _starting = null);
  }

  Future<void>? _starting;

  /// A switch went off: forgets what is in memory and stops talking to the
  /// server. Everything on the device stays.
  void stop() {
    _forget();
    notifyListeners();
  }

  @override
  void onSignOut() => stop();

  void _forget() {
    _starting = null;
    _userId = null;
    _device = null;
    _box = null;
    _status = .off;
    _peers.clear();
  }

  /// Publishes, reads the queue and restocks: at a start, and whenever the app
  /// comes back to the front.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || !_remote.allowed) return;
    try {
      await _serial(() => _publish(userId));
      // read first: a session that arrived spent a single-use key, which makes
      // room for a new one
      await receive();
      await _serial(() => _restock(userId));
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  /// Takes deliveries of [kind]: what is already waiting at once, and every
  /// later one as it arrives.
  Future<void> on(String kind, KeyDeliveryHandler handler) async {
    _handlers[kind] = handler;
    if (_userId case final String userId when _vault != null) await _dispatch(userId);
  }

  /// Someone this device shares keys with added or removed a device.
  Future<void> devicesChanged(String userId) async {
    if (_userId == null || !_remote.allowed) return;
    try {
      await devicesOf(userId);
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  /// Reads [userId]'s devices and checks them: against [fingerprint], the one
  /// their invitation link carried, and against the ones that vouched for each
  /// other. The account's own id reads its own other devices, checked against
  /// this one.
  Future<Peer> devicesOf(String userId, {String? fingerprint}) {
    return _serial(() async {
      final me = _userId;
      if (me == null) throw StateError('device keys are off');
      final own = userId == me;
      final devices = await _service.getCryptoDevices(
        userId: switch (own) {
          true => null,
          false => userId,
        },
      );
      final peer = await _check(me, userId, devices, fingerprint: fingerprint);
      _peers[userId] = peer;
      notifyListeners();
      return peer;
    });
  }

  /// Seals [payload] to every device of [userId]'s that [to] lets through
  /// (all of them by default), each in its own pairwise session, and sends
  /// them one at a time. The account's own id sends to its other devices.
  ///
  /// Refuses with [KeyMismatch] when their devices don't match [fingerprint].
  Future<void> deliver({
    required String userId,
    required String kind,
    required String payload,
    String? fingerprint,
    bool Function(PeerDevice device)? to,
  }) {
    return _serial(() async {
      final me = _userId;
      final device = _device;
      if (me == null || device == null || !device.published || !_remote.allowed) {
        throw StateError('device keys are not published');
      }
      final own = userId == me;
      final listed = await _service.getCryptoDevices(
        userId: switch (own) {
          true => null,
          false => userId,
        },
      );
      final peer = await _check(me, userId, listed, fingerprint: fingerprint);
      _peers[userId] = peer;
      if (peer.check == .mismatch) throw KeyMismatch(userId);
      final targets = peer.devices.where((each) => each.id != device.id && (to?.call(each) ?? true)).toList();
      if (targets.isEmpty) return;

      // a device with no session yet needs one of its single-use keys
      final sessions = {for (final each in targets) each.id: await _session(me, each.id)};
      final claimed = switch (sessions.values.any((each) => each == null)) {
        true => {for (final each in await _service.claimKeys(userId)) each.id: each},
        false => const <String, CryptoDevice>{},
      };

      for (final target in targets) {
        final session = sessions[target.id] ?? _start(device, target.device, claimed[target.id]);
        // a device that came between the list and the claim waits for the next send
        if (session == null) continue;
        final sealed = _guard(() => _sealbox.encrypt(session.session, payload));
        // saved before it travels: a session used twice is a broken one
        await _saveSession(me, target.id, (
          session: sealed.session,
          sessionId: session.sessionId,
          identityKey: session.identityKey,
        ));
        final content = _Envelope(from: me, message: sealed.message).encode();
        if (content.length > _maxItem) throw ArgumentError.value(kind, 'kind', 'sealed past what the queue carries');
        await _service.enqueueKeyItem(
          id: _newId(),
          recipientDeviceId: target.id,
          senderDeviceId: device.id,
          kind: kind,
          content: content,
        );
      }
      notifyListeners();
    });
  }

  /// A new session to [target], from the keys a claim took for it.
  _Session? _start(_Device device, CryptoDevice target, CryptoDevice? claimed) {
    if (claimed == null || claimed.identityKey != target.identityKey) return null;
    final started = _guard(
      () => _sealbox.startSession(
        account: device.account,
        identityKey: claimed.identityKey,
        oneTimeKey: claimed.oneTimeKey ?? claimed.fallbackKey,
      ),
    );
    return (session: started.session, sessionId: started.sessionId, identityKey: claimed.identityKey);
  }

  /// Reads what waits for this device, opens it, keeps it, confirms it, then
  /// hands each item to the handler for its kind.
  Future<void> receive() async {
    final userId = _userId;
    if (userId == null) return;
    await _serial(() async {
      final device = _device;
      if (device == null || !device.published || !_remote.allowed) return;
      final items = await _service.getKeyQueue(device.id);
      if (items.isEmpty) return;
      final inbox = await _inbox(userId);
      final kept = {for (final each in inbox) each.id};
      // whose devices sent what, read once per sender
      final senders = <String, List<CryptoDevice>>{};
      for (final item in items.where((each) => !kept.contains(each.id))) {
        if (await _open(userId, item, senders) case final KeyDelivery opened) {
          // kept before it is confirmed: a pairwise message opens once
          await _saveInbox(userId, [...inbox, opened]);
          inbox.add(opened);
        }
      }
      await _service.confirmKeyItems(device.id, [for (final each in items) each.id]);
    });
    await _dispatch(userId);
  }

  // ---- the device's own keys ----

  /// This device's keys, made the first time.
  Future<_Device> _local(String userId) async {
    if (_device case final _Device device) return device;
    final vault = _vault!;
    final storageKey = await vault.read(_key(userId, 'storage')) ?? await _newStorageKey(userId);
    final box = _box = Sealbox(storageKey);
    final stored = _Device.of(_decode(await vault.read(_key(userId, 'device'))));
    final device = stored ?? await _create(userId, box);
    _device = device;
    if (_status == .off) {
      _status = switch (device.published) {
        true => .published,
        false => .local,
      };
    }
    return device;
  }

  Future<String> _newStorageKey(String userId) async {
    final random = Random.secure();
    final key = base64.encode(List.generate(32, (_) => random.nextInt(256)));
    await _vault!.write(_key(userId, 'storage'), key);
    return key;
  }

  Future<_Device> _create(String userId, Sealbox box) async {
    final made = _guard(() => box.createAccount(oneTimeKeys: _oneTimeKeys));
    final device = _Device(
      id: _newId(),
      account: made.account,
      published: false,
      pending: {for (final each in made.oneTimeKeys) each.id: each.key},
      fallbackKey: made.fallbackKey.key,
      fallbackAt: _now(),
    );
    await _saveDevice(userId, device);
    return device;
  }

  Future<void> _publish(String userId) async {
    var device = await _local(userId);
    if (device.published) return;
    final keys = _sealbox.accountKeys(device.account);
    try {
      await _service.publishCryptoDevice(
        id: device.id,
        identityKey: keys.identityKey,
        signingKey: keys.signingKey,
        fallbackKey: device.fallbackKey,
      );
    } on Map catch (refusal) {
      // a device removed for good can't come back under its id: this phone
      // starts over as a new one
      if (refusal case {'code': 'device_removed'}) {
        _device = null;
        await _vault!.delete(_key(userId, 'device'));
        device = await _create(userId, _box!);
        _device = device;
        return _publish(userId);
      }
      _status = .failed;
      notifyListeners();
      rethrow;
    }
    device = device.copyWith(published: true);
    await _saveDevice(userId, device);
    _status = .published;
    notifyListeners();
  }

  /// Keeps single-use keys on the server, and the fallback key fresh.
  Future<void> _restock(String userId) async {
    var device = await _local(userId);
    if (!device.published) return;
    final box = _sealbox;

    // what was made and never reached the server goes first
    if (device.pending.isNotEmpty) {
      await _service.addOneTimeKeys(device.id, device.pending);
      device = device.copyWith(pending: const {});
      await _saveDevice(userId, device);
    }

    final held = await _service.countOneTimeKeys(device.id);
    if (held < _lowOneTimeKeys) {
      // the library keeps every key not yet spent, claimed or not, so it may
      // have less room than the server
      final room = _oneTimeKeys - box.accountKeys(device.account).storedOneTimeKeys;
      final count = min(_oneTimeKeys - held, room);
      if (count > 0) {
        final made = _guard(() => box.generateOneTimeKeys(device.account, count));
        device = device.copyWith(
          account: made.account,
          pending: {for (final each in made.oneTimeKeys) each.id: each.key},
        );
        await _saveDevice(userId, device);
        await _service.addOneTimeKeys(device.id, device.pending);
        device = device.copyWith(pending: const {});
        await _saveDevice(userId, device);
      }
    }

    if (device.fallbackPending) {
      await _service.replaceFallbackKey(device.id, device.fallbackKey);
      device = device.copyWith(fallbackPending: false);
      await _saveDevice(userId, device);
    } else if (_now().difference(device.fallbackAt) > _fallbackLife) {
      final rotated = _guard(() => box.rotateFallbackKey(device.account));
      device = device.copyWith(
        account: rotated.account,
        fallbackKey: rotated.fallbackKey.key,
        fallbackAt: _now(),
        fallbackPending: true,
      );
      await _saveDevice(userId, device);
      await _service.replaceFallbackKey(device.id, rotated.fallbackKey.key);
      device = device.copyWith(fallbackPending: false);
      await _saveDevice(userId, device);
    }
  }

  // ---- checking someone's devices ----

  Future<Peer> _check(String me, String userId, List<CryptoDevice> devices, {String? fingerprint}) async {
    final own = userId == me;
    final seen = await _seen(me, userId);
    final now = _now();
    final firstLook = seen.isEmpty;
    final remembered = {
      for (final each in devices)
        each.id: switch ((seen.containsKey(each.id), firstLook)) {
          (true, _) => seen[each.id],
          // there from the first look: nothing was added
          (false, true) => null,
          (false, false) => now,
        },
    };
    await _saveSeen(me, userId, remembered);

    final anchors = switch (own) {
      // the account's own: checked against this device
      true => {?_device?.id},
      false => {
        if (fingerprint case final String expected)
          for (final each in devices)
            if (_fingerprintOf(each) == expected) each.id,
      },
    };
    final trusted = _vouchedFrom(anchors, devices);
    final check = switch ((devices.isEmpty, fingerprint, anchors.isEmpty)) {
      (true, _, _) => PeerCheck.noDevices,
      (false, null, _) when !own => PeerCheck.nothingToCheck,
      (false, _, true) when !own => PeerCheck.mismatch,
      _ => PeerCheck.matched,
    };
    return Peer(
      userId: userId,
      check: check,
      devices: [
        for (final each in devices)
          PeerDevice(
            device: each,
            addedAt: remembered[each.id],
            trust: switch ((anchors.contains(each.id), trusted.contains(each.id))) {
              (true, _) => DeviceTrust.pinned,
              (false, true) => DeviceTrust.vouched,
              (false, false) => DeviceTrust.unverified,
            },
          ),
      ],
    );
  }

  /// Every device reached from [anchors] by vouches that check out.
  static Set<String> _vouchedFrom(Set<String> anchors, List<CryptoDevice> devices) {
    final byId = {for (final each in devices) each.id: each};
    final trusted = {...anchors};
    var grew = true;
    while (grew) {
      final next = devices.where((each) {
        if (trusted.contains(each.id)) return false;
        final (voucher, signature) = (byId[each.vouchedBy], each.signature);
        if (voucher == null || signature == null || !trusted.contains(voucher.id)) return false;
        return _signed(voucher, each, signature);
      }).toList();
      grew = next.isNotEmpty;
      trusted.addAll(next.map((each) => each.id));
    }
    return trusted;
  }

  static bool _signed(CryptoDevice voucher, CryptoDevice device, String signature) {
    try {
      return Sealbox.verifySignature(
        signingKey: voucher.signingKey,
        message: vouchMessage(device),
        signature: signature,
      );
    } on SealboxException {
      // a signature or a key that isn't one vouches for nothing
      return false;
    }
  }

  static String? _fingerprintOf(CryptoDevice device) {
    try {
      return Sealbox.fingerprint(
        identityKey: device.identityKey,
        signingKey: device.signingKey,
        context: fingerprintContext,
      );
    } on SealboxException {
      // keys that aren't keys match nothing
      return null;
    }
  }

  // ---- opening what arrived ----

  Future<KeyDelivery?> _open(String me, QueuedItem item, Map<String, List<CryptoDevice>> senders) async {
    final device = _device!;
    final envelope = _Envelope.decode(item.content);
    final senderId = item.senderDeviceId;
    if (envelope == null || senderId == null) {
      _report(const KeyFailure('unreadable_item'));
      return null;
    }
    // the sender says whose device it is; their own list has to agree
    final List<CryptoDevice> listed;
    try {
      listed = senders[envelope.from] ??= await _service.getCryptoDevices(
        // their own other devices are read as the caller's
        userId: switch (envelope.from) {
          final from when from == me => null,
          final from => from,
        },
      );
    } on Map {
      // someone this account can't read keys of, as under a block
      _report(const KeyFailure('unknown_sender'));
      return null;
    }
    final sender = listed.where((each) => each.id == senderId).firstOrNull;
    if (sender == null) {
      _report(const KeyFailure('unknown_sender'));
      return null;
    }
    final message = envelope.message;
    final existing = await _session(me, senderId);
    try {
      // a first message starts a new session, unless it is the one this
      // device already holds, whose sender hasn't heard back yet
      final starts = message.type == 0 && Sealbox.sessionIdOf(message) != existing?.sessionId;
      final opened = switch ((starts, existing)) {
        (true, _) => _accept(device, sender, message),
        (false, final _Session existing) => _decrypt(existing, message),
        (false, null) => null,
      };
      if (opened == null) {
        _report(const KeyFailure('no_session'));
        return null;
      }
      // the single-use key a new session took is spent: saved before anything else
      if (opened.account case final String account) await _saveDevice(me, device.copyWith(account: account));
      await _saveSession(me, senderId, opened.session);
      return KeyDelivery(
        id: item.id,
        kind: item.kind,
        payload: opened.plaintext,
        fromUserId: envelope.from,
        fromDeviceId: senderId,
      );
    } on SealboxException catch (error) {
      // a session that can't open what came on it is stale: the next send
      // starts a new one, and the sender asks again for what it misses
      if (envelope.message.type == 1) await _vault!.delete(_key(me, 'session.$senderId'));
      _report(KeyFailure(error.code));
      return null;
    }
  }

  _Opened _accept(_Device device, CryptoDevice sender, PairwiseMessage message) {
    final accepted = _sealbox.acceptSession(account: device.account, identityKey: sender.identityKey, message: message);
    return (
      account: accepted.account,
      session: (session: accepted.session, sessionId: accepted.sessionId, identityKey: sender.identityKey),
      plaintext: accepted.plaintext,
    );
  }

  _Opened _decrypt(_Session existing, PairwiseMessage message) {
    final decrypted = _sealbox.decrypt(existing.session, message);
    return (
      account: null,
      session: (session: decrypted.session, sessionId: existing.sessionId, identityKey: existing.identityKey),
      plaintext: decrypted.plaintext,
    );
  }

  /// Hands what waits to the handlers for its kinds, outside the lock, so a
  /// handler may send in turn. One run at a time, so nothing is handed twice.
  Future<void> _dispatch(String userId) {
    final done = _dispatching.then((_) async {
      final waiting = await _serial(() => _inbox(userId));
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
      await _serial(() async {
        final inbox = await _inbox(userId);
        await _saveInbox(userId, inbox.where((each) => !handled.contains(each.id)).toList());
      });
    });
    _dispatching = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  // ---- what the vault holds ----

  static String _key(String userId, String name) => 'keys.$userId.$name';

  Sealbox get _sealbox => _box!;

  Future<void> _saveDevice(String userId, _Device device) {
    _device = device;
    return _vault!.write(_key(userId, 'device'), jsonEncode(device.toMap()));
  }

  Future<_Session?> _session(String userId, String deviceId) async {
    return switch (_decode(await _vault!.read(_key(userId, 'session.$deviceId')))) {
      {'session': final String session, 'sessionId': final String sessionId, 'identityKey': final String identityKey} =>
        (session: session, sessionId: sessionId, identityKey: identityKey),
      _ => null,
    };
  }

  Future<void> _saveSession(String userId, String deviceId, _Session session) {
    return _vault!.write(
      _key(userId, 'session.$deviceId'),
      jsonEncode({'session': session.session, 'sessionId': session.sessionId, 'identityKey': session.identityKey}),
    );
  }

  Future<List<KeyDelivery>> _inbox(String userId) async {
    return switch (_decode(await _vault!.read(_key(userId, 'inbox')))) {
      {'items': final List items} => [...items.map(KeyDelivery.of).nonNulls],
      _ => [],
    };
  }

  Future<void> _saveInbox(String userId, List<KeyDelivery> inbox) {
    return _vault!.write(
      _key(userId, 'inbox'),
      jsonEncode({
        'items': [for (final each in inbox) each.toMap()],
      }),
    );
  }

  Future<Map<String, DateTime?>> _seen(String me, String userId) async {
    return switch (_decode(await _vault!.read(_key(me, 'seen.$userId')))) {
      final Map seen => {
        for (final MapEntry(:key, :value) in seen.entries)
          '$key': switch (value) {
            final String at => DateTime.tryParse(at),
            _ => null,
          },
      },
      _ => {},
    };
  }

  Future<void> _saveSeen(String me, String userId, Map<String, DateTime?> seen) {
    return _vault!.write(
      _key(me, 'seen.$userId'),
      jsonEncode({for (final MapEntry(:key, :value) in seen.entries) key: value?.toUtc().toIso8601String()}),
    );
  }

  static Map? _decode(String? json) {
    if (json == null) return null;
    try {
      return switch (jsonDecode(json)) {
        final Map map => map,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  Future<T> _serial<T>(Future<T> Function() step) {
    final done = _tail.then((_) => step());
    _tail = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  /// Runs a call into the library, turning what it throws into its code alone.
  static T _guard<T>(T Function() call) {
    try {
      return call();
    } on SealboxException catch (error) {
      throw KeyFailure(error.code);
    }
  }

  void _report(Object error, [StackTrace? stacktrace]) {
    // what the library says beyond its code never leaves the device
    final reported = switch (error) {
      SealboxException(:final code) => KeyFailure(code),
      _ => error,
    };
    onError?.call(reported, stacktrace: stacktrace);
  }
}

/// A pairwise session with one device, and that device's identity key.
typedef _Session = ({String session, String sessionId, String identityKey});

/// What opening one message gave: the session moved on, the words, and the
/// account when a new session spent one of its single-use keys.
typedef _Opened = ({String? account, _Session session, String plaintext});

/// This device's own record: its id, its account sealed under the storage key,
/// and what it made that the server hasn't taken yet.
class _Device {
  final String id;
  final String account;
  final bool published;

  /// Single-use keys made and not yet on the server, by name.
  final Map<String, String> pending;

  final String fallbackKey;
  final DateTime fallbackAt;

  /// A new fallback key the server hasn't taken yet.
  final bool fallbackPending;

  const new({
    required this.id,
    required this.account,
    required this.published,
    required this.pending,
    required this.fallbackKey,
    required this.fallbackAt,
    this.fallbackPending = false,
  });

  _Device copyWith({
    String? account,
    bool? published,
    Map<String, String>? pending,
    String? fallbackKey,
    DateTime? fallbackAt,
    bool? fallbackPending,
  }) {
    return _Device(
      id: id,
      account: account ?? this.account,
      published: published ?? this.published,
      pending: pending ?? this.pending,
      fallbackKey: fallbackKey ?? this.fallbackKey,
      fallbackAt: fallbackAt ?? this.fallbackAt,
      fallbackPending: fallbackPending ?? this.fallbackPending,
    );
  }

  Map<String, Object> toMap() => {
    'id': id,
    'account': account,
    'published': published,
    'pending': pending,
    'fallbackKey': fallbackKey,
    'fallbackAt': fallbackAt.toUtc().toIso8601String(),
    'fallbackPending': fallbackPending,
  };

  static _Device? of(Map? json) {
    return switch (json) {
      {
        'id': final String id,
        'account': final String account,
        'published': final bool published,
        'pending': final Map pending,
        'fallbackKey': final String fallbackKey,
        'fallbackAt': final String fallbackAt,
        'fallbackPending': final bool fallbackPending,
      } =>
        _Device(
          id: id,
          account: account,
          published: published,
          pending: pending.cast<String, String>(),
          fallbackKey: fallbackKey,
          fallbackAt: DateTime.parse(fallbackAt),
          fallbackPending: fallbackPending,
        ),
      _ => null,
    };
  }
}

/// What travels in a queue item: whose device sent it, and the pairwise
/// message. `v1.<type>.<from>.<body>`, kept short because an item carries at
/// most 1 KB, and the server sees it as text and nothing more.
class _Envelope {
  final String from;
  final PairwiseMessage message;

  const new({required this.from, required this.message});

  static const _version = 'v1';

  String encode() => [_version, message.type, from, message.body].join('.');

  static _Envelope? decode(String content) {
    return switch (content.split('.')) {
      [_version, final String type, final String from, final String body] when from.isNotEmpty && body.isNotEmpty =>
        switch (int.tryParse(type)) {
          final int type when type == 0 || type == 1 => _Envelope(from: from, message: (type: type, body: body)),
          _ => null,
        },
      _ => null,
    };
  }
}
