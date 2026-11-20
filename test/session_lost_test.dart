// An account's session ending from under the running app rather than through
// its own log out (#671): Firebase signs a user out by itself on a revoked or
// expired token or a deleted or disabled account, the server can say the
// account is gone, and a device can lose the keychain that held the session.
// The anonymous session that replaces it starts empty — nothing the account
// held in memory may show under it — while the account's rows stay on the
// device under its uid, untouched, for when it signs back in.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  const account = 'muffin';

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
    when(db.eraseUser(any)).thenAnswer((_) async {});
    // the account's dashboard; every other uid has none
    when(db.getChartRows(account)).thenAnswer(
      (_) async => [
        ChartPreference.create(id: 'pref-1', type: .topSetWeight, data: {'exerciseName': 'bench-press'}).toRow(),
      ],
    );
  });

  Future<MockFirebaseAuth> pumpSignedIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final firebase = MockFirebaseAuth(
      mockUser: MockUser(uid: account, email: 'muffin@test'),
      signedIn: true,
    );
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
    return firebase;
  }

  testWidgets('the anonymous session that follows shows nothing of the account', (tester) async {
    final firebase = await pumpSignedIn(tester);
    final context = tester.element(find.byType(ProfilePage));
    final auth = Auth.of(context);
    final charts = Charts.of(context);
    expect(auth.user?.id, account);
    expect(charts, isNotEmpty, reason: 'the account sees its own dashboard');

    // not the app's log out, which clears on its way: Firebase's own. The
    // mock mints its next anonymous user from `mockUser`, which has to be an
    // anonymous one by then; swapping it raises no event of its own.
    firebase.mockUser = MockUser(uid: 'anonymous', isAnonymous: true);
    await firebase.signOut();
    await tester.pumpTimes();

    expect(auth.isAnonymous, isTrue);
    expect(auth.user?.id, 'anonymous');
    expect(find.byKey(AppKeys.noAccount), findsOneWidget);
    expect(charts, isEmpty, reason: "the account's dashboard is not the anonymous session's");
    expect(charts.userId, auth.user?.id);
    // kept for the account's return, not wiped
    verifyNever(db.eraseUser(any));
  });
}
