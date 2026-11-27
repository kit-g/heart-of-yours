import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

void main() {
  PeerDevice device(String id, {DeviceTrust trust = .unverified, String? vouchedBy}) {
    return PeerDevice(
      device: CryptoDevice(
        id: id,
        userId: 'muffin',
        identityKey: 'i-$id',
        signingKey: 's-$id',
        fallbackKey: 'f-$id',
        createdAt: DateTime.utc(2026, 11, 1),
        vouchedBy: vouchedBy,
      ),
      trust: trust,
    );
  }

  Peer own(List<PeerDevice> devices) => Peer(userId: 'muffin', devices: devices, check: .matched);

  final self = device('phone', trust: .pinned);
  final alone = own([self]);
  final notLetIn = own([self, device('tablet')]);
  final letsIn = own([self, device('tablet', trust: .pinned)]);
  final vouched = own([device('phone', trust: .pinned, vouchedBy: 'tablet'), device('tablet')]);
  // one let in, and another the account added since
  final withNew = own([self, device('tablet', trust: .pinned), device('ipad')]);

  LockedReason? reason({
    bool supported = true,
    bool full = false,
    bool removed = false,
    bool mine = false,
    bool theirs = false,
    bool checked = true,
    bool closed = false,
    Peer? own,
    String? deviceId = 'phone',
  }) {
    return lockedReason(
      supported: supported,
      full: full,
      removed: removed,
      mine: mine,
      theirs: theirs,
      checked: checked,
      closed: closed,
      own: own,
      deviceId: deviceId,
    );
  }

  test('nothing locked has no reason', () {
    expect(reason(own: alone), isNull);
    expect(reason(supported: false), isNull);
  });

  test('where no keys are kept, they open elsewhere whatever else holds', () {
    expect(reason(supported: false, mine: true, theirs: true, closed: true, own: notLetIn), LockedReason.elsewhere);
  });

  test('a device the account has no room for says so first, whatever else holds (#750)', () {
    expect(reason(theirs: true, full: true, own: letsIn), LockedReason.full);
    expect(reason(mine: true, full: true, own: notLetIn), LockedReason.full);
    expect(reason(mine: true, closed: true, full: true), LockedReason.full);
    expect(reason(full: true), isNull);
    expect(reason(theirs: true, full: true, supported: false), LockedReason.elsewhere);
  });

  test("over, with only the other person's locked, a full account changes nothing: they never open", () {
    expect(reason(theirs: true, closed: true, full: true), LockedReason.ended);
  });

  test('a removed device says so, whatever else holds, and nothing where nothing is locked (#750)', () {
    expect(reason(theirs: true, removed: true, deviceId: null), LockedReason.removed);
    expect(reason(mine: true, closed: true, removed: true, own: letsIn), LockedReason.removed);
    expect(reason(removed: true), isNull);
  });

  test("while this device's keys don't run, nothing is said", () {
    expect(reason(theirs: true, checked: false, deviceId: null), isNull);
    expect(reason(mine: true, own: alone, deviceId: null), isNull);
  });

  test('before the devices are read, only what does not turn on them is said', () {
    expect(reason(mine: true), isNull);
    expect(reason(mine: true, theirs: true, checked: false), isNull);
    expect(reason(theirs: true), isNull);
    expect(reason(theirs: true, checked: false), LockedReason.others);
    expect(reason(theirs: true, closed: true), LockedReason.ended);
  });

  test("one's own open from another device, approved or not, and never with none", () {
    expect(reason(mine: true, own: alone), LockedReason.gone);
    expect(reason(mine: true, own: notLetIn), LockedReason.approve);
    expect(reason(mine: true, own: letsIn), LockedReason.ownLater);
    expect(reason(mine: true, own: vouched), LockedReason.ownLater);
    expect(reason(mine: true, own: withNew), LockedReason.ownLater, reason: 'this device is let in already');
  });

  test('the other person hands theirs over, once this device is approved where they check', () {
    expect(reason(theirs: true, own: alone), LockedReason.others);
    expect(reason(theirs: true, own: notLetIn), LockedReason.approve);
    expect(reason(theirs: true, own: letsIn), LockedReason.others);
    expect(reason(theirs: true, own: vouched), LockedReason.others);
    expect(reason(theirs: true, own: withNew), LockedReason.others);
  });

  test("a coach's device shares with each of a student's: nothing there to approve", () {
    expect(reason(theirs: true, checked: false, own: notLetIn), LockedReason.others);
    expect(reason(mine: true, theirs: true, checked: false, own: notLetIn), LockedReason.approve);
  });

  test('a conversation that is over answers for no key', () {
    expect(reason(theirs: true, closed: true, own: notLetIn), LockedReason.ended);
    expect(reason(theirs: true, closed: true, own: letsIn), LockedReason.ended);
    expect(reason(mine: true, closed: true, own: letsIn), LockedReason.ended);
    expect(reason(mine: true, closed: true, own: alone), LockedReason.gone);
    expect(
      reason(mine: true, closed: true, own: notLetIn),
      LockedReason.approve,
      reason: 'approving hands over the keys made there, whatever became of the conversation',
    );
  });

  test('where several apply, the one that helps most', () {
    expect(reason(mine: true, theirs: true, own: notLetIn), LockedReason.approve);
    expect(reason(mine: true, theirs: true, own: letsIn), LockedReason.others);
    expect(reason(mine: true, theirs: true, own: alone), LockedReason.others);
    expect(reason(mine: true, theirs: true, closed: true, own: alone), LockedReason.ended);
  });
}
