import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sealbox/sealbox.dart';

import 'remote.dart';

part 'device_keys/approval.dart';
part 'device_keys/arrivals.dart';
part 'device_keys/notes.dart';
part 'device_keys/boundary.dart';
part 'device_keys/own_keys.dart';
part 'device_keys/peers.dart';
part 'device_keys/threads.dart';
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

  /// The account has no place for this device, and the server keeps it
  /// waiting for one (`device_waiting`): nothing is sent to it, but it may
  /// remove a device, after its first day for one added before it. It takes
  /// its place as soon as there is one, tried again at each start, resume and
  /// change to the account's devices (#750).
  waiting,

  /// The account has no place for this device, nor room for it to wait
  /// (`device_limit`): the server knows nothing of it, so a device is removed
  /// from another of the account's. Tried again as [waiting] is.
  full,

  /// The server removed this device, from another or from this one's
  /// account elsewhere (#750). Every key it held is forgotten, and it comes
  /// back only when asked, as a new device ([DeviceKeys.startOver]).
  removed,
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
class DeviceKeys with ChangeNotifier implements SignOutStateSentry, ThreadCipher, NoteCipher {
  final RemoteKeyService _service;
  final KeyVault? _vault;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// Whether a device the account adds gets the note keys as soon as it is
  /// heard of, rather than when notes are next read or written here: not
  /// while notes are off. Always, when not given.
  final bool Function()? sharesNoteKeys;
  final String Function() _newId;
  final DateTime Function() _now;

  new({
    required this._service,
    required this._vault,
    RemoteAccess? remote,
    this.onError,
    this.sharesNoteKeys,
    String Function()? newId,
    DateTime Function()? now,
  }) : _remote = remote ?? RemoteAccess(),
       _newId = newId ?? uuidV7,
       _now = now ?? DateTime.now {
    _handlers[threadKeyKind] = _takeThreadKey;
    _handlers[threadKeyRequestKind] = _takeKeyRequest;
    _handlers[noteKeyKind] = _takeNoteKey;
    for (final kind in DeviceApproval._kinds) {
      _handlers[kind] = approval._take;
    }
  }

  /// Letting another device of the account's in by comparing a code.
  late final approval = DeviceApproval._(this);

  static DeviceKeys of(BuildContext context) => Provider.of<DeviceKeys>(context, listen: false);

  static DeviceKeys watch(BuildContext context) => Provider.of<DeviceKeys>(context, listen: true);

  /// Names a device's keys in a fingerprint. Part of every invitation link a
  /// coach sends, so changing it breaks the links still out there.
  static const fingerprintContext = 'heart-of.me/device-keys/v1';

  /// What a device signs to remove [deviceId] from [ownerId]'s account at
  /// [signedAt], in seconds since the epoch (heart-api#483). The server
  /// checks these bytes, so changing them breaks removing.
  static String removeMessage({required String ownerId, required String deviceId, required int signedAt}) {
    return ['heart-of.me/remove-device/v1', ownerId, deviceId.toLowerCase(), '$signedAt'].join('\n');
  }

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

  /// How long one answer of the server's is waited for while others wait their
  /// turn: a connection that died with the network would hold them all up.
  static const _answerTime = Duration(seconds: 15);

  /// The most a queue item may carry.
  static const _maxItem = 1024;

  /// What a thread's key travels as between devices (#556).
  static const threadKeyKind = 'thread_key';

  /// What a request for thread keys travels as, to the devices that made
  /// them (#556).
  static const threadKeyRequestKind = 'thread_key_request';

  final _threadKeys = StreamController<String>.broadcast();

  @override
  Stream<String> get threadKeys => _threadKeys.stream;

  KeyRequestHandler? _onKeyRequest;

  @override
  set onKeyRequest(KeyRequestHandler? handler) {
    _onKeyRequest = handler;
    // what waited for someone to decide may be decided now
    if ((handler, _run) case (_?, final _Run run)) _redispatch(run);
  }

  @override
  Future<void> ask(String threadId, List<ThreadCiphertext> items, {String? fingerprint}) async {
    try {
      await _ask(threadId, items, fingerprint);
    } on _Stopped {
      // stopped on the way: asked again when the thread is next read
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  @override
  Future<void> answer(KeyRequest request, {String? fingerprint}) => _answer(request, fingerprint);

  @override
  Future<SealedMessage> seal(String threadId, String text) => _seal(threadId, text);

  @override
  Future<void> share(String threadId, {required String userId, String? fingerprint}) {
    return _share(threadId, userId: userId, fingerprint: fingerprint);
  }

  @override
  Future<List<OpenedMessage>> open(String threadId, List<ThreadCiphertext> items) => _openThread(threadId, items);

  /// What a coach's note key travels as between their devices (#556).
  static const noteKeyKind = 'note_key';

  final _noteKeys = StreamController<void>.broadcast();

  @override
  Stream<void> get noteKeys => _noteKeys.stream;

  @override
  Future<String> sealNote(String noteId, {required String connectionId, required String text}) {
    return _sealNote(noteId, connectionId, text);
  }

  @override
  Future<List<OpenedNote>> openNotes(List<CoachNote> notes) => _openNotes(notes);

  @override
  Future<void> shareNoteKeys() async {
    try {
      await _shareNoteKeys();
    } on _Stopped {
      // stopped on the way: shared at the next start
    }
  }

  /// The account running now, from its start until a stop or sign-out.
  _Run? _run;

  final _handlers = <String, KeyDeliveryHandler>{};

  /// One thing at a time: every step reads and writes the same account and
  /// sessions, and items go out one by one, in order.
  Future<void> _tail = Future.value();

  /// Handing deliveries over, one run at a time.
  Future<void> _dispatching = Future.value();

  DeviceKeysStatus get status => _run?.status ?? .off;

  /// Whether keys can run on this device at all: not without a vault to keep
  /// them in, as on the web.
  bool get supported => _vault != null;

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
      final vouched = await run.service
          .vouchForCryptoDevice(device.id, vouchedBy: own.id, signature: signature)
          .timeout(_answerTime);
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
        _keep(run, await _check(run, run.userId, devices));
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

  @override
  void dispose() {
    _threadKeys.close();
    _noteKeys.close();
    approval.dispose();
    super.dispose();
  }

  /// Ends the run: whatever it still has queued finds it over and stops.
  void _end() {
    _starting = null;
    approval._abandon();
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
      await _payOwed(run);
    } on _Stopped {
      // stopped on the way: nothing more goes out
    } catch (error, stacktrace) {
      if (!await _removedBy(run, error)) _report(error, stacktrace);
    }
  }

  /// Whether [error], what a call naming this device was answered with, came
  /// because the server removed it: the account's own list is read to tell,
  /// and a device missing from it forgets its keys. A device whose keys were
  /// never published was never on it.
  Future<bool> _removedBy(_Run run, Object error) async {
    if (error case ServerRefusal(code: 'not_found' || 'device_removed') when run.device?.published ?? false) {
      try {
        await devicesOf(run.userId);
      } on _Removed {
        return true;
      } catch (_) {
        // not told either way: the refusal is said as it came
      }
    }
    return false;
  }

  /// This device was removed: everything it held is forgotten, and the run
  /// says so.
  Future<void> _forgetRemoved(_Run run) async {
    await run.forgetAll();
    approval._abandon();
    _changed(run);
  }

  /// Makes this device over as a new one, after it was removed (#750): new
  /// keys, published as soon as the server takes them. It reads nothing said
  /// before until one of the account's devices lets it in.
  Future<void> startOver() async {
    final run = _run;
    if (run == null || !run.removed) throw StateError('this device was not removed');
    run.removed = false;
    try {
      final box = run.box = Sealbox(await _newStorageKey(run));
      run.device = await _create(run, box);
      // the new one is kept first: cut short before this, the next start
      // finds the mark and forgets it, and is removed as before
      await run.unmark();
    } catch (_) {
      run
        ..removed = true
        ..device = null
        ..box = null;
      rethrow;
    }
    run.status = .local;
    _changed(run);
    await refresh();
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
    // every thread shares again before its next message
    _run?.sharedAt.clear();
    try {
      await devicesOf(userId);
      final run = _run;
      if (run == null || userId != run.userId) return;
      if (!(run.device?.published ?? false)) {
        // a device removed elsewhere may have made room for this one
        await refresh();
        if (!(run.device?.published ?? false)) return;
        // in now: its own row, and a list the shares below can go by
        await devicesOf(userId);
      }
      // a vouch this device owes may be due, or answered by another's
      await _payOwed(run);
      // a device of the account's own may be new, or newly vouched for: one
      // this device trusts gets the thread and note keys without waiting for
      // the next message, or for the notes to be opened somewhere
      await _shareThreadsWithOwn(run);
      if (sharesNoteKeys?.call() ?? true) await _shareNoteKeys();
    } on _Stopped {
      // stopped on the way: read again at the next start
    } catch (error, stacktrace) {
      _report(error, stacktrace);
    }
  }

  /// Removes [deviceId], another of the account's devices, for good: the
  /// server sends it nothing more, and every key this device made that it
  /// held is replaced before anything else is sealed under it. Then this
  /// device publishes, when it waited for room. Throws what the server says,
  /// and [ArgumentError] for this device, which is never removed from here.
  ///
  /// The removal is signed by this device, which the server has to know, in
  /// its place or waiting for one: [RemovalRefused] says why it can't, and
  /// when, where that is known. A removal of one gone already counts as
  /// done. This device having been removed itself makes it forget its keys,
  /// and answers quietly.
  Future<void> remove(String deviceId) async {
    final run = _run;
    if (run == null || !_remote.allowed) throw StateError('device keys are off');
    final _Device device;
    try {
      device = await _local(run);
      if (deviceId == device.id) throw ArgumentError.value(deviceId, 'deviceId', 'this device');
      await _serial(run, () => _removeSigned(run, device, deviceId));
    } on _Removed {
      // this device was removed itself: it forgot its keys, and says so
      return;
    }
    _changed(run);
    try {
      // in first, when it waited for room: then the list holds it too
      if (!(run.device?.published ?? false)) await refresh();
      await devicesOf(run.userId);
    } on _Stopped {
      // stopped on the way: read again at the next start
    } catch (error, stacktrace) {
      // removed all the same: the list is read again on the next open
      _report(error, stacktrace);
    }
  }

  /// [remove]'s turn: signs, sends, and on its way out forgets what it knew
  /// of [deviceId].
  Future<void> _removeSigned(_Run run, _Device device, String deviceId) async {
    // nothing recorded of this device: its word counts for nothing yet
    if (run.status == .full) throw const RemovalRefused(.notJoined);
    final signedAt = _now().millisecondsSinceEpoch ~/ 1000;
    final message = removeMessage(ownerId: run.userId, deviceId: deviceId, signedAt: signedAt);
    final signature = _guard(() => run.sealbox.sign(device.account, message));
    try {
      await run.service
          .removeCryptoDevice(deviceId, removedBy: device.id, signedAt: signedAt, signature: signature)
          .timeout(_answerTime);
    } on ServerRefusal catch (refusal, stacktrace) {
      switch (refusal.code) {
        // gone already, from another device: the same as from here
        case 'not_found':
          break;
        // an older device, before this one's first day is out
        case 'device_too_new':
          throw RemovalRefused(.tooNew, removableAt: DateTime.tryParse('${refusal.details['removableAt']}'));
        // this device's clock is off by more than the server allows
        case 'signature_expired':
          throw const RemovalRefused(.clock);
        // the server doesn't know this device, though it thought it did:
        // said, and worth knowing about
        case 'unknown_device':
          _report(refusal, stacktrace);
          throw const RemovalRefused(.notJoined);
        // this device was removed itself
        case 'device_removed':
          await _forgetRemoved(run);
          throw _Removed();
        default:
          rethrow;
      }
    }
    // kept before anything else: a seal that comes before the next read of
    // the devices finds it gone, even after a relaunch
    await run.saveSeen(run.userId, {...await run.seen(run.userId)}..remove(deviceId));
    await run.ownDeviceWent();
    await run.forgetSessions(deviceId);
    if (run.peers[run.userId] case final Peer own) {
      run.peers[run.userId] = Peer(
        userId: own.userId,
        check: own.check,
        devices: [...own.devices.where((each) => each.id != deviceId)],
      );
    }
    if (run.ownListing case final CryptoDevices listing) {
      run.ownListing = CryptoDevices(
        [...listing.devices.where((each) => each.id != deviceId)],
        waiting: [...listing.waiting.where((each) => each.id != deviceId)],
        removed: listing.removed,
      );
    }
  }

  /// The account's other devices waiting for a place, as last read: never
  /// sent anything.
  List<CryptoDevice> get waiting {
    final self = deviceId;
    return [...?_run?.ownListing?.waiting.where((each) => each.id != self)];
  }

  /// The account's devices removed lately, newest first, each with when and
  /// by which device, as last read.
  List<CryptoDevice> get removedLately => [...?_run?.ownListing?.removed];

  /// When this device may remove [target], another of the account's: a device
  /// added after this one at once, one added before it once this one has been
  /// in use for a day. Null when it may now, or when this device's own row
  /// wasn't read, so only the server can tell.
  DateTime? removableAt(CryptoDevice target) {
    final (self, listing) = (deviceId, _run?.ownListing);
    if (self == null || listing == null) return null;
    final own = [...listing.devices, ...listing.waiting].where((each) => each.id == self).firstOrNull;
    if (own == null || target.createdAt.isAfter(own.createdAt)) return null;
    final at = own.createdAt.add(const Duration(days: 1));
    return switch (_now().isBefore(at)) {
      true => at,
      false => null,
    };
  }

  /// Reads what waits for this device, opens it, keeps it, confirms it, then
  /// hands each item to the handler for its kind.
  @override
  Future<void> receive() async {
    final run = _run;
    if (run == null) return;
    try {
      await _receive(run);
    } on _Stopped {
      // stopped on the way: what was not confirmed waits on the server
    } catch (error) {
      // the queue of a device the server removed: it forgets its keys
      if (!await _removedBy(run, error)) rethrow;
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
      _keep(run, peer);
      _changed(run);
      return peer;
    });
  }

  /// Seals [payload] to every device of [userId]'s that [to] lets through
  /// (all of them by default), each in its own pairwise session, and sends
  /// them one at a time. The account's own id sends to its other devices.
  ///
  /// Refuses with [KeyMismatch] when their devices don't match [fingerprint].
  /// Answers the devices it reached: one left out of a claim, or whose keys
  /// changed since the list, waits for the next send.
  Future<Set<String>> deliver({
    required String userId,
    required String kind,
    required String payload,
    String? fingerprint,
    bool Function(PeerDevice device)? to,
  }) async {
    final run = _run;
    if (run == null) throw StateError('device keys are not published');
    return _serial(run, () async {
      // read first: a device removed on the way here answers nothing
      final device = await _local(run);
      if (!device.published || !_remote.allowed) {
        throw StateError('device keys are not published');
      }
      final listed = await _listed(run, userId);
      final peer = await _check(run, userId, listed, fingerprint: fingerprint);
      _keep(run, peer);
      if (peer.check == .mismatch) throw KeyMismatch(userId);
      final targets = peer.devices.where((each) => each.id != device.id && (to?.call(each) ?? true)).toList();
      if (targets.isEmpty) return const <String>{};

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
          for (final each in await run.service.claimKeys(userId, deviceIds: named).timeout(_answerTime)) each.id: each,
      };
      // one the claim left out was removed, or stopped being theirs, since the
      // list: nothing reaches it now, and the next send reads the list again
      if (unkeyed.where((id) => !claimed.containsKey(id)).length case final missing when missing > 0) {
        _report(KeysUnclaimed(userId, missing));
      }

      final reached = <String>{};
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
        await run.service
            .enqueueKeyItem(
              id: _newId(),
              recipientDeviceId: target.id,
              senderDeviceId: device.id,
              kind: kind,
              content: content,
            )
            .timeout(_answerTime);
        reached.add(target.id);
      }
      _changed(run);
      return reached;
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

  /// Keeps [peer] as [run]'s latest of its person's devices. One of the
  /// account's own coming to be trusted hands over again what waited for it:
  /// keys it sent before this device trusted it.
  void _keep(_Run run, Peer peer) {
    final before = {
      for (final each in run.peers[peer.userId]?.devices ?? const <PeerDevice>[])
        if (each.trusted) each.id,
    };
    run.peers[peer.userId] = peer;
    if (peer.userId == run.userId && peer.devices.any((each) => each.trusted && !before.contains(each.id))) {
      _redispatch(run);
    }
  }

  /// Whether this device compared a code with [deviceId] and its vouch hasn't
  /// reached the server yet: trusted here, and not yet by the account's other
  /// devices.
  bool owesVouch(String deviceId) => _run?.owing.contains(deviceId) ?? false;

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

/// Why this device couldn't remove another (#750).
enum RemovalRefusal {
  /// The other was added before this one, whose first day isn't out:
  /// [RemovalRefused.removableAt] says when it is.
  tooNew,

  /// The server knows nothing of this device: the account had no room even
  /// for it to wait. Another of the account's devices removes it.
  notJoined,

  /// This device's clock is too far off for its signature to count.
  clock,
}

/// What [DeviceKeys.remove] throws when the server won't take this device's
/// word for the removal.
class RemovalRefused implements Exception {
  final RemovalRefusal reason;

  /// When the removal will go through, for [RemovalRefusal.tooNew].
  final DateTime? removableAt;

  const new(this.reason, {this.removableAt});

  @override
  String toString() => 'RemovalRefused(${reason.name})';
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
