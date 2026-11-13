import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A coach's invitation, from the student's side (#553): the link opens the
/// ask, and the answer lands; Settings then holds the coach.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late HeartRouter router;

  const token = '9kAxjMgFcH8wAlbJUwiesRT-ZcvQ2_KOJe4mC645glM';

  Connection coach({ConnectionStatus status = .active, List<String> shares = const [], String? name}) => Connection(
    targetId: 'alex',
    role: .student,
    domain: .fitness,
    status: status,
    createdAt: DateTime.utc(2026, 11, 8),
    connectionId: 'c1',
    acceptedAt: DateTime.utc(2026, 11, 8),
    shares: shares,
    name: name,
  );

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    router = HeartRouter();
    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(api.getBlocks(cursor: anyNamed('cursor'))).thenAnswer((_) async => (items: <BlockedPerson>[], cursor: null));
    when(api.previewInvitation(token)).thenAnswer(
      (_) async => InvitationPreview.fromJson({'inviterName': 'Alex', 'good': true}),
    );
  });

  /// Wide: under the test font the page's longer lines and Settings overflow a
  /// phone, as the a11y harness's sweep knows.
  Future<void> pump(WidgetTester tester, {Map<String, Object> prefs = const {}, bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      router: router,
      firebaseAuth: switch (signedIn) {
        true => MockFirebaseAuth(
          mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
          signedIn: true,
        ),
        false => MockFirebaseAuth(signedIn: false),
      },
      settle: false,
    );
    await tester.pumpTimes();
  }

  Preferences preferencesOf(WidgetTester tester) => Preferences.of(tester.element(find.byType(Scaffold).first));

  testWidgets('accepting shares only what was chosen, turns Your coach on, and remembers who and their key', (
    tester,
  ) async {
    when(api.acceptInvitation(token, any)).thenAnswer((_) async => AcceptedInvitation(coach(shares: ['goals'])));
    await pump(tester);

    router.openInvitation(token, fingerprint: 'fp22chars');
    await tester.pumpTimes();
    expect(find.text('Alex would like to coach you'), findsOneWidget);

    await tester.tapByKey(AppKeys.invitationShareGoals);
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(AppKeys.invitationAccept));
    await tester.tapByKey(AppKeys.invitationAccept);
    await tester.pumpTimes();

    verify(api.acceptInvitation(token, {ConnectionShare.goals})).called(1);
    final preferences = preferencesOf(tester);
    expect(preferences.isOn(.yourCoach), isTrue);
    expect(preferences.coachName('c1'), 'Alex');
    expect(preferences.coachFingerprint('c1'), 'fp22chars');
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Alex is your coach now'), findsOneWidget);
  });

  testWidgets('a link that is no longer good says so, and offers no answer', (tester) async {
    when(api.previewInvitation('gone')).thenAnswer((_) async => InvitationPreview.fromJson({'good': false}));
    await pump(tester);

    router.openInvitation('gone');
    await tester.pumpTimes();

    expect(find.text('This invitation is no longer good'), findsOneWidget);
    expect(find.byKey(AppKeys.invitationAccept), findsNothing);
  });

  testWidgets('declining is a no to Your coach: off, with the one notice', (tester) async {
    when(api.declineInvitation(token)).thenAnswer((_) async {});
    await pump(tester);

    router.openInvitation(token);
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(AppKeys.invitationDecline));
    await tester.tapByKey(AppKeys.invitationDecline);
    await tester.pumpTimes();

    verify(api.declineInvitation(token)).called(1);
    expect(preferencesOf(tester).featureAnswer(.yourCoach), FeatureAnswer.off);
    expect(find.text('You can always turn this on in Settings › Features.'), findsOneWidget);
  });

  testWidgets('closing the ask is a dismissal, which reads as no', (tester) async {
    await pump(tester);

    router.openInvitation(token);
    await tester.pumpTimes();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpTimes();

    expect(preferencesOf(tester).featureAnswer(.yourCoach), FeatureAnswer.off);
    verifyNever(api.declineInvitation(any));
  });

  testWidgets("an earlier coach's yes stays a yes when another invitation is declined", (tester) async {
    when(api.declineInvitation(token)).thenAnswer((_) async {});
    await pump(tester, prefs: {'feature-yourCoach': 'on'});

    router.openInvitation(token);
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(AppKeys.invitationDecline));
    await tester.tapByKey(AppKeys.invitationDecline);
    await tester.pumpTimes();

    expect(preferencesOf(tester).isOn(.yourCoach), isTrue);
  });

  testWidgets('a second link over the first is its own page, with its own coach', (tester) async {
    when(api.previewInvitation('other')).thenAnswer(
      (_) async => InvitationPreview.fromJson({'inviterName': 'Bea', 'good': true}),
    );
    await pump(tester);

    router.openInvitation(token);
    await tester.pumpTimes();
    expect(find.text('Alex would like to coach you'), findsOneWidget);

    router.openInvitation('other');
    await tester.pumpTimes();
    expect(find.text('Bea would like to coach you'), findsOneWidget);
    expect(find.text('Alex would like to coach you'), findsNothing);
  });

  testWidgets('a preview that fails to load is not called dead, and can be tried again', (tester) async {
    var calls = 0;
    when(api.previewInvitation(token)).thenAnswer((_) async {
      if (calls++ == 0) throw StateError('offline');
      return InvitationPreview.fromJson({'inviterName': 'Alex', 'good': true});
    });
    await pump(tester);

    router.openInvitation(token);
    await tester.pumpTimes();
    expect(find.text("Couldn't open this invitation"), findsOneWidget);
    expect(find.text('This invitation is no longer good'), findsNothing);

    await tester.tapByKey(AppKeys.invitationRetry);
    await tester.pumpTimes();
    expect(find.text('Alex would like to coach you'), findsOneWidget);
  });

  testWidgets('a crafted token opens nothing and sends nothing', (tester) async {
    await pump(tester);

    router.openInvitation('../../v1/accounts/x');
    await tester.pumpTimes();

    expect(find.byKey(AppKeys.invitationPage), findsNothing);
    verifyNever(api.previewInvitation(any));
  });

  testWidgets('blocking whoever sent it', (tester) async {
    when(api.blockInviter(token)).thenAnswer((_) async {});
    await pump(tester);

    router.openInvitation(token);
    await tester.pumpTimes();
    await tester.ensureVisible(find.byKey(AppKeys.invitationBlock));
    await tester.tapByKey(AppKeys.invitationBlock);
    await tester.pumpTimes();

    verify(api.blockInviter(token)).called(1);
    expect(find.text("Blocked. They can't invite you again."), findsOneWidget);
  });

  testWidgets('without an account, the one way forward is making one, and the link is kept', (tester) async {
    await pump(tester, signedIn: false);

    router.openInvitation(token, fingerprint: 'fp');
    await tester.pumpTimes();
    expect(find.byKey(AppKeys.invitationAccept), findsNothing);
    await tester.ensureVisible(find.byKey(AppKeys.invitationMakeAccount));
    await tester.tapByKey(AppKeys.invitationMakeAccount);
    await tester.pumpTimes();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(preferencesOf(tester).pendingInvitation, (token: token, fingerprint: 'fp'));
    verifyNever(api.acceptInvitation(any, any));
  });

  testWidgets('a link kept while making an account opens again once there is one', (tester) async {
    await pump(
      tester,
      prefs: {
        'pendingInvitation': [token, 'fp'],
      },
    );

    expect(find.byKey(AppKeys.invitationPage), findsOneWidget);
    expect(preferencesOf(tester).pendingInvitation, isNull);
  });

  group('Settings › Features › Your coach', () {
    Future<void> openFeatures(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpTimes();
      await tester.ensureVisible(find.byKey(AppKeys.features));
      await tester.tapByKey(AppKeys.features);
      await tester.pumpTimes();
    }

    testWidgets("a coach's name is their profile's now, over the one their invitation showed", (tester) async {
      when(api.getConnections()).thenAnswer((_) async => [coach(name: 'Alex Rivera')]);
      await pump(tester, prefs: {'feature-yourCoach': 'on', 'coachName-c1': 'Alex'});
      await openFeatures(tester);

      await tester.scrollUntilVisible(find.byKey(AppKeys.yourCoach('c1')), 200);
      expect(
        find.descendant(of: find.byKey(AppKeys.yourCoach('c1')), matching: find.text('Alex Rivera')),
        findsOneWidget,
      );
    });

    testWidgets('each coach by the name their invitation showed, and leaving one is asked once', (tester) async {
      when(api.getConnections()).thenAnswer((_) async => [coach()]);
      when(api.endConnection('c1')).thenAnswer((_) async {});
      await pump(tester, prefs: {'feature-yourCoach': 'on', 'coachName-c1': 'Alex'});
      await openFeatures(tester);

      await tester.scrollUntilVisible(find.byKey(AppKeys.yourCoach('c1')), 200);
      expect(find.descendant(of: find.byKey(AppKeys.yourCoach('c1')), matching: find.text('Alex')), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpTimes();
      expect(find.text('Leave Alex?'), findsOneWidget);
      await tester.tapByKey(AppKeys.yourCoachLeaveConfirm);
      await tester.pumpTimes();

      verify(api.endConnection('c1')).called(1);
      expect(find.byKey(AppKeys.yourCoach('c1')), findsNothing);
    });

    testWidgets('turning Your coach off pauses the coach, and on resumes them', (tester) async {
      var status = ConnectionStatus.active;
      when(api.getConnections()).thenAnswer((_) async => [coach(status: status)]);
      when(api.setConnectionStatus('c1', any)).thenAnswer((invocation) async {
        status = invocation.positionalArguments[1] as ConnectionStatus;
        return coach(status: status);
      });
      await pump(tester, prefs: {'feature-yourCoach': 'on'});

      preferencesOf(tester).setFeature(.yourCoach, on: false);
      await tester.pumpTimes();
      expect(status, ConnectionStatus.paused);

      preferencesOf(tester).setFeature(.yourCoach, on: true);
      await tester.pumpTimes();
      expect(status, ConnectionStatus.active);
    });

    testWidgets('a pause that fails is owed, and goes through on a later try', (tester) async {
      var fail = true;
      when(api.getConnections()).thenAnswer((_) async => [coach()]);
      when(api.setConnectionStatus('c1', ConnectionStatus.paused)).thenAnswer((_) async {
        if (fail) throw StateError('offline');
        return coach(status: .paused);
      });
      await pump(tester, prefs: {'feature-yourCoach': 'on'});

      preferencesOf(tester).setFeature(.yourCoach, on: false);
      await tester.pumpTimes();
      expect(preferencesOf(tester).coachPauseOwed, isTrue);

      fail = false;
      // anything that tells the presenter again: here, another answer elsewhere
      preferencesOf(tester).setFeature(.recaps, on: false);
      await tester.pumpTimes();
      expect(preferencesOf(tester).coachPauseOwed, isFalse);
    });

    testWidgets('a coach can be left with Your coach off', (tester) async {
      when(api.getConnections()).thenAnswer((_) async => [coach(status: .paused)]);
      when(api.endConnection('c1')).thenAnswer((_) async {});
      await pump(tester, prefs: {'feature-yourCoach': 'off', 'coachName-c1': 'Alex'});
      await openFeatures(tester);

      await tester.scrollUntilVisible(find.byKey(AppKeys.yourCoach('c1')), 200);
      await tester.tap(find.text('Leave'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.yourCoachLeaveConfirm);
      await tester.pumpTimes();

      verify(api.endConnection('c1')).called(1);
    });

    testWidgets('a block shows with the way to lift it, once Your coach has been asked about', (tester) async {
      when(api.getBlocks(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (
          items: [
            BlockedPerson.fromJson({'id': 'alex', 'name': 'Alex', 'since': '2026-11-07T21:05:35Z'}),
          ],
          cursor: null,
        ),
      );
      when(api.liftBlock('alex')).thenAnswer((_) async {});
      await pump(tester, prefs: {'feature-yourCoach': 'off'});
      await openFeatures(tester);

      await tester.scrollUntilVisible(find.byKey(AppKeys.yourCoachUnblock('alex')), 200);
      await tester.tapByKey(AppKeys.yourCoachUnblock('alex'));
      await tester.pumpTimes();

      verify(api.liftBlock('alex')).called(1);
      expect(find.byKey(AppKeys.yourCoachUnblock('alex')), findsNothing);
    });

    testWidgets('never invited: no blocks are asked of the server', (tester) async {
      await pump(tester);
      await openFeatures(tester);
      verifyNever(api.getBlocks(cursor: anyNamed('cursor')));
    });
  });
}
