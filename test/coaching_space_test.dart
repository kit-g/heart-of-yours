import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

/// The Coaching space (#566): there only with Coach people on, for an account
/// that may coach; otherwise the app is as it was before coaching was built.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  /// The account as the server answers it, with or without the coach
  /// entitlement.
  void account({required bool coach}) {
    when(api.registerAccount(any)).thenAnswer((invocation) async {
      final user = invocation.positionalArguments.single as User;
      return User(
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        settings: user.settings,
        entitlements: [if (coach) 'coach'],
      );
    });
  }

  final share = _FakeShare();
  setUpAll(() => SharePlatform.instance = share);

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(api.getConnections()).thenAnswer((_) async => []);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer((_) async => (items: <Invitation>[], cursor: null));
    when(api.getClients(former: anyNamed('former'), cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <ClientSummary>[], cursor: null));
    when(api.getCoachFeed(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachFeedItem>[], cursor: null));
    share.shared.clear();
  });

  /// A phone by default. Settings is swept wide, as the a11y harness does:
  /// under the test font its pickers overflow a phone's width.
  Future<void> pump(WidgetTester tester, Map<String, Object> prefs, {bool wide = false}) async {
    tester.view.physicalSize = wide ? const Size(1200, 2400) : const Size(1179, 2556);
    tester.view.devicePixelRatio = wide ? 1 : 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({...pastOnboarding(), ...prefs});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
  }

  testWidgets('off, there is no way in, and nothing is read from the server', (tester) async {
    account(coach: true);
    await pump(tester, {});

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byKey(AppKeys.coachingButton), findsNothing);
    verifyNever(api.getConnections());
    verifyNever(api.getClients(former: anyNamed('former'), cursor: anyNamed('cursor')));
  });

  testWidgets('on, but for an account that may not coach, it is still not there', (tester) async {
    account(coach: false);
    await pump(tester, {'feature-coachPeople': 'on'});

    expect(find.byKey(AppKeys.coachingButton), findsNothing);
    verifyNever(api.getConnections());
  });

  testWidgets('on for a coach: the button opens the space, and the way back returns to Profile', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on'});

    verify(api.getConnections()).called(1);
    await tester.tapByKey(AppKeys.coachingButton);
    await tester.pumpTimes();

    expect(find.byType(ClientsPage), findsOneWidget);
    expect(find.byKey(AppKeys.profileStack), findsNothing, reason: "the space's tabs replace the app's");
    final context = tester.element(find.byType(ClientsPage));
    expect(Preferences.of(context).inCoachingSpace, isTrue);

    await tester.tapByKey(AppKeys.coachingMessagesStack);
    await tester.pumpTimes();
    expect(find.byType(CoachMessagesPage), findsOneWidget);

    await tester.tapByKey(AppKeys.coachingYourTraining);
    await tester.pumpTimes();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(Preferences.of(tester.element(find.byType(ProfilePage))).inCoachingSpace, isFalse);
  });

  testWidgets('the app opens in the space it was left in', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

    expect(find.byType(ClientsPage), findsOneWidget);
  });

  testWidgets('left by any other way, a Live Activity or a link, Profile is Profile again', (tester) async {
    account(coach: true);
    // wide: under the test font the Workout tab's header overflows a phone
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
    expect(find.byType(ClientsPage), findsOneWidget);

    GoRouter.of(tester.element(find.byType(ClientsPage))).go('/workout');
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.profileStack);
    await tester.pumpTimes();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ClientsPage), findsNothing);
  });

  testWidgets('left in the space but switched off since, the app opens on Profile', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'off', 'coachingSpace': true});

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ClientsPage), findsNothing);
  });

  testWidgets('switched off from inside, the space goes', (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
    expect(find.byType(ClientsPage), findsOneWidget);

    Preferences.of(tester.element(find.byType(ClientsPage))).setFeature(.coachPeople, on: false);
    await tester.pumpTimes();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ClientsPage), findsNothing);
  });

  testWidgets("a workout of the user's own still going is one line, and the way back to it", (tester) async {
    account(coach: true);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    // wide: under the test font the Workout tab's header overflows a phone
    await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
    expect(find.byKey(AppKeys.coachingBackToWorkout), findsNothing);

    await Workouts.of(tester.element(find.byType(ClientsPage))).startWorkout(source: .blank, name: 'Push');
    await tester.pumpTimes();
    expect(find.text('Your workout is still going'), findsOneWidget);

    await tester.tapByKey(AppKeys.coachingBackToWorkout);
    await tester.pumpTimes();
    expect(find.byType(ClientsPage), findsNothing, reason: 'back in their own space');
    expect(find.byKey(AppKeys.workoutStack), findsOneWidget, reason: 'on the Workout tab, the sheet over it');
    expect(Preferences.of(tester.element(find.byType(Scaffold).first)).inCoachingSpace, isFalse);
  });

  group('inviting someone (#553)', () {
    Invitation invitation({String? token, String status = 'pending'}) => Invitation(
      id: 'i1',
      name: 'Biscuit',
      status: status,
      role: 'COACH',
      domain: 'fitness',
      expiresAt: DateTime.utc(2026, 11, 15),
      createdAt: DateTime.utc(2026, 11, 8),
      token: token,
    );

    testWidgets('a name makes a link, which goes to the share sheet and waits on Clients', (tester) async {
      account(coach: true);
      when(api.createInvitation(any, programId: anyNamed('programId')))
          .thenAnswer((_) async => invitation(token: 'abc'));
      // wide: under the test font the dialog's buttons overflow a phone
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      await tester.tapByKey(AppKeys.coachingInvite);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingMakeLink), findsNothing, reason: 'no one to make it for yet');
      await tester.enterText(find.byKey(AppKeys.coachingInviteName), '  Biscuit ');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingMakeLink);
      await tester.pumpTimes();

      verify(api.createInvitation('Biscuit', programId: null)).called(1);
      expect(share.shared.single.text, contains('/invite.html?t=abc'));
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsOneWidget);
      expect(find.text('Waiting to hear back'), findsOneWidget);
    });

    testWidgets("the beta's refusal says so, and shares nothing", (tester) async {
      account(coach: true);
      when(api.createInvitation(any, programId: anyNamed('programId'))).thenAnswer(
        (_) async => throw {'code': 'coaching_beta'},
      );
      // wide: under the test font the dialog's buttons overflow a phone
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      await tester.tapByKey(AppKeys.coachingInvite);
      await tester.pumpTimes();
      await tester.enterText(find.byKey(AppKeys.coachingInviteName), 'Biscuit');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingMakeLink);
      await tester.pumpTimes();

      expect(find.text('Inviting is open to testers for now.'), findsOneWidget);
      expect(share.shared, isEmpty);
    });

    testWidgets('a cancel that fails says so, and the invitation stays', (tester) async {
      account(coach: true);
      when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (items: [invitation()], cursor: null),
      );
      when(api.cancelInvitation('i1')).thenAnswer((_) async => throw StateError('offline'));
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpTimes();
      await tester.tap(find.text('Cancel invitation'));
      await tester.pumpTimes();

      expect(find.text("Couldn't cancel the invitation. Try again."), findsOneWidget);
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsOneWidget);
    });

    testWidgets('a waiting invitation can be cancelled from its menu', (tester) async {
      account(coach: true);
      when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (items: [invitation()], cursor: null),
      );
      when(api.cancelInvitation('i1')).thenAnswer((_) async {});
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpTimes();
      await tester.tap(find.text('Cancel invitation'));
      await tester.pumpTimes();

      verify(api.cancelInvitation('i1')).called(1);
      expect(find.byKey(AppKeys.coachingInvitation('i1')), findsNothing);
      expect(find.byKey(AppKeys.coachingInvite), findsOneWidget, reason: 'back to the empty state, and its button');
    });
  });

  group('Settings › Features', () {
    Future<void> openFeatures(WidgetTester tester) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/profile/settings/features');
      await tester.pumpTimes();
    }

    testWidgets("Coach people's switch is there only for an account that may coach", (tester) async {
      account(coach: false);
      await pump(tester, {'feature-recaps': 'off'}, wide: true);
      await openFeatures(tester);
      expect(find.text('Coach people'), findsNothing);
    });

    testWidgets("for a coach, Coach people's switch is there; Your coach's waits for an invitation", (tester) async {
      account(coach: true);
      // the server's copy of the account, entitlements and all, arrives here
      // through settings sync, which an answer to any feature sets off: the
      // sign-in's own registration waits on startup a widget test never ends
      await pump(tester, {'feature-recaps': 'off'}, wide: true);
      await openFeatures(tester);
      await tester.scrollUntilVisible(find.text('Coach people'), 200);
      expect(find.text('Coach people'), findsOneWidget);
      expect(find.text('Your coach'), findsNothing);
    });

    testWidgets("once asked about, Your coach's switch is there", (tester) async {
      account(coach: false);
      await pump(tester, {'feature-yourCoach': 'off'}, wide: true);
      await openFeatures(tester);
      await tester.scrollUntilVisible(find.text('Your coach'), 200);
      expect(find.text('Your coach'), findsOneWidget);
    });
  });

  group('the roster (#559)', () {
    final sam = ClientSummary(
      connectionId: 'c-sam',
      studentId: 'sam',
      name: 'Sam',
      status: 'active',
      programName: 'Strength block',
      programWeek: 2,
      programWeeks: 6,
      recent: [DateTime.now().toUtc()],
      reasons: ['note', 'gap'],
    );
    final riley = ClientSummary(connectionId: 'c-riley', studentId: 'riley', name: 'Riley', status: 'paused');
    final pip = ClientSummary(connectionId: 'c-pip', studentId: 'pip', name: 'Pip', status: 'active', reasons: ['gap']);

    void clients(List<ClientSummary> clients) {
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: clients, cursor: null));
    }

    testWidgets('who needs a word comes first, with why in words, and a look clears what it can', (tester) async {
      account(coach: true);
      clients([sam, pip, riley]);
      when(api.markReviewed('c-sam', at: anyNamed('at'))).thenAnswer((_) async {});
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      expect(find.text('No clients yet'), findsNothing);
      expect(find.text('Strength block · week 2 of 6'), findsOneWidget);
      expect(find.text("Left a note · Hasn't trained lately"), findsOneWidget);
      expect(find.text('No program · Paused'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Trained 1 of the last 7 days',
        ),
        findsOneWidget,
      );
      expect(find.byKey(AppKeys.coachingMarkReviewed('c-riley')), findsNothing, reason: 'nothing to look at');
      expect(find.byKey(AppKeys.coachingMarkReviewed('c-pip')), findsNothing, reason: 'a look clears no gap');

      await tester.tapByKey(AppKeys.coachingMarkReviewed('c-sam'));
      await tester.pumpTimes();

      verify(api.markReviewed('c-sam', at: anyNamed('at'))).called(1);
      expect(
        find.descendant(of: find.byKey(AppKeys.coachingClient('c-sam')), matching: find.text("Hasn't trained lately")),
        findsOneWidget,
        reason: 'a gap holds until it stops being true',
      );
      expect(find.byKey(AppKeys.coachingReasonFilter('note')), findsNothing, reason: 'nobody left with a note');
      expect(
        find.byKey(AppKeys.coachingMarkReviewed('c-sam')),
        findsNothing,
        reason: 'a look would clear nothing more',
      );
    });

    testWidgets('a reason filters the roster, and a word this build lacks still counts', (tester) async {
      account(coach: true);
      clients([
        sam,
        ClientSummary(connectionId: 'c-pip', studentId: 'pip', name: 'Pip', status: 'active', reasons: ['shrug']),
        riley,
      ]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingReasonFilter('note'));
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClient('c-sam')), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClient('c-pip')), findsNothing);
      expect(find.byKey(AppKeys.coachingFormerClients), findsNothing, reason: 'only with everyone showing');

      // the chips are one line that scrolls sideways
      await tester.ensureVisible(find.byKey(AppKeys.coachingReasonFilter('shrug')));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingReasonFilter('shrug'));
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClient('c-pip')), findsOneWidget);
      expect(find.text('Needs a word'), findsWidgets);

      await tester.ensureVisible(find.byKey(AppKeys.coachingReasonFilter(null)));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingReasonFilter(null));
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClient('c-riley')), findsOneWidget);
    });

    testWidgets('a wide page makes it a table', (tester) async {
      account(coach: true);
      clients([sam, riley]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Program'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClient('c-sam')), findsOneWidget);
    });

    testWidgets('former clients are read only when opened', (tester) async {
      account(coach: true);
      clients([sam]);
      when(api.getClients(former: true, cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (
          items: [ClientSummary(connectionId: 'c-old', studentId: 'old', name: 'Pepper', status: 'severed')],
          cursor: null,
        ),
      );
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      verifyNever(api.getClients(former: true, cursor: anyNamed('cursor')));

      await tester.scrollUntilVisible(
        find.byKey(AppKeys.coachingFormerClients),
        200,
        scrollable: find.descendant(of: find.byType(ClientsPage), matching: find.byType(Scrollable)).first,
      );
      await tester.tapByKey(AppKeys.coachingFormerClients);
      await tester.pumpTimes();

      verify(api.getClients(former: true, cursor: anyNamed('cursor'))).called(1);
      expect(find.text('Pepper'), findsOneWidget);
    });

    testWidgets('Activity is what they all did, in words, and a kind without words is left out', (tester) async {
      account(coach: true);
      clients([sam]);
      final at = DateTime.utc(2026, 11, 7, 18);
      when(api.getCoachFeed(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (
          items: [
            CoachFeedItem(kind: 'workout', id: 'w1', studentId: 'sam', name: 'Sam', at: at, title: 'Day B'),
            CoachFeedItem(kind: 'skip', id: 's1', studentId: 'sam', name: 'Sam', at: at),
            CoachFeedItem(kind: 'cheer', id: 'x1', studentId: 'sam', name: 'Sam', at: at),
            CoachFeedItem(kind: 'ending', id: 'e1', studentId: 'sam', name: 'Sam', at: at, title: 'Strength block'),
          ],
          cursor: null,
        ),
      );
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      verifyNever(api.getCoachFeed(cursor: anyNamed('cursor')));

      await tester.tapByKey(AppKeys.coachingActivityView);
      await tester.pumpTimes();

      expect(find.text('Sam finished Day B'), findsOneWidget);
      expect(find.text('Sam skipped a session'), findsOneWidget);
      expect(find.text('Sam is near the end of Strength block'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
    });
  });
}
