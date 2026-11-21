import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/history/history.dart' show WorkoutEditor;
import 'package:heart/presentation/routes/messages/messages.dart' show ThreadPage, ThreadView;
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/workout/workout.dart' show TemplateEditor;
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart' show WorkoutDetail, WorkoutDetailKeys;
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
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
    when(api.getLibraryPrograms(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachProgram>[], cursor: null));
    // a client opened beside the roster opens the conversation beside them (#693)
    when(api.openThread(any)).thenAnswer((invocation) async {
      final connectionId = invocation.positionalArguments.first as String;
      return Thread(id: 't-$connectionId', connectionId: connectionId, otherId: connectionId, otherName: connectionId);
    });
    when(api.getThreadItems(any, limit: anyNamed('limit')))
        .thenAnswer((_) async => (items: <ThreadItem>[], cursor: null));
    share.shared.clear();
  });

  /// A phone by default. Settings is swept wide, as the a11y harness does:
  /// under the test font its pickers overflow a phone's width.
  Future<void> pump(
    WidgetTester tester,
    Map<String, Object> prefs, {
    bool wide = false,
    Size? size,
    KeyVault? keyVault,
    AnalyticsService? analytics,
  }) async {
    tester.view.physicalSize = size ?? (wide ? const Size(1200, 2400) : const Size(1179, 2556));
    tester.view.devicePixelRatio = (wide || size != null) ? 1 : 3;
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
      keyVault: keyVault,
      analytics: switch (analytics) {
        final AnalyticsService service => Analytics(service: service),
        null => null,
      },
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

  testWidgets("Me's rows line up with the page's edges: the tile's own inset, not the list's on top", (tester) async {
    account(coach: true);
    await pump(tester, {'feature-coachPeople': 'on'});
    await tester.tapByKey(AppKeys.coachingButton);
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.coachingMeStack);
    await tester.pumpTimes();

    final page = tester.getRect(find.byType(CoachMePage));
    final settings = find.byKey(AppKeys.coachingSettings);
    final icon = tester.getRect(find.descendant(of: settings, matching: find.byIcon(Icons.settings_rounded)));
    final chevron = tester.getRect(find.descendant(of: settings, matching: find.byIcon(Icons.chevron_right_rounded)));
    // the icons' boxes, not their glyphs: the inset is the tile's to set
    expect(icon.left - page.left, 16);
    expect(page.right - chevron.right, 16);
    final logOut = find.byKey(AppKeys.coachingLogOut);
    expect(
      tester.getRect(find.descendant(of: logOut, matching: find.byIcon(Icons.logout_rounded))).left - page.left,
      16,
    );
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

    testWidgets("with keys on the device, the link carries their fingerprint after '#' (#555)", (tester) async {
      account(coach: true);
      when(api.createInvitation(any, programId: anyNamed('programId')))
          .thenAnswer((_) async => invitation(token: 'abc'));
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true, keyVault: MemoryKeyVault());

      await tester.tapByKey(AppKeys.coachingInvite);
      await tester.pumpTimes();
      await tester.enterText(find.byKey(AppKeys.coachingInviteName), 'Biscuit');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingMakeLink);
      await tester.pumpTimes();

      final fingerprint = await DeviceKeys.of(tester.element(find.byType(Navigator).first)).fingerprint();
      expect(fingerprint, hasLength(22));
      expect(share.shared.single.text, contains('/invite.html?t=abc#$fingerprint'));
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

    testWidgets("once asked about, Your coach's switch is there, and flipping it is counted as Settings'", (
      tester,
    ) async {
      account(coach: false);
      final recorded = RecordedAnalytics();
      await pump(tester, {'feature-yourCoach': 'off'}, wide: true, analytics: recorded);
      await openFeatures(tester);
      await tester.scrollUntilVisible(find.text('Your coach'), 200);
      expect(find.text('Your coach'), findsOneWidget);

      await tester.tap(find.text('Your coach'));
      await tester.pumpTimes();

      expect(recorded.of('feature_switched'), [
        {'feature': 'yourCoach', 'on': 'true', 'source': 'settings'},
      ]);
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

    testWidgets('who needs a word comes first, with why in words, and opening them clears what a look can', (
      tester,
    ) async {
      account(coach: true);
      clients([sam, pip, riley]);
      // the server, asked again after the look, has the note gone
      when(api.markReviewed('c-sam', at: anyNamed('at'))).thenAnswer((_) async {
        clients([
          ClientSummary(
            connectionId: 'c-sam',
            studentId: 'sam',
            name: 'Sam',
            status: 'active',
            programName: 'Strength block',
            programWeek: 2,
            programWeeks: 6,
            recent: [DateTime.now().toUtc()],
            reasons: ['gap'],
          ),
          pip,
          riley,
        ]);
      });
      final recorded = RecordedAnalytics();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, analytics: recorded);
      expect(recorded.property('coaching_role'), [
        'coach',
      ], reason: 'once the entitlements are known, and never a role before');

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
      // opening the client is the look (#686): no button for it
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.pageBack();
      await tester.pumpTimes();

      verify(api.markReviewed('c-sam', at: anyNamed('at'))).called(1);
      expect(recorded.of('client_reviewed'), hasLength(1));
      expect(
        find.descendant(of: find.byKey(AppKeys.coachingClient('c-sam')), matching: find.text("Hasn't trained lately")),
        findsOneWidget,
        reason: 'a gap holds until it stops being true',
      );
      expect(find.byKey(AppKeys.coachingReasonFilter('note')), findsNothing, reason: 'nobody left with a note');

      // a gap a look doesn't clear: opening them marks nothing
      await tester.tapByKey(AppKeys.coachingClient('c-pip'));
      await tester.pumpTimes();
      verifyNever(api.markReviewed('c-pip', at: anyNamed('at')));
    });

    testWidgets('someone who accepts while the coach is away is there when the app comes back', (tester) async {
      account(coach: true);
      clients([]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      expect(find.text('No clients yet'), findsOneWidget);

      clients([sam]);
      void comeBack() {
        tester.binding.handleAppLifecycleStateChanged(.inactive);
        tester.binding.handleAppLifecycleStateChanged(.resumed);
      }

      // a quick switch away and back reads nothing
      comeBack();
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClient('c-sam')), findsNothing);

      await tester.pump(const Duration(minutes: 1));
      comeBack();
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClient('c-sam')), findsOneWidget);
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

  group('a client (#559)', () {
    final sam = ClientSummary(
      connectionId: 'c-sam',
      studentId: 'sam',
      name: 'Sam',
      status: 'active',
      programName: 'Strength block',
      programWeek: 2,
      programWeeks: 6,
      reasons: ['lighter'],
    );
    final dayA = Workout.fromJson({
      'id': 'w1',
      'name': 'Day A',
      'start': '2026-11-07T19:05:00Z',
      'end': '2026-11-07T20:05:00Z',
      'note': 'Last set was a grind',
      'exercises': [
        {
          'id': 'we1',
          'exercise': {'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs', 'own': 0},
          'start': '2026-11-07T19:05:00Z',
          'order': 0,
          'sets': [
            {'id': 's1', 'completed': true, 'started_at': '2026-11-07T19:10:00Z', 'weight': 100.0, 'reps': 5},
            {'id': 's2', 'completed': true, 'started_at': '2026-11-07T19:15:00Z', 'weight': 90.0, 'reps': 5},
          ],
        },
      ],
    });
    const plan = WorkoutPlan({
      'exercises': [
        {
          'exerciseId': 'squat',
          'sets': [
            {'setId': 's1', 'weight': 100, 'reps': 5},
            {'setId': 's2', 'weight': 100, 'reps': 5},
            {'setId': 's3', 'weight': 100, 'reps': 5},
          ],
        },
      ],
    });

    void withSam() {
      account(coach: true);
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [sam], cursor: null));
      when(api.getClientWorkouts('sam', cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [dayA], cursor: null));
      when(api.getClientSkips('sam')).thenAnswer((_) async => [TrainingSkip(at: DateTime.utc(2026, 11, 8, 9))]);
      when(api.getClientWorkoutPlan('sam', 'w1')).thenAnswer((_) async => plan);
    }

    testWidgets('on a phone, a client opens over the roster: their week, their workouts and skips', (tester) async {
      withSam();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      expect(find.byType(ClientPage), findsOneWidget);
      expect(find.text('Strength block · week 2 of 6'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientWorkout('w1')), findsOneWidget);
      expect(find.text('Last set was a grind'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientSkip), findsOneWidget);
      expect(find.text('Skipped a session'), findsOneWidget);
    });

    testWidgets("a client's page leads to the coach's own notes on them (#556)", (tester) async {
      withSam();
      when(db.getCoachNotes(any)).thenAnswer((_) async => []);
      when(api.getNotes(connectionId: anyNamed('connectionId'), cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (notes: <CoachNote>[], cursor: null));
      when(db.replaceCoachNotes(any, any, keep: anyNamed('keep'))).thenAnswer((_) async {});
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault());

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      expect(find.text('Only you can read them'), findsOneWidget);

      await tester.tapByKey(AppKeys.coachingClientNotes);
      await tester.pumpTimes();

      expect(find.byType(ClientNotesPage), findsOneWidget);
      expect(find.text('No notes yet'), findsOneWidget);
      verify(api.getNotes(connectionId: anyNamed('connectionId'), cursor: anyNamed('cursor'))).called(greaterThan(0));
    });

    final pepper = ClientSummary(connectionId: 'c-old', studentId: 'old', name: 'Pepper', status: 'severed');

    /// Sam coached, Pepper gone, and notes that read as none.
    void withPepper({List<ClientSummary>? current}) {
      withSam();
      if (current != null) {
        when(api.getClients(former: false, cursor: anyNamed('cursor')))
            .thenAnswer((_) async => (items: current, cursor: null));
      }
      when(api.getClients(former: true, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [pepper], cursor: null));
      when(db.getCoachNotes(any)).thenAnswer((_) async => []);
      when(api.getNotes(connectionId: anyNamed('connectionId'), cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (notes: <CoachNote>[], cursor: null));
      when(db.replaceCoachNotes(any, any, keep: anyNamed('keep'))).thenAnswer((_) async {});
    }

    Future<void> openFormer(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.coachingFormerClients),
        200,
        scrollable: find.descendant(of: find.byType(ClientsPage), matching: find.byType(Scrollable)).first,
      );
      await tester.tapByKey(AppKeys.coachingFormerClients);
      await tester.pumpTimes();
    }

    testWidgets("a former client opens to the coach's notes on them, and nothing of their training", (tester) async {
      withPepper();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault());
      await openFormer(tester);

      await tester.tapByKey(AppKeys.coachingClient('c-old'));
      await tester.pumpTimes();

      expect(find.byType(ClientPage), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientFormer), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientMessages), findsNothing, reason: 'no conversation to read back');
      expect(find.text('Workouts'), findsNothing);

      // pulled down: the notes and the conversation again, never their training
      await tester.fling(find.byType(ListView).last, const Offset(0, 400), 1000);
      await tester.pumpTimes();
      verifyNever(api.getClientWorkouts('old', cursor: anyNamed('cursor')));
      verifyNever(api.getClientSkips('old'));
      verifyNever(api.getClientPrograms('old'));

      await tester.tapByKey(AppKeys.coachingClientNotes);
      await tester.pumpTimes();

      expect(find.byType(ClientNotesPage), findsOneWidget);
      expect(find.text('Notes on Pepper'), findsOneWidget);
    });

    testWidgets('on a tablet a former client opens beside the roster, which stays as it was', (tester) async {
      withPepper();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault(), wide: true);
      await openFormer(tester);

      await tester.tapByKey(AppKeys.coachingClient('c-old'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingClientPane), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientFormer), findsOneWidget);
      final row = tester.widget<ListTile>(find.byKey(AppKeys.coachingClient('c-old')));
      expect(row.selected, isTrue, reason: 'Former clients stayed open, with Pepper picked');
      verifyNever(api.getClientWorkouts('old', cursor: anyNamed('cursor')));
    });

    testWidgets('a coach whose clients have all left still reaches them', (tester) async {
      withPepper(current: <ClientSummary>[]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault());

      expect(find.byKey(AppKeys.coachingFormerClients), findsOneWidget);
      await tester.tapByKey(AppKeys.coachingFormerClients);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClient('c-old'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingClientFormer), findsOneWidget);
    });

    testWidgets('with nothing kept of a former client here, their name leads nowhere', (tester) async {
      withPepper();
      // no vault, as on the web, and no conversation
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      await openFormer(tester);

      final row = tester.widget<ListTile>(find.byKey(AppKeys.coachingClient('c-old')));
      expect(row.onTap, isNull);
      expect(row.trailing, isNull);
    });

    testWidgets('where keys have nowhere to be kept, as on the web, there are no notes to lead to', (tester) async {
      withSam();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      expect(find.byType(ClientPage), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientNotes), findsNothing);
      verifyNever(api.getNotes(connectionId: anyNamed('connectionId'), cursor: anyNamed('cursor')));
    });

    testWidgets('a workout puts target beside done, saying what was lighter and skipped', (tester) async {
      withSam();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClientWorkout('w1'));
      await tester.pumpTimes();

      final squat = find.byKey(AppKeys.coachingReviewExercise(0));
      expect(find.text('Last set was a grind'), findsOneWidget);
      expect(find.descendant(of: squat, matching: find.text('Squat')), findsOneWidget);
      expect(find.descendant(of: squat, matching: find.text('Asked')), findsOneWidget);
      expect(find.descendant(of: squat, matching: find.text('Lighter')), findsOneWidget);
      expect(find.descendant(of: squat, matching: find.text('Skipped')), findsOneWidget);
      // the coach's own unit: these tests run in pounds
      expect(find.descendant(of: squat, matching: find.text('198.4 lbs x 5')), findsOneWidget);
    });

    testWidgets('from a workout, a message about it, or about one set of it, in words the coach knows', (tester) async {
      withSam();
      final thread = Thread(id: 't-sam', connectionId: 'c-sam', otherId: 'sam', otherName: 'Sam');
      when(api.openThread('c-sam')).thenAnswer((_) async => thread);
      when(api.getThreads()).thenAnswer((_) async => [thread]);
      when(api.getThreadItems('t-sam', limit: anyNamed('limit')))
          .thenAnswer((_) async => (items: <ThreadItem>[], cursor: null));
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClientWorkout('w1'));
      await tester.pumpTimes();
      final context = tester.element(find.byKey(AppKeys.coachingReview));
      final messages = Messages.of(context);

      // a set: a long press on its row, and the one thing the menu offers
      await tester.longPress(find.byKey(AppKeys.reviewSet('s1')));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.reviewSetMessage);
      await tester.pumpTimes();

      expect(find.byType(ThreadPage), findsOneWidget);
      expect(messages.about('c-sam'), const MessageSubject(.exerciseSet, 's1'));
      // a set by what was done in it, never its place: these tests run in pounds
      expect(find.text('About Squat, 220.5 lbs x 5'), findsOneWidget, reason: 'over the box, in words');

      await tester.pageBack();
      await tester.pumpTimes();
      // the whole workout: the page's own action
      await tester.tapByKey(AppKeys.reviewMessage);
      await tester.pumpTimes();

      expect(messages.about('c-sam'), const MessageSubject(.workout, 'w1'));
      final day = DateFormat.MMMEd('en').format(dayA.start.toLocal());
      expect(find.text('About Day A, $day'), findsOneWidget);
    });

    ThreadItem about(String id, String type, String subjectId) {
      return ThreadItem(
        id: id,
        threadId: 't-sam',
        senderId: 'sam',
        kind: 'message',
        subjectType: type,
        subjectId: subjectId,
        content: 'm1.session.ciphertext',
        commitment: 'c',
        tag: 't',
        tagKey: 'k',
        at: DateTime.utc(2026, 11, 8, 9),
        createdAt: DateTime.utc(2026, 11, 8, 9),
        cursor: 'c-$id',
      );
    }

    /// Sam coached, and a conversation holding [items].
    void withThread(List<ThreadItem> items) {
      withSam();
      final thread = Thread(id: 't-sam', connectionId: 'c-sam', otherId: 'sam', otherName: 'Sam');
      when(api.openThread('c-sam')).thenAnswer((_) async => thread);
      when(api.getThreads()).thenAnswer((_) async => [thread]);
      when(api.getThreadItems('t-sam', limit: anyNamed('limit'))).thenAnswer((_) async => (items: items, cursor: null));
      // the device's own copy, kept as the store would keep it
      final stored = <String, StoredItem>{};
      when(db.getThreads(any)).thenAnswer((_) async => []);
      when(db.storeThreads(any, any)).thenAnswer((_) async {});
      when(db.storeThread(any, any)).thenAnswer((_) async {});
      when(db.storeThreadItems(any, any)).thenAnswer((invocation) async {
        for (final each in invocation.positionalArguments[1] as Iterable<StoredItem>) {
          stored[each.item.id] = each;
        }
      });
      when(db.getThreadItems(any, any)).thenAnswer(
        (_) async => stored.values.toList()..sort((a, b) => (a.position ?? 1 << 30).compareTo(b.position ?? 1 << 30)),
      );
    }

    testWidgets("opened straight from Messages, a client's subjects are read, a workout further back by itself", (
      tester,
    ) async {
      withThread([about('i1', 'workout', 'w1'), about('i2', 'workout', 'w9')]);
      final older = Workout.fromJson({
        'id': 'w9',
        'name': 'Day B',
        'start': '2026-10-01T19:05:00Z',
        'end': '2026-10-01T20:05:00Z',
        'exercises': <Object>[],
      });
      when(api.getTargetWorkout(requesterId: anyNamed('requesterId'), targetUserId: 'sam', workoutId: 'w9'))
          .thenAnswer((_) async => older);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault());
      await tester.tapByKey(AppKeys.coachingMessagesStack);
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.inboxThread('t-sam'));
      await tester.pumpTimes();

      final day = DateFormat.MMMEd('en');
      expect(find.text('About Day A, ${day.format(dayA.start.toLocal())}'), findsOneWidget);
      expect(find.text('About Day B, ${day.format(older.start.toLocal())}'), findsOneWidget);
    });

    testWidgets("a workout opened from the conversation's subject sends its message back there, not over it", (
      tester,
    ) async {
      withThread([about('i1', 'workout', 'w1')]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, keyVault: MemoryKeyVault());
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClientMessages);
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.messageSubject);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingReview), findsOneWidget);
      await tester.tapByKey(AppKeys.reviewMessage);
      await tester.pumpTimes();

      expect(find.byType(ThreadPage), findsOneWidget, reason: 'the same conversation, not a second over it');
      expect(find.byKey(AppKeys.coachingReview), findsNothing);
      expect(find.byKey(AppKeys.messageAbout), findsOneWidget);
    });

    testWidgets('someone no longer coached: their workout offers no message, by action or by set', (tester) async {
      withSam();
      when(api.getClients(former: false, cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (
          items: [ClientSummary(connectionId: 'c-sam', studentId: 'sam', name: 'Sam', status: 'severed')],
          cursor: null,
        ),
      );
      when(api.getTargetWorkout(requesterId: anyNamed('requesterId'), targetUserId: 'sam', workoutId: 'w1'))
          .thenAnswer((_) async => dayA);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      GoRouter.of(tester.element(find.byType(Navigator).first)).push('/coaching/clients/c-sam/workouts/w1');
      await tester.pumpTimes();

      expect(find.text('Squat'), findsOneWidget, reason: 'their workout is open');
      expect(find.byKey(AppKeys.reviewMessage), findsNothing);
      await tester.longPress(find.byKey(AppKeys.reviewSet('s1')));
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.reviewSetMessage), findsNothing);
    });

    testWidgets('a workout with no plan lists what was done and compares nothing', (tester) async {
      withSam();
      when(api.getClientWorkoutPlan('sam', 'w1')).thenAnswer((_) async => null);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClientWorkout('w1'));
      await tester.pumpTimes();

      expect(find.text('Not from a program: nothing to compare with'), findsOneWidget);
      expect(find.text('Asked'), findsNothing);
      expect(find.text('Lighter'), findsNothing);
    });

    testWidgets('on a wide page, a client opens beside the roster, and closes back to the table', (tester) async {
      withSam();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
      expect(find.text('Last 7 days'), findsOneWidget);

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      expect(find.byType(ClientPage), findsNothing, reason: 'beside, not over');
      expect(find.byKey(AppKeys.coachingClientPane), findsOneWidget);
      expect(find.byKey(AppKeys.coachingClientWorkout('w1')), findsOneWidget);
      expect(find.text('Last 7 days'), findsNothing, reason: 'the roster narrows to a list');

      await tester.tapByKey(AppKeys.coachingClientClose);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingClientPane), findsNothing);
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('beside the roster, another client opens in the same pane, read after the build', (tester) async {
      withSam();
      final pip = ClientSummary(connectionId: 'c-pip', studentId: 'pip', name: 'Pip', status: 'active');
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [sam, pip], cursor: null));
      when(api.getClientWorkouts('pip', cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: <Workout>[], cursor: null));
      when(api.getClientSkips('pip')).thenAnswer((_) async => <TrainingSkip>[]);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClient('c-pip'));
      await tester.pumpTimes();

      expect(tester.takeException(), isNull);
      verify(api.getClientWorkouts('pip', cursor: anyNamed('cursor'))).called(1);
      expect(find.text('Nothing logged yet'), findsOneWidget);
    });

    testWidgets(
      'on its side, a client opens with the conversation beside them, and a reply is about the workout (#693)',
      (
        tester,
      ) async {
        withSam();
        // a conversation to show first
        when(api.getThreads()).thenAnswer(
          (_) async => [
            Thread(
              id: 't-c-sam',
              connectionId: 'c-sam',
              otherId: 'sam',
              otherName: 'Sam',
              lastAt: DateTime.utc(2026, 11, 12, 8),
            ),
          ],
        );
        await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, size: const Size(1600, 1000));

        await tester.tapByKey(AppKeys.coachingClient('c-sam'));
        await tester.pumpTimes();

        final beside = find.byKey(AppKeys.coachingBeside);
        expect(beside, findsOneWidget);
        expect(find.descendant(of: beside, matching: find.byType(ThreadView)), findsOneWidget);
        expect(
          find.descendant(of: find.byKey(AppKeys.coachingClientPane), matching: find.byKey(AppKeys.coachingBeside)),
          findsNothing,
          reason: 'beside the client, not under them',
        );
        // the latest workout in full, target beside done
        final latest = find.byKey(AppKeys.coachingLatestWorkout);
        expect(find.descendant(of: latest, matching: find.text('Asked')), findsOneWidget);
        expect(find.descendant(of: latest, matching: find.text('Last set was a grind')), findsOneWidget);
        expect(
          find.byKey(AppKeys.coachingClientMessages),
          findsNothing,
          reason: 'the conversation is already beside them',
        );

        await tester.tapByKey(AppKeys.coachingBesideTab('program'));
        await tester.pumpTimes();
        expect(find.descendant(of: beside, matching: find.byType(ThreadView)), findsNothing);

        await tester.tapByKey(AppKeys.coachingReplyAbout);
        await tester.pumpTimes();
        expect(find.descendant(of: beside, matching: find.byType(ThreadView)), findsOneWidget);
        final messages = Messages.of(tester.element(beside));
        expect(messages.about('c-sam'), const MessageSubject(.workout, 'w1'));
      },
    );

    testWidgets('upright, what is beside the client is under them, and stays picked through a turn (#693)', (
      tester,
    ) async {
      withSam();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, size: const Size(900, 1200));

      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      final beside = find.byKey(AppKeys.coachingBeside);
      expect(beside, findsOneWidget);
      // no conversation yet: none is opened on the server just by looking
      expect(find.descendant(of: beside, matching: find.byType(ThreadView)), findsNothing);
      verifyNever(api.openThread(any));
      final client = find.byKey(AppKeys.coachingClientPane);
      expect(tester.getTopLeft(beside).dx, lessThan(tester.getTopRight(client).dx), reason: 'under the client');
      expect(tester.getTopLeft(beside).dy, greaterThan(tester.getTopLeft(client).dy));

      await tester.tapByKey(AppKeys.coachingBesideTab('program'));
      await tester.pumpTimes();

      tester.view.physicalSize = const Size(1600, 1000);
      await tester.pumpTimes();

      expect(tester.takeException(), isNull);
      expect(find.byKey(AppKeys.coachingClientPane), findsOneWidget, reason: 'the same client');
      expect(
        find.descendant(of: beside, matching: find.byType(ThreadView)),
        findsNothing,
        reason: 'still Program',
      );
      expect(
        tester.getTopLeft(beside).dx,
        greaterThanOrEqualTo(tester.getTopRight(client).dx),
        reason: 'beside them now',
      );
    });

    testWidgets('a workout in Activity opens target beside done', (tester) async {
      withSam();
      when(api.getCoachFeed(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (
          items: [
            CoachFeedItem(kind: 'workout', id: 'w1', studentId: 'sam', name: 'Sam', at: dayA.start, title: 'Day A'),
          ],
          cursor: null,
        ),
      );
      when(
        api.getTargetWorkout(requesterId: anyNamed('requesterId'), targetUserId: 'sam', workoutId: 'w1'),
      ).thenAnswer((_) async => dayA);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});

      await tester.tapByKey(AppKeys.coachingActivityView);
      await tester.pumpTimes();
      await tester.tap(find.text('Sam finished Day A'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingReview), findsOneWidget);
      expect(find.text('Lighter'), findsOneWidget);
    });
  });

  group("a client's copy, edited by both (#558)", () {
    final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
    final sam = ClientSummary(
      connectionId: 'c-sam',
      studentId: 'sam',
      name: 'Sam',
      status: 'active',
      programId: 'p1',
      programName: 'Strength block',
      programWeek: 2,
      programWeeks: 4,
    );
    CoachProgramView copy({
      int sessionRevision = 0,
      List<Object> exercises = const [],
      Map<String, Object> planning = const {},
    }) {
      return CoachProgramView.fromJson({
        'program': {
          'id': 'p1',
          'name': 'Strength block',
          'perWeek': 2,
          'weeks': 4,
          'sessions': ['s1'],
          'revision': 0,
          'sessionRevisions': {'s1': sessionRevision},
        },
        'sessions': [
          {'id': 's1', 'name': 'Day A', 'order': 0, 'programId': 'p1', 'exercises': exercises},
        ],
        'position': {'week': 2},
        ...planning,
      });
    }

    void withCopy({ClientSummary? client, CoachProgramView? view}) {
      account(coach: true);
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [client ?? sam], cursor: null));
      when(api.getClientWorkouts('sam', cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: <Workout>[], cursor: null));
      when(api.getClientSkips('sam')).thenAnswer((_) async => <TrainingSkip>[]);
      when(api.getClientProgram('sam', 'p1')).thenAnswer((_) async => view ?? copy());
      when(api.getClientPrograms('sam')).thenAnswer((_) async => [copy().program]);
      when(api.getClientProgramChanges('sam', 'p1', since: anyNamed('since'))).thenAnswer(
        (_) async => [
          ProgramChange(
            id: 'ch1',
            programId: 'p1',
            sessionId: 's1',
            actorId: 'sam',
            kind: 'edit',
            revision: 1,
            before: const {'name': 'Day A'},
            after: const {'name': 'Day A'},
            at: DateTime.utc(2026, 11, 9, 18),
          ),
          ProgramChange(
            id: 'ch2',
            programId: 'p1',
            actorId: 'coach',
            kind: 'edit',
            revision: 1,
            stale: true,
            at: DateTime.utc(2026, 11, 10, 18),
          ),
        ],
      );
    }

    /// Opens Sam's page and starts a log from Day A, up to the editor.
    Future<WorkoutEditor> logDayA(WidgetTester tester) async {
      // wide: the times dialog's wheels overflow a phone under the test font
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      await tester.ensureVisible(find.byKey(AppKeys.coachingLogFor));
      await tester.tapByKey(AppKeys.coachingLogFor);
      await tester.pumpTimes();
      expect(find.byKey(AppKeys.coachingLogBlank), findsOneWidget, reason: 'or something not in the program');
      await tester.tapByKey(AppKeys.coachingLogSession('s1'));
      await tester.pumpTimes();
      expect(find.text('When was it?'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpTimes();
      return tester.widget<WorkoutEditor>(find.byType(WorkoutEditor));
    }

    testWidgets('a session they trained together is logged as theirs, from their program (#560)', (tester) async {
      withCopy();
      when(api.logClientWorkout('sam', any)).thenAnswer(
        (invocation) async => Workout.fromJson({
          ...(invocation.positionalArguments.last as Workout).toMap(),
          'loggedBy': 'muffin',
          'loggedByName': 'Muffin',
        }),
      );

      final editor = await logDayA(tester);

      expect(find.text('Logging for Sam'), findsOneWidget);
      expect((editor.copy.name, editor.copy.templateId, editor.copy.programId), ('Day A', 's1', 'p1'));
      // the exercise's page and pinned notes are the coach's own
      final detail = tester.widget<WorkoutDetail>(find.byType(WorkoutDetail));
      expect((detail.onTapExercise, detail.pinsNotes), (null, false));
      // and so is last time: no column of it, not one left empty (#591)
      detail.onAddExercises([bench]);
      await tester.pumpTimes();
      expect(find.byKey(WorkoutDetailKeys.fillFor(bench.id, 'weight')), findsOneWidget, reason: 'the set table is up');
      expect(find.text('Previous'), findsNothing);

      await editor.logTo!(tester.element(find.byType(WorkoutEditor)), editor.copy);
      await tester.pumpTimes();

      verify(api.logClientWorkout('sam', editor.copy)).called(1);
      expect(find.text('Logged for Sam'), findsOneWidget);
    });

    testWidgets("the session starts at the client's targets, and its plan goes with it (heart-api#439)", (
      tester,
    ) async {
      withCopy(
        view: copy(
          exercises: [
            {
              'id': 'te1',
              'exercise': {'id': bench.id, 'name': bench.name, 'category': 'Barbell', 'target': 'Chest'},
              'sets': [
                {
                  'id': 'set-1',
                  'set_type': 'normal',
                  'target': {
                    'share': 0.7,
                    'reps': {'min': 5, 'max': 5},
                  },
                },
              ],
            },
          ],
          planning: {
            // where a history of nothing folds to, so it can be planned from
            'position': {'week': 1, 'next': 's1'},
            'bases': [
              ProgramBase(
                id: 'b1',
                programId: 'p1',
                exerciseId: bench.id,
                value: 100,
                at: DateTime.utc(2026, 11),
              ).toMap(),
            ],
          },
        ),
      );
      when(api.logClientWorkout('sam', any)).thenAnswer(
        (invocation) async => invocation.positionalArguments.last as Workout,
      );

      final editor = await logDayA(tester);

      final set = editor.copy.single.single;
      // 70% of Sam's 100 kg is 154 lb: 155 on the coach's plates, which count
      // in pounds here
      expect(set.target?[TargetMeasure.weight]?.min, closeTo(155.asKilograms, 0.001));
      set
        ..setMeasurements(weight: 70, reps: 5)
        ..isCompleted = true;
      await editor.logTo!(tester.element(find.byType(WorkoutEditor)), editor.copy);
      await tester.pumpTimes();

      final plan = verify(api.saveClientWorkoutPlan('sam', editor.copy.id, captureAny)).captured.single as WorkoutPlan;
      final planned = ((plan.plan['exercises'] as List).single as Map)['sets'] as List;
      expect((planned.single as Map)['setId'], set.id);
      expect(find.text('Logged for Sam'), findsOneWidget);
    });

    testWidgets('a refusal says why and offers nothing; a failure that may pass offers Retry (#560)', (tester) async {
      withCopy();
      when(api.logClientWorkout('sam', any)).thenThrow({'code': 'forbidden'});

      final editor = await logDayA(tester);
      final context = tester.element(find.byType(WorkoutEditor));
      await editor.logTo!(context, editor.copy);
      await tester.pumpTimes();

      expect(find.text("Couldn't log it: Sam is no longer your client"), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      when(api.logClientWorkout('sam', any)).thenThrow({'code': 'unavailable'});
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      await editor.logTo!(context, editor.copy);
      await tester.pumpTimes();

      expect(find.text("Couldn't log it for Sam"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a second tap while the first is starting starts nothing, and where they are is read afresh', (
      tester,
    ) async {
      withCopy();
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      clearInteractions(api);

      await tester.ensureVisible(find.byKey(AppKeys.coachingLogFor));
      // both before a frame: the second reaches the button as it was
      final button = tester.widget<PrimaryButton>(find.byKey(AppKeys.coachingLogFor));
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'the icon, while it reads');
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingLogBlank), findsOneWidget, reason: 'one menu');
      verify(api.getClientProgram('sam', 'p1')).called(1);
    });

    testWidgets('a former client has no log', (tester) async {
      withCopy(
        client: ClientSummary(connectionId: 'c-sam', studentId: 'sam', name: 'Sam', status: 'severed', programId: 'p1'),
      );
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: true);
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingClientFormer), findsOneWidget, reason: 'their page is open');
      expect(find.byKey(AppKeys.coachingLogFor), findsNothing);
    });

    Future<void> openCopy(WidgetTester tester) async {
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingClientProgram);
      await tester.pumpTimes();
    }

    testWidgets('from their page: the sessions, and what changed, newest first, by whom', (tester) async {
      withCopy();
      await openCopy(tester);

      expect(find.byType(ClientProgramPage), findsOneWidget);
      expect(find.byKey(AppKeys.coachingCopySession('s1')), findsOneWidget);
      expect(find.text('Strength block · week 2 of 4'), findsOneWidget);
      expect(find.text('Sam changed Day A'), findsOneWidget);
      expect(find.text("You changed the program's details"), findsOneWidget);
      expect(find.textContaining('from an older version of the app'), findsOneWidget);
    });

    testWidgets('a copy sent and not started yet is on their page too, waiting', (tester) async {
      withCopy();
      when(api.getClientPrograms('sam')).thenAnswer(
        (_) async => [
          copy().program,
          Program.fromJson({
            ...Program(id: 'p2', name: 'Peaking', perWeek: 3, weeks: 3).toMap(),
            'waitingSince': '2026-11-11T10:00:00.000Z',
          }),
        ],
      );
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true});
      await tester.tapByKey(AppKeys.coachingClient('c-sam'));
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingClientProgram), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(AppKeys.coachingClientCopy('p2')),
          matching: find.text('Waiting for them to start it'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("a session of their copy is theirs: no Previous of the coach's own last sets (#591)", (tester) async {
      withCopy();
      await openCopy(tester);

      await tester.tapByKey(AppKeys.coachingCopySession('s1'));
      await tester.pumpTimes();
      expect(find.byType(TemplateEditor), findsOneWidget);
      tester.widget<WorkoutDetail>(find.byType(WorkoutDetail)).onAddExercises([bench]);
      await tester.pumpTimes();

      final weight = find.byKey(WorkoutDetailKeys.fillFor(bench.id, 'weight'));
      expect(weight, findsOneWidget, reason: 'the set table is up');
      expect(find.text('Previous'), findsNothing);
      // its share of the row kept, not handed out: kg is a fifth of what the
      // set number and the tick leave, as on one's own (padding 8 a side)
      final row = tester.getSize(find.byType(WorkoutDetail)).width - 16 - 44 - 32;
      expect(tester.getSize(weight).width, moreOrLessEquals(row / 5));
    });

    testWidgets("their own program they see, and can't change: no editing, nothing to put back", (tester) async {
      withCopy();
      when(api.getClientPrograms('sam')).thenAnswer((_) async => <Program>[]);
      await openCopy(tester);

      expect(find.text('Their own program: you can see it, not change it.'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingCopyAddSession), findsNothing);
      expect(find.byKey(AppKeys.coachingCopySessionMenu('s1')), findsNothing);
      expect(find.byKey(AppKeys.coachingCopyPutBack('ch1')), findsNothing);
    });

    testWidgets('a change is put back, and one built on since says so', (tester) async {
      withCopy();
      when(api.revertClientChange('sam', 'p1', 'ch1')).thenAnswer((_) async {});
      when(api.revertClientChange('sam', 'p1', 'ch2')).thenThrow({'code': 'conflict'});
      await openCopy(tester);

      // asked first, since it changes what they train (#686): no, then yes
      await tester.tapByKey(AppKeys.coachingCopyPutBack('ch1'));
      await tester.pumpTimes();
      expect(find.text('Put this back?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpTimes();
      verifyNever(api.revertClientChange('sam', 'p1', 'ch1'));
      await tester.tapByKey(AppKeys.coachingCopyPutBack('ch1'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingCopyPutBackConfirm);
      await tester.pumpTimes();
      verify(api.revertClientChange('sam', 'p1', 'ch1')).called(1);

      await tester.tapByKey(AppKeys.coachingCopyPutBack('ch2'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingCopyPutBackConfirm);
      await tester.pumpTimes();
      expect(find.text("Couldn't put that back. It has changed since."), findsOneWidget);
    });

    testWidgets("a session Sam changed first isn't lost: both stay, and Use mine sends it from theirs", (tester) async {
      withCopy();
      final bases = <int>[];
      when(
        api.editClientSession(
          'sam',
          'p1',
          any,
          baseRevision: anyNamed('baseRevision'),
          changeId: anyNamed('changeId'),
        ),
      ).thenAnswer((invocation) async {
        final base = invocation.namedArguments[#baseRevision] as int;
        bases.add(base);
        if (base == 0) throw {'code': 'program_changed', 'revision': 1};
      });
      await openCopy(tester);

      final programs = ClientPrograms.of(tester.element(find.byType(ClientProgramPage)));
      programs.editSession('sam', 'p1', session: programs.view('p1')!.sessions.single);
      // Sam's edit lands meanwhile, so the read after the refusal has revision 1
      when(api.getClientProgram('sam', 'p1')).thenAnswer((_) async => copy(sessionRevision: 1));
      await programs.saveEditable();
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.coachingCopyConflict), findsOneWidget);
      expect(find.text("Sam changed Day A since you opened it. Yours isn't saved."), findsOneWidget);

      await tester.tapByKey(AppKeys.coachingCopyKeepMine);
      await tester.pumpTimes();

      expect(bases, [0, 1]);
      expect(find.byKey(AppKeys.coachingCopyConflict), findsNothing);
    });
  });

  group("a coach's library (#557)", () {
    final squat = Exercise(name: 'Squat', category: .barbell, target: .legs, isMine: true);
    final sam = ClientSummary(connectionId: 'c-sam', studentId: 'sam', name: 'Sam', status: 'active');
    final pip = ClientSummary(connectionId: 'c-pip', studentId: 'pip', name: 'Pip', status: 'active');
    final pepper = ClientSummary(connectionId: 'c-pepper', studentId: 'pepper', name: 'Pepper', status: 'active');
    const programId = '01a1b7d4-bc29-70bb-866b-6549c07024bf';

    /// The server's library, one program per id, a version per save.
    late Map<String, Map<String, dynamic>> bodies;
    late Map<String, int> versions;

    CoachProgram row(String id, {bool body = true}) {
      return CoachProgram(
        id: id,
        name: bodies[id]!['name'] as String,
        version: versions[id]!,
        body: body ? bodies[id] : null,
        updatedAt: DateTime.utc(2026, 11, 10, 12),
      );
    }

    setUp(() {
      bodies = {};
      versions = {};
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat]));
      when(api.getOwnExercises()).thenAnswer((_) async => [squat]);
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [sam, pip, pepper], cursor: null));
      when(api.getLibraryPrograms(cursor: anyNamed('cursor'))).thenAnswer(
        (_) async => (items: [for (final id in bodies.keys) row(id, body: false)], cursor: null),
      );
      when(api.getLibraryProgram(any)).thenAnswer((invocation) async => row(invocation.positionalArguments.first));
      when(api.saveLibraryProgram(any, any)).thenAnswer((invocation) async {
        final [id as String, body as Map<String, dynamic>] = invocation.positionalArguments;
        bodies[id] = body;
        versions[id] = (versions[id] ?? 0) + 1;
        return row(id);
      });
      when(api.getLibraryHolders(any)).thenAnswer((_) async => []);
    });

    /// Strength block, of one session: Day A, a squat for one set of five.
    void written({int version = 1}) {
      bodies[programId] = {
        'name': 'Strength block',
        'note': 'Four weeks, two days a week',
        'perWeek': 2,
        'weeks': 4,
        'sessions': [
          {
            'id': '01a1b7d4-bc59-7ad7-9994-c01207b8fb92',
            'name': 'Day A',
            'exercises': [
              {
                'id': '01a1b7d4-bc59-7012-afde-89362ab6aca6',
                'exercise': squat.id,
                'sets': [
                  {'id': '01a1b7d4-bc59-79c7-9550-874a8fd0647e', 'reps': 5},
                ],
              },
            ],
          },
        ],
      };
      versions[programId] = version;
    }

    Future<void> openPrograms(WidgetTester tester, {bool wide = false}) async {
      account(coach: true);
      await pump(tester, {'feature-coachPeople': 'on', 'coachingSpace': true}, wide: wide);
      // the coach's own exercises, which a body names by id: this harness
      // never reads the catalog by itself
      await Exercises.of(tester.element(find.byType(ClientsPage))).init();
      await tester.tapByKey(AppKeys.coachingProgramsStack);
      await tester.pumpTimes();
    }

    testWidgets('an empty library says so, and a new program is made there, with a note', (tester) async {
      await openPrograms(tester);
      expect(find.text('No programs yet'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingNewProgram), findsNothing, reason: 'the empty page has its own button');

      await tester.tapByKey(AppKeys.coachingNewProgramEmpty);
      await tester.pumpTimes();
      await tester.enterText(find.byKey(AppKeys.programFormName), 'Strength block');
      await tester.enterText(find.byKey(AppKeys.programFormNote), 'Four weeks, two days a week');
      await tester.pump();
      await tester.ensureVisible(find.byKey(AppKeys.programFormSave));
      await tester.tapByKey(AppKeys.programFormSave);
      await tester.pumpTimes();

      final [id as String, body as Map] = verify(api.saveLibraryProgram(captureAny, captureAny)).captured;
      expect(isUuidV7(id), isTrue);
      expect(body, containsPair('name', 'Strength block'));
      expect(body, containsPair('note', 'Four weeks, two days a week'));
      expect(body['sessions'], isEmpty);
      expect(find.byType(CoachProgramPage), findsOneWidget);
      expect(find.text('No sessions yet.'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingSendProgram), findsNothing, reason: 'nothing in it to send');
    });

    testWidgets("a program's page: its sessions by name, and who holds which version", (tester) async {
      written(version: 2);
      when(api.getLibraryHolders(programId)).thenAnswer(
        (_) async => [
          CoachProgramHolder(connectionId: 'c-pip', studentId: 'pip', programId: 'copy', version: 1),
        ],
      );
      await openPrograms(tester);

      expect(find.text('Version 2 · Nov 10, 2026'), findsOneWidget);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();

      expect(find.text('2 times a week · 4 weeks'), findsOneWidget);
      expect(find.text('Four weeks, two days a week'), findsOneWidget);
      expect(find.text('Day A'), findsOneWidget);
      expect(find.text('Squat'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(AppKeys.coachingHolder('c-pip')), 200);
      expect(
        find.descendant(of: find.byKey(AppKeys.coachingHolder('c-pip')), matching: find.text('Pip')),
        findsOneWidget,
        reason: "the roster's name, when the holder comes without one",
      );
      expect(find.text('Version 1; the latest is 2'), findsOneWidget);
    });

    testWidgets('a copy behind is brought up to date, after saying it replaces their edits (#558)', (tester) async {
      written(version: 2);
      when(api.getLibraryHolders(programId)).thenAnswer(
        (_) async => [
          CoachProgramHolder(connectionId: 'c-pip', studentId: 'pip', programId: 'copy', version: 1),
        ],
      );
      when(api.updateLibraryCopies(programId, any)).thenAnswer(
        (_) async => [const ProgramDelivery(connectionId: 'c-pip', delivered: true, programId: 'copy')],
      );
      await openPrograms(tester);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();
      await tester.scrollUntilVisible(find.byKey(AppKeys.coachingUpdateCopy('c-pip')), 200);

      await tester.tapByKey(AppKeys.coachingUpdateCopy('c-pip'));
      await tester.pumpTimes();
      expect(find.text('Bring Pip up to date?'), findsOneWidget);
      expect(find.textContaining('Changes they made to it are replaced'), findsOneWidget);

      await tester.tapByKey(AppKeys.coachingUpdateCopyConfirm);
      await tester.pumpTimes();

      verify(api.updateLibraryCopies(programId, ['c-pip'])).called(1);
      expect(find.text('Pip is up to date'), findsOneWidget);
    });

    testWidgets('a session edited in the template editor is saved into the program', (tester) async {
      written();
      await openPrograms(tester);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();

      await tester.tap(find.text('Day A'));
      await tester.pumpTimes();
      expect(find.byType(TemplateEditor), findsOneWidget);
      expect(find.text('Edit session'), findsOneWidget);
      expect(find.text('Previous'), findsNothing, reason: "the coach's own last sets aren't the client's (#591)");

      await tester.enterText(
        find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)),
        'Day A, heavy',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();

      final body = verify(api.saveLibraryProgram(programId, captureAny)).captured.last as Map;
      final [session as Map] = body['sessions'] as List;
      expect(session['name'], 'Day A, heavy');
      expect(((session['exercises'] as List).single as Map)['exercise'], squat.id);
      expect(find.byType(CoachProgramPage), findsOneWidget);
      expect(find.text('Day A, heavy'), findsOneWidget);
    });

    testWidgets("the kg header fills nothing from the coach's own last squat (#591)", (tester) async {
      written();
      // the coach squatted 140 × 5 last time: their own, not the client's
      when(db.getPreviousSets(any)).thenAnswer(
        (_) async => {
          squat.id: [
            {'set_id': 'q1', 'weight': 140.0, 'reps': 5, 'duration': null, 'distance': null, 'set_type': 'normal'},
          ],
        },
      );
      await openPrograms(tester);
      final previous = PreviousExercises.of(tester.element(find.byType(MaterialApp)));
      await (previous..userId = 'muffin').init();
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();
      await tester.tap(find.text('Day A'));
      await tester.pumpTimes();

      final library = CoachLibrary.of(tester.element(find.byType(TemplateEditor)));
      final session = library.editable!.single;
      expect(previous.matching(session, 0)?['weight'], 140.0, reason: "the app's own last time has it");

      await tester.tapByKey(WorkoutDetailKeys.fillFor(squat.id, 'weight'));
      await tester.pumpTimes();

      expect(session.single.weight, isNull, reason: 'nothing of the coach\'s is written into the session');
      expect(find.textContaining('140'), findsNothing);
    });

    testWidgets('sending: who holds it is greyed, and each client answers on its own', (tester) async {
      written();
      when(api.getLibraryHolders(programId)).thenAnswer(
        (_) async => [
          CoachProgramHolder(connectionId: 'c-pip', studentId: 'pip', programId: 'copy', version: 1),
        ],
      );
      when(api.sendLibraryProgram(programId, any)).thenAnswer(
        (_) async => [
          const ProgramDelivery(connectionId: 'c-sam', delivered: true, programId: 'copy-sam'),
          const ProgramDelivery(connectionId: 'c-pepper', delivered: false, reason: 'program_limit'),
        ],
      );
      await openPrograms(tester);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.coachingSendProgram);
      await tester.pumpTimes();
      expect(find.text('Has it (version 1)'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(AppKeys.coachingSendTo('c-pip'))).onChanged, isNull);

      await tester.tapByKey(AppKeys.coachingSendTo('c-sam'));
      await tester.tapByKey(AppKeys.coachingSendTo('c-pepper'));
      await tester.pump();
      expect(find.text('Send to 2 clients'), findsOneWidget);
      await tester.tapByKey(AppKeys.coachingSendConfirm);
      await tester.pumpTimes();

      final [ids as Iterable] = verify(api.sendLibraryProgram(programId, captureAny)).captured;
      expect(ids, unorderedEquals(['c-sam', 'c-pepper']));
      expect(
        find.text('Sent to 1 client\nNot sent to Pepper: they have as many programs as they can hold'),
        findsOneWidget,
      );
    });

    testWidgets("a save that doesn't arrive is kept, said, and sent again by Retry", (tester) async {
      written();
      await openPrograms(tester);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();

      when(api.saveLibraryProgram(any, any)).thenThrow({'code': 'offline'});
      await tester.tapByKey(AppKeys.coachingRemoveSession('01a1b7d4-bc59-7ad7-9994-c01207b8fb92'));
      await tester.pumpTimes();

      expect(find.text('No sessions yet.'), findsOneWidget);
      expect(find.text('Not saved yet: your last change is only on this device.'), findsOneWidget);
      expect(find.byKey(AppKeys.coachingSendProgram), findsNothing);

      when(api.saveLibraryProgram(any, any)).thenAnswer((invocation) async {
        final [id as String, body as Map<String, dynamic>] = invocation.positionalArguments;
        bodies[id] = body;
        versions[id] = versions[id]! + 1;
        return row(id);
      });
      await tester.tapByKey(AppKeys.coachingUnsavedRetry);
      await tester.pumpTimes();

      expect(find.text('Not saved yet: your last change is only on this device.'), findsNothing);
      expect(bodies[programId]!['sessions'], isEmpty);
    });

    testWidgets('a deleted program leaves the library', (tester) async {
      written();
      when(api.deleteLibraryProgram(programId)).thenAnswer((_) async {
        bodies.remove(programId);
      });
      await openPrograms(tester);
      await tester.tapByKey(AppKeys.coachingLibraryProgram(programId));
      await tester.pumpTimes();

      await tester.tapByKey(AppKeys.coachingProgramMenu);
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.coachingDeleteProgram);
      await tester.pumpTimes();
      expect(find.text('Clients who have it keep their copies.'), findsOneWidget);
      await tester.tapByKey(AppKeys.coachingDeleteConfirm);
      await tester.pumpTimes();

      verify(api.deleteLibraryProgram(programId)).called(1);
      expect(find.byType(CoachProgramsPage), findsOneWidget);
      expect(find.byKey(AppKeys.coachingLibraryProgram(programId)), findsNothing);
    });
  });
}
