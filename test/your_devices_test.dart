import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:ui' show ImageByteFormat;

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/rendering.dart' show RenderParagraph, RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/core/utils/visual.dart' show dialogWidth;
import 'package:heart/presentation/navigation/pushes.dart' show PushPresenter;
import 'package:heart/presentation/navigation/router/router.dart' show HeartRouter;
import 'package:heart/presentation/routes/messages/messages.dart' show ThreadPage;
import 'package:heart/presentation/routes/settings/settings.dart' show SettingsPage, YourDevicesPage;
import 'package:heart/presentation/widgets/compare_codes.dart' show deviceName;
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:sealbox/sealbox.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Your devices (#555): the account's devices, and letting one in by
/// comparing a code. The phone is the app; the tablet is played here, with
/// the real encryption library, through the server's queue.
void main() {
  // the app's own fonts: the comparison sheet sizes its code by measuring it,
  // and the test font's em-wide glyphs measure nothing like a real face
  setUpAll(loadAppFonts);

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  /// The app's device, once it published.
  late CryptoDevice phone;

  /// What the app keeps single-use keys of, for the tablet to start a session.
  late Map<String, String> phoneKeys;

  late Sealbox tabletBox;
  late String tabletAccount;
  late CryptoDevice tablet;
  String? tabletSession;

  /// What the app sent, in order, and what waits in its queue.
  late List<({String kind, String content})> sent;
  late List<QueuedItem> queue;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    sent = [];
    queue = [];
    phoneKeys = {};
    tabletSession = null;
    tabletBox = Sealbox(base64.encode(List.filled(32, 3)));
    final made = tabletBox.createAccount(oneTimeKeys: 1);
    tabletAccount = made.account;
    tablet = CryptoDevice(
      id: '01a1e000-0000-7000-8000-00000000ab12',
      userId: 'muffin',
      identityKey: made.identityKey,
      signingKey: made.signingKey,
      fallbackKey: made.fallbackKey.key,
      createdAt: DateTime.utc(2026, 11, 2),
      oneTimeKeyId: made.oneTimeKeys.single.id,
      oneTimeKey: made.oneTimeKeys.single.key,
    );

    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(
      api.publishCryptoDevice(
        id: anyNamed('id'),
        identityKey: anyNamed('identityKey'),
        signingKey: anyNamed('signingKey'),
        fallbackKey: anyNamed('fallbackKey'),
        vouch: anyNamed('vouch'),
      ),
    ).thenAnswer(
      (invocation) async => phone = CryptoDevice(
        id: invocation.namedArguments[#id] as String,
        userId: 'muffin',
        identityKey: invocation.namedArguments[#identityKey] as String,
        signingKey: invocation.namedArguments[#signingKey] as String,
        fallbackKey: invocation.namedArguments[#fallbackKey] as String,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    );
    when(api.addOneTimeKeys(any, any)).thenAnswer((invocation) async {
      phoneKeys.addAll((invocation.positionalArguments[1] as Map).cast<String, String>());
      return phoneKeys.length;
    });
    when(api.countOneTimeKeys(any)).thenAnswer((_) async => 50);
    when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer((_) async => CryptoDevices([phone, tablet]));
    when(api.claimKeys('muffin', deviceIds: anyNamed('deviceIds'))).thenAnswer((_) async => [tablet]);
    when(
      api.enqueueKeyItem(
        id: anyNamed('id'),
        recipientDeviceId: anyNamed('recipientDeviceId'),
        senderDeviceId: anyNamed('senderDeviceId'),
        kind: anyNamed('kind'),
        content: anyNamed('content'),
      ),
    ).thenAnswer((invocation) async {
      sent.add((
        kind: invocation.namedArguments[#kind] as String,
        content: invocation.namedArguments[#content] as String,
      ));
    });
    when(api.getKeyQueue(any)).thenAnswer((_) async => [...queue]);
    when(api.confirmKeyItems(any, any)).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments[1] as List<String>;
      queue.removeWhere((each) => ids.contains(each.id));
    });
    when(
      api.vouchForCryptoDevice(any, vouchedBy: anyNamed('vouchedBy'), signature: anyNamed('signature')),
    ).thenAnswer((invocation) async {
      return tablet = CryptoDevice(
        id: tablet.id,
        userId: tablet.userId,
        identityKey: tablet.identityKey,
        signingKey: tablet.signingKey,
        fallbackKey: tablet.fallbackKey,
        createdAt: tablet.createdAt,
        vouchedBy: invocation.namedArguments[#vouchedBy] as String,
        signature: invocation.namedArguments[#signature] as String,
      );
    });
  });

  /// A signed removal of [deviceId], or of any device: for stubbing and
  /// verifying, whatever it was signed with.
  Future<bool> removal([String? deviceId]) => api.removeCryptoDevice(
    deviceId ?? any,
    removedBy: anyNamed('removedBy'),
    signedAt: anyNamed('signedAt'),
    signature: anyNamed('signature'),
  );

  /// Tall enough that the Settings list builds its Account section, unless
  /// a test is about [size] itself.
  void tall(WidgetTester tester, {Size size = const Size(1200, 2400)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1200, 2400),
    Map<String, Object> features = const {'feature-yourCoach': 'on'},
  }) async {
    tall(tester, size: size);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...features});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      keyVault: MemoryKeyVault(),
      settle: false,
    );
    await tester.pumpTimes();
  }

  BuildContext root(WidgetTester tester) => tester.element(find.byType(Navigator).first);

  L l(WidgetTester tester) => L.of(tester.element(find.byType(Scaffold).last));

  /// The tablet opens what the app sent it last, as [kind].
  Map<String, Object?> opened(String kind) {
    final last = sent.lastWhere((each) => each.kind == kind);
    final [_, type, body] = last.content.split('.');
    final message = (type: int.parse(type), body: body);
    final plaintext = switch (tabletSession) {
      final String session => () {
        final decrypted = tabletBox.decrypt(session, message);
        tabletSession = decrypted.session;
        return decrypted.plaintext;
      }(),
      null => () {
        final accepted = tabletBox.acceptSession(
          account: tabletAccount,
          identityKey: phone.identityKey,
          message: message,
        );
        (tabletAccount, tabletSession) = (accepted.account, accepted.session);
        return accepted.plaintext;
      }(),
    };
    return (jsonDecode(plaintext) as Map).cast<String, Object?>();
  }

  /// The tablet sends [payload] as [kind], and the app reads its queue.
  Future<void> reply(WidgetTester tester, String kind, Map<String, String> payload) async {
    final session =
        tabletSession ??
        tabletBox
            .startSession(account: tabletAccount, identityKey: phone.identityKey, oneTimeKey: phoneKeys.values.first)
            .session;
    final sealed = tabletBox.encrypt(session, jsonEncode(payload));
    tabletSession = sealed.session;
    queue.add(
      QueuedItem(
        id: uuidV7(),
        recipientDeviceId: phone.id,
        senderDeviceId: tablet.id,
        senderUserId: 'muffin',
        kind: kind,
        content: 'v1.${sealed.message.type}.${sealed.message.body}',
        createdAt: DateTime.now(),
      ),
    );
    await DeviceKeys.of(root(tester)).receive();
    await tester.pumpTimes();
  }

  Future<void> openDevices(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(AppKeys.yourDevices));
    await tester.pumpTimes();
    await tester.tap(find.byKey(AppKeys.yourDevices));
    await tester.pumpTimes();
  }

  testWidgets('a device not approved yet is let in by comparing the code both show', (tester) async {
    await pump(tester);
    await openDevices(tester);

    expect(find.text(l(tester).thisDevice), findsOneWidget);
    expect(find.text(l(tester).deviceNotApproved), findsOneWidget);
    expect(find.byKey(AppKeys.compareCodes(phone.id)), findsNothing);

    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();
    expect(find.text(l(tester).compareCodesWaiting), findsOneWidget);

    // the tablet answers with its key, and the app with its own
    final asked = opened('compare_start');
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    await reply(tester, 'compare_key', {'c': asked['c']! as String, 'key': comparison.publicKey});
    comparison.establish(
      opened('compare_key')['key']! as String,
      theirCommitment: asked['commitment']! as String,
    );
    final info = 'heart-of.me/compare/v1\n${phone.id}\n${tablet.id}';
    final code = comparison.code(info);

    expect(find.text(code.decimals.join('   ')), findsOneWidget, reason: 'the same code on both');

    await tester.tap(find.byKey(AppKeys.codesMatch));
    await tester.pumpTimes();
    expect(find.text(l(tester).compareCodesConfirmed), findsOneWidget);
    expect(
      comparison.verifyMac('${phone.identityKey}|${phone.signingKey}', info, opened('compare_mac')['mac']! as String),
      isTrue,
    );
    await reply(tester, 'compare_mac', {
      'c': asked['c']! as String,
      'mac': comparison.mac('${tablet.identityKey}|${tablet.signingKey}', info),
    });

    verify(
      api.vouchForCryptoDevice(tablet.id, vouchedBy: phone.id, signature: anyNamed('signature')),
    ).called(1);
    expect(sent.last.kind, 'compare_done');
    // let in here; done only once the tablet says it let this one in too
    expect(find.text(l(tester).compareCodesDone), findsNothing);
    expect(find.text(l(tester).compareCodesConfirmed), findsOneWidget);

    await reply(tester, 'compare_done', {'c': asked['c']! as String});
    expect(find.text(l(tester).compareCodesDone), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();
    expect(find.text(l(tester).deviceApproved), findsOneWidget);
    expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsNothing);
  });

  group('removing a device (#750)', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(AppKeys.deviceMenu(tablet.id)));
      await tester.pumpTimes();
      await tester.tap(find.byKey(AppKeys.deviceRemove(tablet.id)));
      await tester.pumpTimes();
    }

    testWidgets('another device is removed from its menu, asked once; this one has no menu', (tester) async {
      when(removal()).thenAnswer((_) async {
        when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer((_) async => CryptoDevices([phone]));
        return true;
      });
      await pump(tester);
      await openDevices(tester);

      expect(find.byKey(AppKeys.deviceMenu(phone.id)), findsNothing);
      expect(find.byTooltip(l(tester).deviceOptions), findsOneWidget);

      // asked, and cancelled: nothing happens
      await openMenu(tester);
      expect(find.text(l(tester).deviceRemoveBody), findsOneWidget);
      await tester.tap(find.text(l(tester).cancel));
      await tester.pumpTimes();
      verifyNever(removal());
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      verify(removal(tablet.id)).called(1);
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsNothing);
      expect(find.byKey(AppKeys.deviceRow(phone.id)), findsOneWidget);
    });

    testWidgets('a removal the server refuses says so, and the device stays', (tester) async {
      when(removal()).thenThrow(
        const ServerRefusal(status: 403, code: 'forbidden', method: 'DELETE', route: '/v1/keys/devices/{id}'),
      );
      await pump(tester);
      await openDevices(tester);

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      expect(find.text(l(tester).deviceRemoveFailed), findsOneWidget);
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsOneWidget);
    });

    /// Publishing answered by [refusal] until a removal makes room; this
    /// device's waiting row, where the server keeps one, as [waitingSince].
    void noPlace(String refusal, {DateTime? waitingSince, List<CryptoDevice> waiting = const []}) {
      var room = false;
      CryptoDevice row(Invocation invocation, DateTime at) => CryptoDevice(
        id: invocation.namedArguments[#id] as String,
        userId: 'muffin',
        identityKey: invocation.namedArguments[#identityKey] as String,
        signingKey: invocation.namedArguments[#signingKey] as String,
        fallbackKey: invocation.namedArguments[#fallbackKey] as String,
        createdAt: at,
      );
      CryptoDevice? self;
      when(
        api.publishCryptoDevice(
          id: anyNamed('id'),
          identityKey: anyNamed('identityKey'),
          signingKey: anyNamed('signingKey'),
          fallbackKey: anyNamed('fallbackKey'),
          vouch: anyNamed('vouch'),
        ),
      ).thenAnswer((invocation) async {
        if (!room) {
          if (waitingSince != null) self = row(invocation, waitingSince);
          throw ServerRefusal(status: 409, code: refusal, method: 'POST', route: '/v1/keys/devices');
        }
        return phone = row(invocation, waitingSince ?? DateTime.utc(2026, 10, 1));
      });
      when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer(
        (_) async => switch (room) {
          false => CryptoDevices([tablet], waiting: [?self, ...waiting]),
          true => CryptoDevices([phone]),
        },
      );
      when(removal()).thenAnswer((_) async {
        room = true;
        return true;
      });
    }

    testWidgets('waiting for a place, it says so at the top, and joins once it removes one', (tester) async {
      // waiting since before the tablet came: the tablet is removed at once
      noPlace('device_waiting', waitingSince: DateTime.utc(2026, 10, 1));
      await pump(tester);
      await openDevices(tester);

      expect(DeviceKeys.of(root(tester)).status, DeviceKeysStatus.waiting);
      expect(find.text(l(tester).yourDevicesFull), findsOneWidget);
      // comparing travels through the queue, which a waiting device can't use
      expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsNothing);

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.yourDevicesFull), findsNothing);
      expect(DeviceKeys.of(root(tester)).status, DeviceKeysStatus.published);
      expect(find.text(l(tester).thisDevice), findsOneWidget);
    });

    testWidgets('with nowhere even to wait, it sends the person to another device, and offers no menu', (
      tester,
    ) async {
      noPlace('device_limit');
      await pump(tester);
      await openDevices(tester);

      expect(DeviceKeys.of(root(tester)).status, DeviceKeysStatus.full);
      expect(find.text(l(tester).yourDevicesFullElsewhere), findsOneWidget);
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsOneWidget);
      expect(find.byKey(AppKeys.deviceMenu(tablet.id)), findsNothing);
    });

    testWidgets("in its first day, an older device's Remove is greyed with when it can be", (tester) async {
      // waiting since just now, after the tablet
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      noPlace('device_waiting', waitingSince: since);
      await pump(tester);
      await openDevices(tester);

      await tester.tap(find.byKey(AppKeys.deviceMenu(tablet.id)));
      await tester.pumpTimes();

      final item = tester.widget<PopupMenuItem<Object?>>(find.byKey(AppKeys.deviceRemove(tablet.id)));
      expect(item.enabled, isFalse);
      final at = DateFormat.MMMd('en').add_jm().format(since.add(const Duration(days: 1)).toLocal());
      expect(find.text(l(tester).deviceRemovableFrom(at)), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.deviceRemove(tablet.id)), warnIfMissed: false);
      await tester.pumpTimes();
      expect(find.text(l(tester).deviceRemoveBody), findsNothing, reason: 'nothing to confirm');
    });

    testWidgets("the server's word that it's too soon is said with its time, and not reported", (tester) async {
      when(removal()).thenThrow(
        const ServerRefusal(
          status: 403,
          code: 'device_too_new',
          method: 'DELETE',
          route: '/v1/keys/devices/{id}',
          details: {'removableAt': '2026-12-01T09:00:00Z'},
        ),
      );
      await pump(tester);
      await openDevices(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      final at = DateFormat.MMMd('en').add_jm().format(DateTime.utc(2026, 12, 1, 9).toLocal());
      expect(find.text(l(tester).deviceRemoveTooNew(at)), findsOneWidget);
      expect(find.text(l(tester).deviceRemoveFailed), findsNothing);
    });

    testWidgets('says when each other device was last seen, and marks one not seen for two weeks', (tester) async {
      final today = DateTime.now().toUtc();
      DateTime daysAgo(int days) => DateTime.utc(today.year, today.month, today.day - days);
      CryptoDevice seen(String id, DateTime on) => CryptoDevice(
        id: id,
        userId: 'muffin',
        identityKey: tablet.identityKey,
        signingKey: tablet.signingKey,
        fallbackKey: tablet.fallbackKey,
        createdAt: DateTime.utc(2026, 11, 2),
        lastSeenOn: on,
      );
      const today_ = '01a1e000-0000-7000-8000-00000000aa01';
      const yesterday = '01a1e000-0000-7000-8000-00000000aa02';
      const week = '01a1e000-0000-7000-8000-00000000aa03';
      const old = '01a1e000-0000-7000-8000-00000000aa04';
      when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer(
        (_) async => CryptoDevices([
          phone,
          seen(today_, daysAgo(0)),
          seen(yesterday, daysAgo(1)),
          seen(week, daysAgo(7)),
          seen(old, daysAgo(20)),
        ]),
      );
      await pump(tester);
      await openDevices(tester);
      final format = DateFormat.yMMMd('en');

      Finder under(String id, String words) =>
          find.descendant(of: find.byKey(AppKeys.deviceRow(id)), matching: find.text(words));
      expect(under(today_, l(tester).deviceSeenToday), findsOneWidget);
      expect(under(yesterday, l(tester).deviceSeenYesterday), findsOneWidget);
      expect(under(week, l(tester).deviceSeenOn(format.format(daysAgo(7)))), findsOneWidget);
      expect(under(old, l(tester).deviceNotSeenSince(format.format(daysAgo(20)))), findsOneWidget);
      expect(find.byKey(AppKeys.deviceStale(old)), findsOneWidget);
      expect(find.byKey(AppKeys.deviceStale(week)), findsNothing);
    });

    testWidgets('waiting devices have their own section, with Remove; removals say by which device', (
      tester,
    ) async {
      const waitingId = '01a1e000-0000-7000-8000-00000000bb01';
      const mineId = '01a1e000-0000-7000-8000-00000000bb02';
      const theirsId = '01a1e000-0000-7000-8000-00000000bb03';
      CryptoDevice other(String id, {DateTime? removedAt, String? removedBy}) => CryptoDevice(
        id: id,
        userId: 'muffin',
        identityKey: tablet.identityKey,
        signingKey: tablet.signingKey,
        fallbackKey: tablet.fallbackKey,
        createdAt: DateTime.utc(2026, 11, 20),
        removedAt: removedAt,
        removedBy: removedBy,
      );
      when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer(
        (_) async => CryptoDevices(
          [phone, tablet],
          waiting: [other(waitingId)],
          removed: [
            other(mineId, removedAt: DateTime.utc(2026, 11, 24, 12), removedBy: phone.id),
            other(theirsId, removedAt: DateTime.utc(2026, 11, 22, 12), removedBy: tablet.id),
          ],
        ),
      );
      when(removal()).thenAnswer((_) async => false);
      await pump(tester);
      await openDevices(tester);
      final format = DateFormat.yMMMd('en');

      expect(find.text(l(tester).yourDevicesWaiting), findsOneWidget);
      expect(find.byKey(AppKeys.waitingRow(waitingId)), findsOneWidget);
      expect(find.text(l(tester).yourDevicesRemovedLately), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(AppKeys.removedRow(mineId)),
          matching: find.text(l(tester).deviceRemovedByThis(format.format(DateTime.utc(2026, 11, 24, 12).toLocal()))),
        ),
        findsOneWidget,
      );
      final tabletName = 'Device ${tablet.id.replaceAll('-', '').substring(26).toUpperCase()}';
      expect(
        find.descendant(
          of: find.byKey(AppKeys.removedRow(theirsId)),
          matching: find.text(
            l(tester).deviceRemovedBy(tabletName, format.format(DateTime.utc(2026, 11, 22, 12).toLocal())),
          ),
        ),
        findsOneWidget,
      );
      // the one this device didn't make is marked for a reader too
      expect(
        find.descendant(
          of: find.byKey(AppKeys.removedRow(theirsId)),
          matching: find.byWidgetPredicate(
            (each) => each is Icon && each.semanticLabel == l(tester).deviceRemovedElsewhere,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(AppKeys.removedRow(mineId)),
          matching: find.byWidgetPredicate(
            (each) => each is Icon && each.semanticLabel == l(tester).deviceRemovedElsewhere,
          ),
        ),
        findsNothing,
      );

      await tester.ensureVisible(find.byKey(AppKeys.deviceMenu(waitingId)));
      await tester.tap(find.byKey(AppKeys.deviceMenu(waitingId)));
      await tester.pumpTimes();
      await tester.tap(find.byKey(AppKeys.deviceRemove(waitingId)));
      await tester.pumpTimes();
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      verify(removal(waitingId)).called(1);
    });

    testWidgets('one removed already, elsewhere, goes from the list as though removed here', (tester) async {
      var gone = false;
      when(api.getCryptoDevices(userId: anyNamed('userId')))
          .thenAnswer((_) async => CryptoDevices(gone ? [phone] : [phone, tablet]));
      when(removal()).thenAnswer((_) async {
        gone = true;
        throw const ServerRefusal(status: 404, code: 'not_found', method: 'DELETE', route: '/v1/keys/devices/{id}');
      });
      await pump(tester);
      await openDevices(tester);

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pumpTimes();

      expect(find.text(l(tester).deviceRemoveFailed), findsNothing);
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsNothing);
    });

    testWidgets('while its removal runs, the row offers nothing more', (tester) async {
      final answer = Completer<bool>();
      when(removal()).thenAnswer((_) => answer.future);
      await pump(tester);
      await openDevices(tester);

      await openMenu(tester);
      await tester.tap(find.byKey(AppKeys.deviceRemoveConfirm));
      await tester.pump();

      expect(find.byKey(AppKeys.deviceMenu(tablet.id)), findsNothing);
      when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer((_) async => CryptoDevices([phone]));
      answer.complete(true);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsNothing);
    });

    testWidgets('a device the account removed says so, lists nothing, and comes back only as a new one', (
      tester,
    ) async {
      var published = <String>[];
      when(
        api.publishCryptoDevice(
          id: anyNamed('id'),
          identityKey: anyNamed('identityKey'),
          signingKey: anyNamed('signingKey'),
          fallbackKey: anyNamed('fallbackKey'),
          vouch: anyNamed('vouch'),
        ),
      ).thenAnswer((invocation) async {
        published = [...published, invocation.namedArguments[#id] as String];
        return phone = CryptoDevice(
          id: invocation.namedArguments[#id] as String,
          userId: 'muffin',
          identityKey: invocation.namedArguments[#identityKey] as String,
          signingKey: invocation.namedArguments[#signingKey] as String,
          fallbackKey: invocation.namedArguments[#fallbackKey] as String,
          createdAt: DateTime.utc(2026, 10, 1),
        );
      });
      await pump(tester);
      final first = phone.id;
      // removed from the tablet: the list no longer holds this phone
      var removed = true;
      when(
        api.getCryptoDevices(userId: anyNamed('userId')),
      ).thenAnswer((_) async => CryptoDevices(removed ? [tablet] : [phone, tablet]));
      await openDevices(tester);

      expect(find.byKey(AppKeys.yourDevicesRemoved), findsOneWidget);
      expect(find.text(l(tester).yourDevicesRemoved), findsOneWidget);
      expect(find.byKey(AppKeys.deviceRow(tablet.id)), findsNothing);
      expect(DeviceKeys.of(root(tester)).status, DeviceKeysStatus.removed);

      removed = false;
      await tester.tap(find.byKey(AppKeys.deviceStartOver));
      await tester.pumpTimes();

      expect(published, hasLength(2));
      expect(published.last, isNot(first));
      expect(find.byKey(AppKeys.yourDevicesRemoved), findsNothing);
      expect(find.text(l(tester).thisDevice), findsOneWidget);
      expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsOneWidget);
    });
  });

  testWidgets('another device asking opens the comparison over whatever is on screen, and may be told no', (
    tester,
  ) async {
    await pump(tester);
    final comparison = Comparison.start();
    addTearDown(comparison.end);

    await reply(tester, 'compare_start', {'c': uuidV7(), 'commitment': comparison.commitment});

    final name = 'Device ${tablet.id.replaceAll('-', '').substring(26).toUpperCase()}';
    expect(find.text(l(tester).compareCodesAsked(name)), findsOneWidget);
    expect(opened('compare_key')['key'], isA<String>());

    await tester.tap(find.byKey(AppKeys.codesDontMatch));
    await tester.pumpTimes();

    expect(find.text(l(tester).compareCodesCancelled), findsOneWidget);
    expect(sent.last.kind, 'compare_cancel');
    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();
    expect(DeviceKeys.of(root(tester)).approval.value, isNull);
  });

  /// Puts [payload] in the app's queue as [kind], as [reply] does, with
  /// nothing to say it is there.
  void enqueue(String kind, Map<String, String> payload) {
    final session =
        tabletSession ??
        tabletBox
            .startSession(account: tabletAccount, identityKey: phone.identityKey, oneTimeKey: phoneKeys.values.first)
            .session;
    final sealed = tabletBox.encrypt(session, jsonEncode(payload));
    tabletSession = sealed.session;
    queue.add(
      QueuedItem(
        id: uuidV7(),
        recipientDeviceId: phone.id,
        senderDeviceId: tablet.id,
        senderUserId: 'muffin',
        kind: kind,
        content: 'v1.${sealed.message.type}.${sealed.message.body}',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Muffin coaches Sam, whose message this device has no key for.
  void lockedConversation() {
    when(api.registerAccount(any)).thenAnswer((invocation) async {
      final user = invocation.positionalArguments.single as User;
      return User(id: user.id, email: user.email, settings: user.settings, entitlements: ['coach']);
    });
    when(api.getConnections()).thenAnswer(
      (_) async => [
        Connection(
          targetId: 'sam',
          role: .coach,
          domain: .fitness,
          status: .active,
          createdAt: DateTime.utc(2026, 11, 8),
          connectionId: 'c-sam',
          acceptedAt: DateTime.utc(2026, 11, 8),
          name: 'Sam',
        ),
      ],
    );
    final thread = Thread(id: 't-sam', connectionId: 'c-sam', otherId: 'sam', otherName: 'Sam');
    when(api.openThread('c-sam')).thenAnswer((_) async => thread);
    when(api.getThreads()).thenAnswer((_) async => [thread]);
    final at = DateTime.utc(2026, 11, 12, 8);
    final held = <StoredItem>[];
    when(api.getThreadItems(any, limit: anyNamed('limit'))).thenAnswer(
      (_) async => (
        items: [
          ThreadItem(
            id: '01a1e000-0000-7000-8000-0000000000f1',
            threadId: 't-sam',
            senderId: 'sam',
            kind: 'message',
            content: 'm1.somesession.AAAA',
            commitment: 'c',
            tag: 't',
            tagKey: 'k',
            at: at,
            createdAt: at,
            cursor: 'c1',
          ),
        ],
        cursor: null,
      ),
    );
    when(api.markThreadRead(any, any)).thenAnswer((_) async {});
    when(db.getThreads(any)).thenAnswer((_) async => []);
    when(db.storeThreads(any, any)).thenAnswer((_) async {});
    when(db.storeThread(any, any)).thenAnswer((_) async {});
    when(db.storeThreadItems(any, any)).thenAnswer((invocation) async {
      held.addAll(invocation.positionalArguments[1] as Iterable<StoredItem>);
    });
    when(db.getThreadItems(any, any)).thenAnswer((_) async => [...held]);
  }

  testWidgets('it opens over a conversation that needs it, clear of the edge, and Back returns there', (tester) async {
    lockedConversation();
    await pump(tester, size: const Size(400, 860));
    tester.view.padding = const FakeViewPadding(bottom: 34);
    HeartRouter.of(root(tester)).openThread('c-sam');
    await tester.pumpTimes();
    expect(find.byType(ThreadPage), findsOneWidget);
    expect(find.byKey(AppKeys.messagesLockedLine), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.messagesYourDevices));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsOneWidget);
    final list = tester.widget<ListView>(
      find.ancestor(of: find.byKey(AppKeys.compareCodes(tablet.id)), matching: find.byType(ListView)).first,
    );
    expect(list.padding!.resolve(.ltr).bottom, 34);

    await tester.pageBack();
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsNothing);
    expect(find.byType(ThreadPage), findsOneWidget);
  });

  testWidgets('off, nothing pushes it', (tester) async {
    await pump(tester, features: {});
    HeartRouter.of(root(tester)).pushYourDevices(root(tester));
    await tester.pumpTimes();
    expect(tester.takeException(), isNull);
    expect(find.byType(YourDevicesPage), findsNothing);
  });

  group('its link starting the app', () {
    Future<void> start(WidgetTester tester, {Map<String, Object> features = const {'feature-yourCoach': 'on'}}) {
      final platform = tester.binding.platformDispatcher
        ..defaultRouteNameTestValue = HeartRouter.yourDevicesLink('heart-of.me').path;
      addTearDown(platform.clearDefaultRouteNameTestValue);
      return pump(tester, features: features);
    }

    testWidgets('opens it for a student', (tester) async {
      await start(tester);
      expect(find.byType(YourDevicesPage), findsOneWidget);
    });

    testWidgets('opens it for a coach with only Coach people on, once the account says so', (tester) async {
      final answer = Completer<void>();
      when(api.registerAccount(any)).thenAnswer((invocation) async {
        final user = invocation.positionalArguments.single as User;
        await answer.future;
        return User(id: user.id, email: user.email, settings: user.settings, entitlements: ['coach']);
      });
      await start(tester, features: {'feature-coachPeople': 'on'});
      // no page yet for the harness to register from
      unawaited(Auth.of(tester.element(find.byType(PushPresenter))).registerAgain());
      await tester.pumpTimes();
      expect(find.byType(YourDevicesPage), findsNothing, reason: 'not before it is known');

      answer.complete();
      await tester.pumpTimes();
      expect(find.byType(YourDevicesPage), findsOneWidget);
    });

    testWidgets('is one the app has no screen for with both off', (tester) async {
      await start(tester, features: {});
      expect(find.byType(YourDevicesPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('is let go where the account never says', (tester) async {
      when(api.registerAccount(any)).thenAnswer((_) => Completer<User>().future);
      await start(tester, features: {'feature-coachPeople': 'on'});
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpTimes();
      expect(find.byType(YourDevicesPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  testWidgets('its link is the page in Settings', (tester) async {
    expect(
      '${HeartRouter.yourDevicesLink('heart-of.me')}',
      'https://heart-of.me/profile/settings/devices',
    );
    await pump(tester);
    GoRouter.of(root(tester)).go(HeartRouter.yourDevicesLink('heart-of.me').path);
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.compareCodes(tablet.id)), findsOneWidget);
  });

  testWidgets('one already asked for shows as the page opens, with no push (#734)', (tester) async {
    await pump(tester);
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    enqueue('compare_start', {'c': uuidV7(), 'commitment': comparison.commitment});

    await openDevices(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(AppKeys.codesDontMatch), findsOneWidget);
  });

  testWidgets('one asked for while the page is open shows too, with no push (#734)', (tester) async {
    await pump(tester);
    await openDevices(tester);
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    enqueue('compare_start', {'c': uuidV7(), 'commitment': comparison.commitment});

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.codesDontMatch), findsOneWidget);
  });

  testWidgets('on another tab, the page reads no queue (#734)', (tester) async {
    await pump(tester);
    await openDevices(tester);
    GoRouter.of(root(tester)).go('/history');
    await tester.pumpTimes();
    clearInteractions(api);
    await tester.pump(const Duration(seconds: 10));
    verifyNever(api.getKeyQueue(any));
  });

  testWidgets('asked on both at once, the sheet goes on with the one both keep (#734)', (tester) async {
    await pump(tester);
    await openDevices(tester);
    // made first: the smaller id
    final theirs = uuidV7();
    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    opened('compare_start');

    await reply(tester, 'compare_start', {'c': theirs, 'commitment': comparison.commitment});
    expect(find.text(l(tester).compareCodesCancelled), findsNothing);
    comparison.establish(opened('compare_key')['key']! as String);
    await reply(tester, 'compare_key', {'c': theirs, 'key': comparison.publicKey});
    final info = 'heart-of.me/compare/v1\n${tablet.id}\n${phone.id}';
    expect(find.text(comparison.code(info).decimals.join('   ')), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.codesDontMatch));
    await tester.pumpTimes();
    expect(find.text(l(tester).compareCodesCancelled), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();
    expect(DeviceKeys.of(root(tester)).approval.value, isNull);
  });

  /// The comparison up to the codes, as the tablet plays it: answering the
  /// app's start with its key, or, when [tabletAsks], asking itself and
  /// answering the app's key with its own. Either way the sheet is up on the
  /// app with the code, which [code] spells as the sheet does.
  Future<({String id, Comparison comparison, String info, String code})> toCodes(
    WidgetTester tester, {
    bool tabletAsks = false,
  }) async {
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    final String id;
    final String info;
    if (tabletAsks) {
      id = uuidV7();
      await reply(tester, 'compare_start', {'c': id, 'commitment': comparison.commitment});
      comparison.establish(opened('compare_key')['key']! as String);
      await reply(tester, 'compare_key', {'c': id, 'key': comparison.publicKey});
      info = 'heart-of.me/compare/v1\n${tablet.id}\n${phone.id}';
    } else {
      final asked = opened('compare_start');
      id = asked['c']! as String;
      await reply(tester, 'compare_key', {'c': id, 'key': comparison.publicKey});
      comparison.establish(opened('compare_key')['key']! as String, theirCommitment: asked['commitment']! as String);
      info = 'heart-of.me/compare/v1\n${phone.id}\n${tablet.id}';
    }
    return (id: id, comparison: comparison, info: info, code: comparison.code(info).decimals.join('   '));
  }

  testWidgets('a vouch that fails says the device is approved here only, and the rest are told later', (tester) async {
    when(
      api.vouchForCryptoDevice(any, vouchedBy: anyNamed('vouchedBy'), signature: anyNamed('signature')),
    ).thenThrow({'error': 'server error', 'code': 'internal'});
    await pump(tester);
    await openDevices(tester);
    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();
    final (:id, :comparison, :info, code: _) = await toCodes(tester);

    await tester.tap(find.byKey(AppKeys.codesMatch));
    await tester.pumpTimes();
    await reply(tester, 'compare_mac', {
      'c': id,
      'mac': comparison.mac('${tablet.identityKey}|${tablet.signingKey}', info),
    });
    await reply(tester, 'compare_done', {'c': id});

    expect(find.text(l(tester).compareCodesVouchOwed), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();
    expect(find.text(l(tester).deviceApprovedHereOnly), findsOneWidget);
    expect(find.text(l(tester).deviceApproved), findsNothing);
  });

  testWidgets('a second tap on Compare codes starts nothing more', (tester) async {
    await pump(tester);
    await openDevices(tester);

    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)), warnIfMissed: false);
    await tester.pumpTimes();

    expect(sent.where((each) => each.kind == 'compare_start'), hasLength(1));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(l(tester).compareCodesCantStart), findsNothing);
  });

  testWidgets("one that can't start opens no sheet, and says so", (tester) async {
    await pump(tester);
    await openDevices(tester);
    // already comparing, from somewhere that shows no sheet
    unawaited(DeviceKeys.of(root(tester)).approval.start(tablet.id));
    await tester.pumpTimes();

    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text(l(tester).compareCodesCantStart), findsOneWidget);
    expect(sent.where((each) => each.kind == 'compare_start'), hasLength(1));
  });

  testWidgets('a device asking while a sheet is up waits for it to close, and closing it ends only its own', (
    tester,
  ) async {
    await pump(tester);
    await openDevices(tester);
    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();
    final first = opened('compare_start')['c']! as String;
    await reply(tester, 'compare_cancel', {'c': first});
    expect(find.text(l(tester).compareCodesCancelled), findsOneWidget);

    final again = Comparison.start();
    addTearDown(again.end);
    await reply(tester, 'compare_start', {'c': uuidV7(), 'commitment': again.commitment});

    // the tablet's new ask runs, its key sent, behind the sheet still up
    final name = 'Device ${tablet.id.replaceAll('-', '').substring(26).toUpperCase()}';
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(l(tester).compareCodesCancelled), findsOneWidget);
    expect(find.text(l(tester).compareCodesAsked(name)), findsNothing);
    expect(sent.last.kind, 'compare_key');

    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();

    expect(sent.last.kind, 'compare_key', reason: 'closing the first said no to nothing');
    expect(DeviceKeys.of(root(tester)).approval.value!.running, isTrue);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(l(tester).compareCodesAsked(name)), findsOneWidget);
  });

  testWidgets('without a coaching switch on there is no row for it', (tester) async {
    tall(tester);
    SharedPreferences.setMockInitialValues(pastOnboarding());
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      keyVault: MemoryKeyVault(),
      settle: false,
    );
    await tester.pumpTimes();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();

    expect(find.byKey(AppKeys.developerApi), findsOneWidget);
    expect(find.byKey(AppKeys.yourDevices, skipOffstage: false), findsNothing);
  });

  RenderParagraph paragraph(WidgetTester tester, Finder finder) {
    return tester.renderObject<RenderParagraph>(find.descendant(of: finder, matching: find.byType(RichText)).first);
  }

  /// Whether [code] took one line: laid out with no limit, it is as tall.
  bool oneLine(WidgetTester tester, String code) {
    final rendered = paragraph(tester, find.text(code));
    return rendered.size.height <= rendered.getMaxIntrinsicHeight(double.infinity) + .5;
  }

  /// The sheet's two answers (#668), side by side: one size, one line, full
  /// targets.
  void expectAnswersSideBySide(WidgetTester tester) {
    final match = tester.getRect(find.byKey(AppKeys.codesMatch));
    final dontMatch = tester.getRect(find.byKey(AppKeys.codesDontMatch));
    expect(match.size, dontMatch.size, reason: 'the two answers share one size');
    expect(match.top, dontMatch.top, reason: 'and one line');
    expect(match.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  }

  /// The two answers stacked full width, the way out first as the dialogs
  /// stack it, with no word in either label broken across lines.
  void expectAnswersStacked(WidgetTester tester) {
    final match = tester.getRect(find.byKey(AppKeys.codesMatch));
    final dontMatch = tester.getRect(find.byKey(AppKeys.codesDontMatch));
    expect((match.left, match.width), (dontMatch.left, dontMatch.width), reason: 'one column, one width');
    expect(dontMatch.bottom, lessThanOrEqualTo(match.top), reason: 'the way out first');
    expect(match.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    for (final key in [AppKeys.codesMatch, AppKeys.codesDontMatch]) {
      final label = paragraph(tester, find.byKey(key));
      for (final word in label.text.toPlainText().split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: label.text.style),
          textDirection: .ltr,
          textScaler: label.textScaler,
        )..layout();
        expect(painter.width, lessThanOrEqualTo(label.constraints.maxWidth), reason: '"$word" breaks mid-word');
        painter.dispose();
      }
    }
  }

  /// The tablet asks, and the sheet comes up over the profile at [size].
  Future<String> sheetAt(WidgetTester tester, Size size) async {
    await pump(tester, size: size);
    final (:code, id: _, comparison: _, info: _) = await toCodes(tester, tabletAsks: true);
    return code;
  }

  // whether the room the sheet has makes the type scale's 48pt too big
  const sizes = {
    'a 360dp Android phone': (Size(360, 780), shrinks: true),
    'an iPhone 17 Pro': (Size(402, 874), shrinks: true),
    'an iPad in landscape': (Size(1194, 834), shrinks: false),
    'an iPad in portrait': (Size(834, 1194), shrinks: false),
  };

  for (final MapEntry(key: device, value: (size, :shrinks)) in sizes.entries) {
    testWidgets('on $device the code reads as one row, the answers as one pair, and Close fills the row', (
      tester,
    ) async {
      await pump(tester, size: size);
      final (:id, :comparison, :info, :code) = await toCodes(tester, tabletAsks: true);

      expect(find.text(code), findsOneWidget);
      expect(oneLine(tester, code), isTrue, reason: '$code wrapped');
      final fontSize = paragraph(tester, find.text(code)).text.style!.fontSize!;
      switch (shrinks) {
        // shrunk to fit, not to the floor: on a phone it still spans the row
        case true:
          expect(fontSize, inExclusiveRange(24, 48));
          final row = tester
              .getRect(find.byKey(AppKeys.codesDontMatch))
              .expandToInclude(tester.getRect(find.byKey(AppKeys.codesMatch)));
          expect(paragraph(tester, find.text(code)).getMaxIntrinsicWidth(double.infinity), greaterThan(row.width - 6));
        case false:
          expect(fontSize, 48, reason: 'room for the type scale: nothing to shrink');
      }
      expectAnswersSideBySide(tester);
      // the sheet has no row in the a11y matrix, which needs a comparison
      // played to it: its answers are held to the same target guidelines here.
      // Not text contrast: with the app's real fonts loaded, the checker reads
      // the antialiased edges of 14pt text as its colour, and on Linux CI
      // every line of the sheet, plain body text included, measured 2.5:1
      // while macOS measured a pass. The colours are the theme's own pairs
      // (onSurface on the sheet, on surfaceContainerHighest), which the
      // matrix's contrast rows already hold to 4.5:1 on other screens
      final semantics = tester.ensureSemantics();
      // released in the body, not a tear-down: the binding checks for open
      // handles before tear-downs run
      try {
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
      final pair = tester
          .getRect(find.byKey(AppKeys.codesDontMatch))
          .expandToInclude(tester.getRect(find.byKey(AppKeys.codesMatch)));

      await tester.tap(find.byKey(AppKeys.codesMatch));
      await tester.pumpTimes();
      await reply(tester, 'compare_mac', {
        'c': id,
        'mac': comparison.mac('${tablet.identityKey}|${tablet.signingKey}', info),
      });
      await reply(tester, 'compare_done', {'c': id});
      expect(find.text(l(tester).compareCodesDone), findsOneWidget);

      // the done step's one action spans the sheet like the pair above it
      final close = tester.getRect(find.byKey(AppKeys.closeComparison));
      expect(close.left, closeTo(pair.left, 1));
      expect(close.width, closeTo(pair.width, 1));
      expect(close.width, lessThanOrEqualTo(dialogWidth), reason: 'capped on a tablet');
      expect(close.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      expect(tester.takeException(), isNull);
    });
  }

  // the widest faces, in bold, a step up the text size, at the narrowest
  // phone: where a fit measured at the plain weight and base size wrapped
  for (final preset in Preset.values) {
    testWidgets('in ${preset.name}, with bold text a step larger, the code still takes one row on a 360dp phone', (
      tester,
    ) async {
      tester.platformDispatcher
        ..textScaleFactorTestValue = 1.15
        ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pump(tester, size: const Size(360, 780));
      AppTheme.of(tester.element(find.byType(MaterialApp))).preset = preset;
      await tester.pumpTimes();
      final (:code, id: _, comparison: _, info: _) = await toCodes(tester, tabletAsks: true);

      expect(paragraph(tester, find.text(code)).text.style?.fontWeight, FontWeight.bold, reason: 'drawn bold');
      expect(oneLine(tester, code), isTrue, reason: '$code wrapped');
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in const [Locale('en'), Locale('fr'), Locale('ru')]) {
    testWidgets('in $locale on a 360dp phone the code takes one row, and at twice the text size it wraps by group '
        'and the answers stack whole', (tester) async {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final code = await sheetAt(tester, const Size(360, 780));
      expect(oneLine(tester, code), isTrue, reason: '$code wrapped');
      // French stacks already: "Ils ne correspondent pas" outgrows half a phone
      final sideBySide =
          tester.getRect(find.byKey(AppKeys.codesMatch)).top == tester.getRect(find.byKey(AppKeys.codesDontMatch)).top;
      expect(sideBySide, locale.languageCode != 'fr');
      if (sideBySide) {
        expectAnswersSideBySide(tester);
      } else {
        expectAnswersStacked(tester);
      }

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpTimes();

      expect(oneLine(tester, code), isFalse, reason: 'grown past the row, it wraps');
      final rendered = paragraph(tester, find.text(code));
      final groups = code.split('   ').map((group) {
        final painter = TextPainter(
          text: TextSpan(text: group, style: rendered.text.style),
          textDirection: .ltr,
          textScaler: rendered.textScaler,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });
      expect(groups.every((width) => width <= rendered.constraints.maxWidth), isTrue, reason: 'no group broken');
      expectAnswersStacked(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('in Russian on a 360dp phone at large text, a row keeps its title whole beside its menu', (
    tester,
  ) async {
    tester.platformDispatcher
      ..localesTestValue = [const Locale('ru')]
      ..textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // every kind of row the page has: one not seen lately, one waiting, and
    // removals by this device and by another
    CryptoDevice other(String id, {DateTime? lastSeenOn, DateTime? removedAt, String? removedBy}) => CryptoDevice(
      id: id,
      userId: 'muffin',
      identityKey: tablet.identityKey,
      signingKey: tablet.signingKey,
      fallbackKey: tablet.fallbackKey,
      createdAt: DateTime.utc(2026, 11, 20),
      lastSeenOn: lastSeenOn,
      removedAt: removedAt,
      removedBy: removedBy,
    );
    when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer(
      (_) async => CryptoDevices(
        [
          phone,
          tablet,
          other('01a1e000-0000-7000-8000-00000000cc01', lastSeenOn: DateTime.utc(2026, 10, 1)),
        ],
        waiting: [other('01a1e000-0000-7000-8000-00000000cc02')],
        removed: [
          other('01a1e000-0000-7000-8000-00000000cc03', removedAt: DateTime.utc(2026, 11, 24), removedBy: phone.id),
          other('01a1e000-0000-7000-8000-00000000cc04', removedAt: DateTime.utc(2026, 11, 22), removedBy: tablet.id),
        ],
      ),
    );
    await pump(tester, size: const Size(360, 780));
    HeartRouter.of(root(tester)).pushYourDevices(root(tester));
    await tester.pumpTimes();

    final row = find.byKey(AppKeys.deviceRow(tablet.id));
    final title = find.descendant(of: row, matching: find.text(deviceName(l(tester), tablet.id)));
    final menu = find.byKey(AppKeys.deviceMenu(tablet.id));
    final compare = find.byKey(AppKeys.compareCodes(tablet.id));
    expect(tester.getRect(title).right, lessThanOrEqualTo(tester.getRect(menu).left));
    expect(oneLine(tester, deviceName(l(tester), tablet.id)), isTrue, reason: 'the title wrapped');
    expect(tester.getRect(compare).top, greaterThan(tester.getRect(title).bottom), reason: 'under the words');
    // the app bar's logo stripe overflows at this text size on every page
    // that has one, rows or not: not this test's to answer
    tester.takeException();

    // a picture to look at, when asked for one
    if (Platform.environment['HEART_SHOTS'] case final String dir) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.ancestor(of: find.byType(YourDevicesPage), matching: find.byType(RepaintBoundary)).first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        File('$dir/your_devices_ru_360_1.3.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });

  testWidgets('a comparison abandoned under the sheet can no longer be answered (#668)', (tester) async {
    final code = await sheetAt(tester, const Size(360, 780));
    expect(find.text(code), findsOneWidget);

    // the keys stop, as on a sign-out: the comparison is gone, the sheet not
    DeviceKeys.of(root(tester)).stop();
    await tester.pumpTimes();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(l(tester).compareCodesCancelled), findsOneWidget);
    expect(find.byKey(AppKeys.codesMatch), findsNothing);
    expect(find.byKey(AppKeys.codesDontMatch), findsNothing);
    await tester.tap(find.byKey(AppKeys.closeComparison));
    await tester.pumpTimes();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
