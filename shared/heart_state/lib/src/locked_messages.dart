import 'device_keys.dart';

/// What opens a conversation's locked messages ([Locked]), or that nothing
/// does.
enum LockedReason {
  /// This device keeps no keys (the web, a desktop): they open on a phone.
  elsewhere,

  /// The account holds as many devices as it can, so this one's keys aren't
  /// on the server: removing one it no longer uses lets it in (#750).
  full,

  /// This device was removed and forgot its keys: it reads again only as a
  /// new device, let in by another (#750).
  removed,

  /// Another of the account's devices has to approve this one.
  approve,

  /// The other person's device hands over its keys when it is next there.
  others,

  /// One of the account's own devices does.
  ownLater,

  /// The conversation is over: nobody answers for its keys any more.
  ended,

  /// Written by the account on a device that is no longer among its own.
  gone,
}

/// What opens the locked messages of a conversation, the one that helps most
/// where several would. Null while that isn't known yet.
///
/// A key comes only from the device that made it: the account's own devices
/// hand theirs to one they let in, and the other person's to whichever devices
/// they take for this person's.
///
/// - [supported]: this device can keep keys at all;
/// - [full]: its keys wait for room on the account;
/// - [removed]: it was removed, and forgot its keys;
/// - [mine], [theirs]: whose messages are locked;
/// - [checked]: the other person has a fingerprint to check this one's devices
///   against, as a student has of their coach's, and so leaves out one that
///   wasn't let in. A coach has none of a student's, and shares with each;
/// - [closed]: nothing more is answered in the conversation;
/// - [own]: the account's devices as last read, null before;
/// - [deviceId]: this device's, null while its keys don't run.
LockedReason? lockedReason({
  required bool supported,
  required bool full,
  required bool removed,
  required bool mine,
  required bool theirs,
  required bool checked,
  required bool closed,
  required Peer? own,
  required String? deviceId,
}) {
  if (!mine && !theirs) return null;
  if (!supported) return .elsewhere;
  if (removed) return .removed;
  // nothing reaches it until it is in, unless only the other person's are
  // locked in a conversation that is over: being let in opens none of those
  if (full) {
    return switch ((closed, mine)) {
      (true, false) => .ended,
      _ => .full,
    };
  }
  // with no keys running, everything is locked: no reason of its own yet
  if (deviceId == null) return null;
  final theirsOpen = theirs && !closed;
  if (own == null) {
    // what doesn't turn on the account's devices is known without them
    if (mine || (theirsOpen && checked)) return null;
    return closed ? .ended : .others;
  }

  final others = own.devices.where((each) => each.id != deviceId);
  final self = own.devices.where((each) => each.id == deviceId).firstOrNull;
  final letIn = (self?.vouched ?? false) || others.any((each) => each.trusted);
  final approves = others.isNotEmpty && !letIn;

  if (approves && (mine || (theirsOpen && checked))) return .approve;
  if (theirsOpen) return .others;
  if (mine && letIn && !closed) return .ownLater;
  // over: a device asked for keys answers nothing about it any more
  if (theirs || others.isNotEmpty) return .ended;
  return .gone;
}
