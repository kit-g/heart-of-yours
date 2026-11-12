part of '../device_keys.dart';

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

/// Checking someone's devices: against a fingerprint, against each other's
/// vouches, and against what this device saw of them before.
extension _Checking on DeviceKeys {
  /// Reads [userId]'s devices as [run]'s account: the account's own id reads
  /// its own other devices.
  Future<List<CryptoDevice>> _listed(_Run run, String userId) {
    return run.service.getCryptoDevices(
      userId: switch (userId == run.userId) {
        true => null,
        false => userId,
      },
    );
  }

  Future<Peer> _check(_Run run, String userId, List<CryptoDevice> devices, {String? fingerprint}) async {
    final own = userId == run.userId;
    final seen = await run.seen(userId);
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
    await run.saveSeen(userId, remembered);

    final anchors = switch (own) {
      // the account's own: checked against this device
      true => {?run.device?.id},
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
}

/// Every device reached from [anchors] by vouches that check out.
Set<String> _vouchedFrom(Set<String> anchors, List<CryptoDevice> devices) {
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

bool _signed(CryptoDevice voucher, CryptoDevice device, String signature) {
  try {
    return Sealbox.verifySignature(
      signingKey: voucher.signingKey,
      message: DeviceKeys.vouchMessage(device),
      signature: signature,
    );
  } on SealboxException {
    // a signature or a key that isn't one vouches for nothing
    return false;
  }
}

String? _fingerprintOf(CryptoDevice device) {
  try {
    return Sealbox.fingerprint(
      identityKey: device.identityKey,
      signingKey: device.signingKey,
      context: DeviceKeys.fingerprintContext,
    );
  } on SealboxException {
    // keys that aren't keys match nothing
    return null;
  }
}
