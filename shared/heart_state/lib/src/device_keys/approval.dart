part of '../device_keys.dart';

/// Which end of a comparison this device is.
enum ComparisonRole {
  /// It asked: a device already trusted, letting another in.
  initiator,

  /// It was asked.
  responder,
}

/// Why a comparison failed.
enum ComparisonFailure {
  /// The other device's key isn't the one it committed to first: something
  /// between the two changed it.
  commitment,

  /// The other device's proof doesn't match its keys as the server lists
  /// them: the server handed out keys that aren't that device's.
  keys,

  /// The other device couldn't be reached.
  unreachable,

  /// Nothing came back in time.
  timeout,
}

/// Where a comparison stands.
sealed class ComparisonPhase {
  const new();
}

/// Waiting for the other device: its answer, or its key.
final class ComparisonWaiting extends ComparisonPhase {
  const new();
}

/// The code both screens show: three numbers, and the same as emoji indices.
final class ComparisonCode extends ComparisonPhase {
  final List<int> decimals;
  final List<int> emoji;

  const new({required this.decimals, required this.emoji});
}

/// Both sides said the codes match, and each proved its keys to the other.
final class ComparisonDone extends ComparisonPhase {
  const new();
}

/// It ended without letting anything in, for [reason].
final class ComparisonFailed extends ComparisonPhase {
  final ComparisonFailure reason;

  const new(this.reason);
}

/// Either side said no, or the other one was busy.
final class ComparisonCancelled extends ComparisonPhase {
  const new();
}

/// One comparison as a screen shows it.
class CodeComparison {
  /// The other device.
  final String deviceId;
  final ComparisonRole role;
  final ComparisonPhase phase;

  /// Whether the person said here that the codes match, while the other side
  /// hasn't yet.
  final bool confirmed;

  const new({required this.deviceId, required this.role, required this.phase, this.confirmed = false});

  /// Whether it is still on its way.
  bool get running => switch (phase) {
    ComparisonWaiting() || ComparisonCode() => true,
    ComparisonDone() || ComparisonFailed() || ComparisonCancelled() => false,
  };
}

/// Letting a second device of the account's in by comparing a code (#555).
///
/// A device already trusted [start]s with another of the account's devices;
/// both show the same code, and once the person says on each that it
/// matches ([confirm]), each proves its keys to the other under the shared
/// secret. What checks out is remembered on both, and vouched for on the
/// server, so the account's own keys reach the new device from then on.
///
/// Everything travels through the queue, sealed, one device to one device.
/// The device that will see the other's key first commits to its own before
/// it sees it, so whoever moves the keys can't grind a key until the codes
/// match ([Comparison]).
///
/// Memory only: a restart abandons it. One at a time, and gone after five
/// minutes.
class DeviceApproval with ChangeNotifier implements ValueListenable<CodeComparison?> {
  final DeviceKeys _keys;

  new _(this._keys);

  static const _startKind = 'compare_start';
  static const _keyKind = 'compare_key';
  static const _macKind = 'compare_mac';
  static const _doneKind = 'compare_done';
  static const _cancelKind = 'compare_cancel';
  static const _kinds = [_startKind, _keyKind, _macKind, _doneKind, _cancelKind];

  /// Names a comparison's code and proofs, bound to both devices.
  static const _context = 'heart-of.me/compare/v1';

  static const _life = Duration(minutes: 5);

  _Comparing? _current;
  CodeComparison? _value;

  /// The comparison running, or the last one, until [dismiss].
  @override
  CodeComparison? get value => _value;

  /// Starts comparing a code with [deviceId], one of the account's other
  /// devices. Refused while another comparison runs.
  Future<void> start(String deviceId) async {
    final run = _keys._run;
    final device = run?.device;
    if (run == null || device == null) throw StateError('device keys are off');
    if (_current case _Comparing(ended: false)) throw StateError('a comparison is already running');
    if (deviceId == device.id) throw StateError('a device does not compare with itself');
    final comparing = _begin(
      run,
      id: _keys._newId(),
      deviceId: deviceId,
      role: .initiator,
      comparison: _guard(Comparison.start),
    );
    await _send(comparing, _startKind, {'commitment': comparing.comparison.commitment});
  }

  /// The person says the codes match: this device proves its keys to the
  /// other, and lets it in once the other's proof checks out.
  Future<void> confirm() async {
    final comparing = _current;
    if (comparing == null || comparing.ended || comparing.info == null || comparing.confirmed) return;
    comparing.confirmed = true;
    _show(comparing, _value!.phase);
    final run = comparing.run;
    final keys = run.sealbox.accountKeys(run.device!.account);
    final mac = _guard(
      () => comparing.comparison.mac(_keysInput(keys.identityKey, keys.signingKey), comparing.info!),
    );
    if (!await _send(comparing, _macKind, {'mac': mac})) return;
    if (comparing.verified != null) await _complete(comparing);
  }

  /// The person says the codes don't match, or doesn't want to compare: ended
  /// on both.
  Future<void> deny() async {
    final comparing = _current;
    if (comparing == null || comparing.ended) return;
    _finish(comparing, const ComparisonCancelled());
    await _cancel(comparing.run, comparing.deviceId, comparing.id);
  }

  /// Forgets one that ended.
  void dismiss() {
    if (_current case _Comparing(ended: false)) return;
    _current = null;
    _value = null;
    notifyListeners();
  }

  /// The run ended: whatever was on its way is dropped.
  void _abandon() {
    final comparing = _current;
    if (comparing == null) return;
    if (!comparing.ended) _end(comparing);
    _current = null;
    _value = null;
    notifyListeners();
  }

  _Comparing _begin(
    _Run run, {
    required String id,
    required String deviceId,
    required ComparisonRole role,
    required Comparison comparison,
    String? theirCommitment,
  }) {
    final comparing = _Comparing(
      run: run,
      id: id,
      deviceId: deviceId,
      role: role,
      comparison: comparison,
      theirCommitment: theirCommitment,
    );
    comparing.timer = Timer(_life, () => _expire(comparing));
    _current = comparing;
    _show(comparing, const ComparisonWaiting());
    return comparing;
  }

  void _show(_Comparing comparing, ComparisonPhase phase) {
    if (!identical(comparing, _current)) return;
    _value = CodeComparison(
      deviceId: comparing.deviceId,
      role: comparing.role,
      phase: phase,
      confirmed: comparing.confirmed,
    );
    notifyListeners();
  }

  void _end(_Comparing comparing) {
    comparing
      ..ended = true
      ..timer?.cancel();
    try {
      comparing.comparison.end();
    } on SealboxException {
      // already gone in the library: nothing to end
    }
  }

  void _finish(_Comparing comparing, ComparisonPhase phase) {
    if (comparing.ended) return;
    _end(comparing);
    _show(comparing, phase);
  }

  Future<void> _fail(_Comparing comparing, ComparisonFailure reason) async {
    if (comparing.ended) return;
    _finish(comparing, ComparisonFailed(reason));
    await _cancel(comparing.run, comparing.deviceId, comparing.id);
  }

  void _expire(_Comparing comparing) => unawaited(_fail(comparing, .timeout));

  /// Sends [kind] to the other device. A send that reaches nothing fails the
  /// comparison; answers whether it went.
  Future<bool> _send(_Comparing comparing, String kind, Map<String, String> payload) async {
    try {
      final reached = await _deliver(comparing.run, comparing.deviceId, kind, {'c': comparing.id, ...payload});
      if (reached) return true;
    } catch (error, stacktrace) {
      _keys._report(error, stacktrace);
    }
    if (!comparing.ended) _finish(comparing, const ComparisonFailed(.unreachable));
    return false;
  }

  Future<bool> _deliver(_Run run, String deviceId, String kind, Map<String, String> payload) async {
    final reached = await _keys.deliver(
      userId: run.userId,
      kind: kind,
      payload: jsonEncode(payload),
      to: (device) => device.id == deviceId,
    );
    return reached.contains(deviceId);
  }

  /// Tells the other device it ended, as far as it can be told.
  Future<void> _cancel(_Run run, String deviceId, String id) => _tell(run, deviceId, _cancelKind, id);

  /// Sends [kind] with nothing but the comparison's id, as far as it goes:
  /// what doesn't arrive, the other side's timeout ends.
  Future<void> _tell(_Run run, String deviceId, String kind, String id) async {
    try {
      await _deliver(run, deviceId, kind, {'c': id});
    } on _Stopped {
      // stopped on the way: the other side times out
    } catch (error, stacktrace) {
      _keys._report(error, stacktrace);
    }
  }

  /// Takes what the other device sent.
  Future<void> _take(KeyDelivery delivery) async {
    final run = _keys._run;
    if (run == null) throw StateError('device keys are off');
    // a comparison is between the account's own devices, or nowhere
    if (delivery.fromUserId != run.userId) {
      _keys._report(const KeyFailure('foreign_comparison'));
      return;
    }
    final payload = _decodeMap(delivery.payload);
    final id = switch (payload) {
      {'c': final String id} => id,
      _ => null,
    };
    if (id == null) {
      _keys._report(const KeyFailure('unreadable_comparison'));
      return;
    }
    if (delivery.kind == _startKind) return _asked(run, delivery, id, payload!);
    // only what belongs to the one running here: anything else is from one
    // that ended, or never was
    final comparing = _current;
    if (comparing == null || comparing.id != id || comparing.deviceId != delivery.fromDeviceId) return;
    switch ((delivery.kind, payload)) {
      case (_keyKind, {'key': final String key}) when !comparing.ended:
        await _keyed(comparing, key);
      case (_macKind, {'mac': final String mac}) when !comparing.ended:
        await _proved(comparing, mac);
      case (_cancelKind, _):
        _finish(comparing, const ComparisonCancelled());
      case (_doneKind, _):
        // the other side's vouch is on the server now: read it
        await _keys.devicesOf(run.userId);
      case _:
        _keys._report(const KeyFailure('unreadable_comparison'));
    }
  }

  /// Another device asked to compare: this one answers with its key.
  Future<void> _asked(_Run run, KeyDelivery delivery, String id, Map payload) async {
    final commitment = switch (payload) {
      {'commitment': final String commitment} => commitment,
      _ => null,
    };
    // one asked before a restart, or long enough ago that the other side
    // gave up: dropped
    final at = _timeOf(id);
    if (commitment == null || at == null || _keys._now().difference(at).abs() > _life) return;
    if (_current case _Comparing(ended: false)) {
      // busy with another: that one goes on, this one ends
      await _cancel(run, delivery.fromDeviceId, id);
      return;
    }
    final comparing = _begin(
      run,
      id: id,
      deviceId: delivery.fromDeviceId,
      role: .responder,
      comparison: _guard(Comparison.start),
      theirCommitment: commitment,
    );
    await _send(comparing, _keyKind, {'key': comparing.comparison.publicKey});
  }

  /// The other device's key: the code is ready.
  Future<void> _keyed(_Comparing comparing, String key) async {
    if (comparing.info != null) return;
    try {
      _guard(() => comparing.comparison.establish(key, theirCommitment: comparing.theirCommitment));
    } on KeyFailure catch (failure) {
      _keys._report(failure);
      return _fail(comparing, switch (failure.code) {
        'commitment_mismatch' => .commitment,
        _ => .keys,
      });
    }
    // the side that asked sends its own key only now, after the other's
    if (comparing.role == .initiator) {
      if (!await _send(comparing, _keyKind, {'key': comparing.comparison.publicKey})) return;
    }
    final own = comparing.run.device!.id;
    final info = comparing.info = switch (comparing.role) {
      .initiator => [_context, own, comparing.deviceId],
      .responder => [_context, comparing.deviceId, own],
    }.join('\n');
    final code = _guard(() => comparing.comparison.code(info));
    _show(comparing, ComparisonCode(decimals: code.decimals, emoji: code.emoji));
  }

  /// The other device's proof of its keys, checked against its keys as the
  /// account's device list has them.
  Future<void> _proved(_Comparing comparing, String mac) async {
    final info = comparing.info;
    if (info == null) return _fail(comparing, .keys);
    final listed = await _keys.devicesOf(comparing.run.userId);
    final device = listed.devices.where((each) => each.id == comparing.deviceId).firstOrNull?.device;
    final valid = switch (device) {
      final CryptoDevice device => _verify(comparing, device, mac, info),
      null => false,
    };
    if (!valid) return _fail(comparing, .keys);
    comparing.verified = device;
    if (comparing.confirmed) await _complete(comparing);
  }

  bool _verify(_Comparing comparing, CryptoDevice device, String mac, String info) {
    try {
      return comparing.comparison.verifyMac(_keysInput(device.identityKey, device.signingKey), info, mac);
    } on SealboxException {
      return false;
    }
  }

  /// Both sides said the codes match, and the other's proof checked out: the
  /// other device is in.
  Future<void> _complete(_Comparing comparing) async {
    final device = comparing.verified;
    if (device == null || comparing.ended || comparing.completing) return;
    comparing.completing = true;
    final run = comparing.run;
    try {
      await _keys._serial(run, () => run.saveCompared(device.id, _keysOf(device)));
      // every share reads the devices again, and reaches this one
      run.sharedAt.clear();
      // vouched for on the server too, for the account's other devices and
      // for the people it shares keys with: by whichever side finds it not
      // vouched for yet
      if (device.vouchedBy == null) {
        try {
          await _keys.vouchFor(device);
        } on _Stopped {
          rethrow;
        } catch (error, stacktrace) {
          // remembered here all the same
          _keys._report(error, stacktrace);
        }
      }
      if (comparing.role == .initiator) await _tell(run, comparing.deviceId, _doneKind, comparing.id);
      _finish(comparing, const ComparisonDone());
      await _keys.devicesOf(run.userId);
      if (_keys.sharesNoteKeys?.call() ?? true) await _keys._shareNoteKeys();
    } on _Stopped {
      // stopped on the way: what was saved stands
    } catch (error, stacktrace) {
      _keys._report(error, stacktrace);
    }
  }
}

/// One comparison on its way.
class _Comparing {
  final _Run run;

  /// The initiator's id for it, a UUIDv7.
  final String id;
  final String deviceId;
  final ComparisonRole role;
  final Comparison comparison;

  /// What the initiator committed to, for the responder to check its key
  /// against.
  final String? theirCommitment;

  /// What the code and proofs are bound to, once both keys are in.
  String? info;

  bool confirmed = false;

  /// The other device, once its proof checked out.
  CryptoDevice? verified;

  bool completing = false;
  bool ended = false;
  Timer? timer;

  new({
    required this.run,
    required this.id,
    required this.deviceId,
    required this.role,
    required this.comparison,
    this.theirCommitment,
  });
}

/// What a device proves it holds: its two public keys.
String _keysInput(String identityKey, String signingKey) => '$identityKey|$signingKey';

/// When a UUIDv7 was made, from its first 48 bits.
DateTime? _timeOf(String id) {
  final hex = id.replaceAll('-', '');
  if (hex.length != 32) return null;
  return switch (int.tryParse(hex.substring(0, 12), radix: 16)) {
    final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    null => null,
  };
}
