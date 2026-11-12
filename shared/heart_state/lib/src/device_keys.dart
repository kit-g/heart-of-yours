import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sealbox/sealbox.dart';

import 'remote.dart';

part 'device_keys/arrivals.dart';
part 'device_keys/boundary.dart';
part 'device_keys/own_keys.dart';
part 'device_keys/peers.dart';
part 'device_keys/vault.dart';

/// Thrown when a person's devices don't match the fingerprint this device was
/// given for them: nothing is sent.
class KeyMismatch implements Exception {
  final String userId;

  const new(this.userId);

  @override
  String toString() => 'KeyMismatch($userId)';
}

/// Reported, not thrown, when a claim left out devices a send named: removed,
/// or no longer the person's, between reading their devices and claiming.
/// What reached the rest stands; those wait for the next send, which reads the
/// devices again.
class KeysUnclaimed implements Exception {
  final String userId;

  /// How many of the devices named came back without a key.
  final int count;

  const new(this.userId, this.count);

  @override
  String toString() => 'KeysUnclaimed($userId, $count)';
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

  /// The most a queue item may carry.
  static const _maxItem = 1024;

  /// The account running now, from its start until a stop or sign-out.
  _Run? _run;

  final _handlers = <String, KeyDeliveryHandler>{};

  /// One thing at a time: every step reads and writes the same account and
  /// sessions, and items go out one by one, in order.
  Future<void> _tail = Future.value();

  /// Handing deliveries over, one run at a time.
  Future<void> _dispatching = Future.value();

  DeviceKeysStatus get status => _run?.status ?? .off;

  /// This device's id, once it has keys.
  String? get deviceId => _run?.device?.id;

  /// A person's devices as last read, or null before the first read.
  Peer? peer(String userId) => _run?.peers[userId];

  /// This device's fingerprint: what a coach's invitation link carries after
  /// `#`, for the student's device to check the coach's keys against. Makes
  /// the keys first if this device has none, which needs no network, and
  /// waits for nothing that does. Null while keys don't run, or when the
  /// vault can't be read: a link without one still works, and the thread
  /// says there was nothing to check.
  Future<String?> fingerprint() async {
    final run = _run;
    if (run == null) return null;
    try {
      final device = await _local(run);
      final keys = run.sealbox.accountKeys(device.account);
      return Sealbox.fingerprint(
        identityKey: keys.identityKey,
        signingKey: keys.signingKey,
        context: fingerprintContext,
      );
    } on _Stopped {
      return null;
    } catch (error, stacktrace) {
      _report(error, stacktrace);
      return null;
    }
  }

  /// Vouches for another device of the same person's, once the two have
  /// compared a code: this device signs its keys, and the server attaches the
  /// signature to it. What lets the new one in.
  ///
  /// [device] has already published: comparing the code travels through the
  /// queue, which needs both devices published first. Answers [device] as the
  /// server now holds it. A device is vouched for once: vouching again as
  /// before answers it unchanged, and a different vouch is refused whole
  /// (`already_vouched`), as is one the server can't take.
  Future<CryptoDevice> vouchFor(CryptoDevice device) async {
    final run = _run;
    if (run == null || device.userId != run.userId) {
      throw StateError('only a device of the same account is vouched for');
    }
    return _serial(run, () async {
      final own = await _local(run);
      if (!own.published || !_remote.allowed) throw StateError('device keys are not published');
      if (device.id == own.id) throw StateError('a device does not vouch for itself');
      final signature = _guard(() => run.sealbox.sign(own.account, vouchMessage(device)));
      final vouched = await run.service.vouchForCryptoDevice(device.id, vouchedBy: own.id, signature: signature);
      run.check();
      // the account's own devices, as last read, now with the vouch
      if (run.peers[run.userId] case final Peer peer) {
        final devices = [
          for (final each in peer.devices)
            switch (each.id == vouched.id) {
              true => vouched,
              false => each.device,
            },
        ];
        run.peers[run.userId] = await _check(run, run.userId, devices);
        _changed(run);
      }
      return vouched;
    });
  }

  /// Starts keys for [userId]: makes them on the first start, publishes them
  /// until the server has them, keeps single-use keys stocked and reads what
  /// arrived. Safe to repeat.
  Future<void> start(String userId) {
    final vault = _vault;
    if (vault == null) return Future.value();
    if (_run?.userId != userId) {
      _end();
      _run = _Run(userId, _service, vault);
    }
    // a start already on its way is the one asked for again
    return _starting ??= refresh().whenComplete(() => _starting = null);
  }

  Future<void>? _starting;

  /// A switch went off: forgets what is in memory and stops talking to the
  /// server. Everything on the device stays.
  void stop() {
    _end();
    notifyListeners();
  }

  @override
  void onSignOut() => stop();

  /// Ends the run: whatever it still has queued finds it over and stops.
  void _end() {
    _starting = null;
    _run?.end();
    _run = null;
  }

  /// Publishes, reads the queue and restocks: at a start, and whenever the app
  /// comes back to the front.
  Future<void> refresh() async {
    final run = _run;
    if (run == null || !_remote.allowed) return;
    try {
      await _serial(run, () => _publish(run));
      // read first: a session that arrived spent a single-use key, which makes
      // room for a new one
      await _receive(run);
      await _serial(run, () => _restock(run));
    } on _Stopped {
      // stopped on the way: nothing more goes out
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  /// Takes deliveries of [kind]: what is already waiting at once, and every
  /// later one as it arrives.
  Future<void> on(String kind, KeyDeliveryHandler handler) async {
    _handlers[kind] = handler;
    if (_run case final _Run run) await _dispatch(run);
  }

  /// Something arrived in the queue of [deviceId], one of the account's
  /// devices: read now when it is this one. Every app of the account's hears
  /// it, so one naming another device is not this one's to read.
  Future<void> queueWaiting(String deviceId) async {
    final run = _run;
    if (run == null || deviceId != run.device?.id) return;
    try {
      await receive();
    } catch (error, stacktrace) {
      // left on the server: read again on the next start or resume
      _report(error, stacktrace);
    }
  }

  /// Someone this device shares keys with added, removed or vouched for a
  /// device.
  Future<void> devicesChanged(String userId) async {
    if (_run == null || !_remote.allowed) return;
    try {
      await devicesOf(userId);
    } on _Stopped {
      // stopped on the way: read again at the next start
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  /// Reads what waits for this device, opens it, keeps it, confirms it, then
  /// hands each item to the handler for its kind.
  Future<void> receive() async {
    final run = _run;
    if (run == null) return;
    try {
      await _receive(run);
    } on _Stopped {
      // stopped on the way: what was not confirmed waits on the server
    }
  }

  /// Reads [userId]'s devices and checks them: against [fingerprint], the one
  /// their invitation link carried, and against the ones that vouched for each
  /// other. The account's own id reads its own other devices, checked against
  /// this one.
  Future<Peer> devicesOf(String userId, {String? fingerprint}) async {
    final run = _run;
    if (run == null) throw StateError('device keys are off');
    return _serial(run, () async {
      final devices = await _listed(run, userId);
      final peer = await _check(run, userId, devices, fingerprint: fingerprint);
      run.check();
      run.peers[userId] = peer;
      _changed(run);
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
  }) async {
    final run = _run;
    if (run == null) throw StateError('device keys are not published');
    return _serial(run, () async {
      final device = run.device;
      if (device == null || !device.published || !_remote.allowed) {
        throw StateError('device keys are not published');
      }
      final listed = await _listed(run, userId);
      final peer = await _check(run, userId, listed, fingerprint: fingerprint);
      run.peers[userId] = peer;
      if (peer.check == .mismatch) throw KeyMismatch(userId);
      final targets = peer.devices.where((each) => each.id != device.id && (to?.call(each) ?? true)).toList();
      if (targets.isEmpty) return;

      final sessions = {for (final each in targets) each.id: await run.session(each.id)};
      // a device with no session yet needs one of its single-use keys, and
      // only those devices are named in a claim (heart-api#424), so neither one
      // with a session nor one [to] left out spends a key
      final unkeyed = [
        for (final each in targets)
          if (sessions[each.id] == null) each.id,
      ];
      final claimed = {
        for (final named in _batches(unkeyed, _claimLimit))
          for (final each in await run.service.claimKeys(userId, deviceIds: named)) each.id: each,
      };
      // one the claim left out was removed, or stopped being theirs, since the
      // list: nothing reaches it now, and the next send reads the list again
      if (unkeyed.where((id) => !claimed.containsKey(id)).length case final missing when missing > 0) {
        _report(KeysUnclaimed(userId, missing));
      }

      for (final target in targets) {
        final session = sessions[target.id] ?? _startSession(run, device, target.device, claimed[target.id]);
        // left out of the claim, or its keys changed since the list
        if (session == null) continue;
        final sealed = _guard(() => run.sealbox.encrypt(session.session, payload));
        // saved before it travels: a session used twice is a broken one
        await run.saveSession(target.id, (
          session: sealed.session,
          sessionId: session.sessionId,
          identityKey: session.identityKey,
        ));
        final content = _Envelope(sealed.message).encode();
        if (content.length > _maxItem) throw ArgumentError.value(kind, 'kind', 'sealed past what the queue carries');
        await run.service.enqueueKeyItem(
          id: _newId(),
          recipientDeviceId: target.id,
          senderDeviceId: device.id,
          kind: kind,
          content: content,
        );
      }
      _changed(run);
    });
  }

  /// A new session to [target], from the keys a claim took for it.
  _Session? _startSession(_Run run, _Device device, CryptoDevice target, CryptoDevice? claimed) {
    if (claimed == null || claimed.identityKey != target.identityKey) return null;
    final started = _guard(
      () => run.sealbox.startSession(
        account: device.account,
        identityKey: claimed.identityKey,
        oneTimeKey: claimed.oneTimeKey ?? claimed.fallbackKey,
      ),
    );
    return (session: started.session, sessionId: started.sessionId, identityKey: claimed.identityKey);
  }

  /// Says [run] changed, while it is still the one running.
  void _changed(_Run run) {
    if (identical(run, _run)) notifyListeners();
  }

  /// Runs [step] in turn. A step whose run ended before its turn came throws
  /// [_Stopped] instead.
  Future<T> _serial<T>(_Run run, Future<T> Function() step) {
    final done = _tail.then((_) {
      run.check();
      return step();
    });
    _tail = done.then<void>((_) {}, onError: (_) {});
    return done;
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

/// The most devices one claim may name.
const _claimLimit = 10;

/// [ids] in order, in batches of at most [size].
Iterable<List<String>> _batches(List<String> ids, int size) {
  return Iterable.generate((ids.length / size).ceil(), (index) => ids.skip(index * size).take(size).toList());
}

/// Runs a call into the library, turning what it throws into its code alone.
T _guard<T>(T Function() call) {
  try {
    return call();
  } on SealboxException catch (error) {
    throw KeyFailure(error.code);
  }
}
