import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:sealbox/sealbox.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// Your devices (#555): the account's devices, and letting one in by
/// comparing a code. The phone is the app; the tablet is played here, with
/// the real encryption library, through the server's queue.
void main() {
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
    when(api.getCryptoDevices(userId: anyNamed('userId'))).thenAnswer((_) async => [phone, tablet]);
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

  /// Tall enough that the Settings list builds its Account section.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester) async {
    tall(tester);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-yourCoach': 'on'});
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

  /// The comparison up to the codes, as the tablet plays it: answers the
  /// app's start with its key, and answers what the code is bound to.
  Future<({String id, Comparison comparison, String info})> toCodes(WidgetTester tester) async {
    final asked = opened('compare_start');
    final comparison = Comparison.start();
    addTearDown(comparison.end);
    final id = asked['c']! as String;
    await reply(tester, 'compare_key', {'c': id, 'key': comparison.publicKey});
    comparison.establish(opened('compare_key')['key']! as String, theirCommitment: asked['commitment']! as String);
    return (id: id, comparison: comparison, info: 'heart-of.me/compare/v1\n${phone.id}\n${tablet.id}');
  }

  testWidgets('a vouch that fails says the device is approved here only, and the rest are told later', (tester) async {
    when(
      api.vouchForCryptoDevice(any, vouchedBy: anyNamed('vouchedBy'), signature: anyNamed('signature')),
    ).thenThrow({'error': 'server error', 'code': 'internal'});
    await pump(tester);
    await openDevices(tester);
    await tester.tap(find.byKey(AppKeys.compareCodes(tablet.id)));
    await tester.pumpTimes();
    final (:id, :comparison, :info) = await toCodes(tester);

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
}
