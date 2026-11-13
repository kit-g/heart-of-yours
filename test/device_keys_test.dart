import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// This device's encryption keys (#555): opt-in through the coaching
/// switches, by the push client's rule. Off, nothing is made and nothing goes
/// over the wire; a switch going off keeps the keys, inert.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late MemoryKeyVault vault;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    vault = MemoryKeyVault();
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
      (invocation) async => CryptoDevice(
        id: invocation.namedArguments[#id] as String,
        userId: 'muffin',
        identityKey: invocation.namedArguments[#identityKey] as String,
        signingKey: invocation.namedArguments[#signingKey] as String,
        fallbackKey: invocation.namedArguments[#fallbackKey] as String,
        createdAt: DateTime.now(),
      ),
    );
    when(api.addOneTimeKeys(any, any))
        .thenAnswer((invocation) async => (invocation.positionalArguments[1] as Map).length);
    when(api.countOneTimeKeys(any)).thenAnswer((_) async => 50);
    when(api.getKeyQueue(any)).thenAnswer((_) async => []);
  });

  Future<void> pump(WidgetTester tester, Map<String, Object> prefs, {bool anonymous = false}) async {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test', isAnonymous: anonymous),
        signedIn: true,
      ),
      keyVault: vault,
      settle: false,
    );
    await tester.pumpTimes();
  }

  void verifyNothingPublished() {
    verifyNever(
      api.publishCryptoDevice(
        id: anyNamed('id'),
        identityKey: anyNamed('identityKey'),
        signingKey: anyNamed('signingKey'),
        fallbackKey: anyNamed('fallbackKey'),
        vouch: anyNamed('vouch'),
      ),
    );
    verifyNever(api.addOneTimeKeys(any, any));
    verifyNever(api.getKeyQueue(any));
  }

  testWidgets('both coaching switches off: no keys made, nothing sent', (tester) async {
    await pump(tester, {});

    verifyNothingPublished();
    expect(vault.entries, isEmpty);
  });

  testWidgets('an anonymous session has no account to hold keys', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'}, anonymous: true);

    verifyNothingPublished();
    expect(vault.entries, isEmpty);
  });

  testWidgets('Your coach on: the device publishes its keys and its single-use keys, once', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});

    final id = verify(
      api.publishCryptoDevice(
        id: captureAnyNamed('id'),
        identityKey: anyNamed('identityKey'),
        signingKey: anyNamed('signingKey'),
        fallbackKey: anyNamed('fallbackKey'),
        vouch: anyNamed('vouch'),
      ),
    ).captured.single;
    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7')), reason: 'a UUIDv7 the device chose');
    final keys = verify(api.addOneTimeKeys(id, captureAny)).captured.single as Map;
    expect(keys, hasLength(50));
    expect(vault.entries.keys, everyElement(startsWith('keys.muffin.')));
  });

  void resume(WidgetTester tester) {
    for (final AppLifecycleState state in [.inactive, .hidden, .paused, .hidden, .inactive, .resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  testWidgets('back in front, it reads what arrived and restocks', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});
    clearInteractions(api);

    resume(tester);
    await tester.pumpTimes();

    verify(api.getKeyQueue(any)).called(1);
    verify(api.countOneTimeKeys(any)).called(1);
  });

  testWidgets('switched off: it stops, and the keys stay on the device', (tester) async {
    await pump(tester, {'feature-yourCoach': 'on'});
    final kept = Map.of(vault.entries);
    clearInteractions(api);

    Preferences.of(tester.element(find.byType(Navigator).first)).setFeature(.yourCoach, on: false);
    await tester.pumpTimes();
    // back in front: nothing is read or sent while off
    resume(tester);
    await tester.pumpTimes();

    verifyNever(api.getKeyQueue(any));
    verifyNever(api.countOneTimeKeys(any));
    expect(vault.entries, kept);
  });
}
