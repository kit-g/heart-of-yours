// "Erase my data" (#94), through the real app: the row's home on the settings
// page, which session sees it, the confirmation, and where a wiped session
// lands — in the app under a fresh anonymous uid, not on the onboarding.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/onboarding/onboarding.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
    when(db.eraseUser(any)).thenAnswer((_) async {});
  });

  Future<void> pumpToSettings(WidgetTester tester, {required MockFirebaseAuth firebase}) async {
    // the default 800x600 surface overflows LogoStripe under the test
    // environment's fallback font (see a11y_test.dart); a phone-plausible
    // window sidesteps that without touching production layout
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      settle: false,
    );
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    expect(find.byType(SettingsPage), findsOneWidget);
  }

  L l(WidgetTester tester) => L.of(tester.element(find.byType(SettingsPage)));

  group('the settings row', () {
    testWidgets('is the anonymous session\'s "Your data" row, where import stands for an account', (tester) async {
      await pumpToSettings(tester, firebase: MockFirebaseAuth(signedIn: false));

      expect(find.byKey(AppKeys.eraseData), findsOneWidget);
      expect(find.text(l(tester).yourData), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsNothing);
    });

    testWidgets('is absent for a session with an account, which has account deletion instead', (tester) async {
      await pumpToSettings(
        tester,
        firebase: MockFirebaseAuth(
          mockUser: MockUser(uid: 'u1', email: 'u1@test'),
          signedIn: true,
        ),
      );

      expect(find.byKey(AppKeys.eraseData), findsNothing);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    });
  });

  group('the confirmation', () {
    testWidgets('names the health data and offers the way out first', (tester) async {
      await pumpToSettings(tester, firebase: MockFirebaseAuth(signedIn: false));

      await tester.tapByKey(AppKeys.eraseData);
      await tester.pumpTimes();

      final strings = l(tester);
      expect(find.text(strings.eraseDataTitle), findsOneWidget);
      expect(find.text(strings.eraseDataBody), findsOneWidget);
      expect(strings.eraseDataBody, contains('health'), reason: 'the dialog says the health data goes too');
      expect(find.text(strings.eraseDataCancelMessage), findsOneWidget);
      expect(find.byKey(AppKeys.eraseDataConfirm), findsOneWidget);
    });

    testWidgets('cancelled: nothing is wiped and the session is the same one', (tester) async {
      await pumpToSettings(tester, firebase: MockFirebaseAuth(signedIn: false));
      final auth = Auth.of(tester.element(find.byType(SettingsPage)));
      final uid = auth.user!.id;

      await tester.tapByKey(AppKeys.eraseData);
      await tester.pumpTimes();
      await tester.tap(find.text(l(tester).eraseDataCancelMessage));
      await tester.pumpTimes();

      expect(find.text(l(tester).eraseDataTitle), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      verifyNever(db.eraseUser(any));
      expect(auth.user?.id, uid);
    });

    testWidgets(
      'confirmed: the uid is wiped, the session replaced, and the app lands on the profile — not the carousel',
      (
        tester,
      ) async {
        final firebase = MockFirebaseAuth(signedIn: false);
        await pumpToSettings(tester, firebase: firebase);
        final context = tester.element(find.byType(SettingsPage));
        final auth = Auth.of(context);
        final preferences = Preferences.of(context);
        final uid = auth.user!.id;
        await preferences.setBaseColor(uid, 'ember');

        await tester.tapByKey(AppKeys.eraseData);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.eraseDataConfirm);
        await tester.pumpTimes();

        // the store, under the uid that held it
        verify(db.eraseUser(uid)).called(1);
        // what the preferences kept under it
        expect(preferences.getBaseColor(uid), isNull);
        // the device flag stays, so the way back in is the app, not the onboarding
        expect(preferences.onboardingSeen, isTrue);
        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(find.byType(SettingsPage), findsNothing);
        // and the session is an anonymous one again, freshly minted
        expect(auth.isLoggedIn, isTrue);
        expect(auth.isAnonymous, isTrue);
        expect(find.byKey(AppKeys.noAccount), findsOneWidget);
        // nothing about the wipe reached the server
        verifyNever(api.registerAccount(any));
      },
    );
  });
}
