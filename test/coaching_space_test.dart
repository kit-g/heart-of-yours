import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/workout/workout.dart' show TemplateEditor;
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
    when(api.getLibraryPrograms(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachProgram>[], cursor: null));
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
    CoachProgramView copy({int sessionRevision = 0}) {
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
          {'id': 's1', 'name': 'Day A', 'order': 0, 'programId': 'p1', 'exercises': <Object>[]},
        ],
        'position': {'week': 2},
      });
    }

    void withCopy() {
      account(coach: true);
      when(api.getClients(former: false, cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: [sam], cursor: null));
      when(api.getClientWorkouts('sam', cursor: anyNamed('cursor')))
          .thenAnswer((_) async => (items: <Workout>[], cursor: null));
      when(api.getClientSkips('sam')).thenAnswer((_) async => <TrainingSkip>[]);
      when(api.getClientProgram('sam', 'p1')).thenAnswer((_) async => copy());
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

      await tester.tapByKey(AppKeys.coachingCopyPutBack('ch1'));
      await tester.pumpTimes();
      verify(api.revertClientChange('sam', 'p1', 'ch1')).called(1);

      await tester.tapByKey(AppKeys.coachingCopyPutBack('ch2'));
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
