import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart' show ClientsPage;
import 'package:heart/presentation/routes/messages/messages.dart' show ThreadPage, UnreadBadge;
import 'package:heart/presentation/widgets/in_view.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';
import 'support/push_client.dart';

/// A push with the app in front arrives as the app's own note (#724), in the
/// app's words, where the system would have drawn a banner: once, gone by
/// itself, out of the way, and absent for what is already on screen or for a
/// push that shows nothing.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late FakePushClient client;

  /// What the server says waits unread in each conversation.
  late int unread;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    client = FakePushClient();
    unread = 0;
    stubStartup(db, api);
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(
      api.registerDevice(
        platform: anyNamed('platform'),
        token: anyNamed('token'),
        utcOffsetMinutes: anyNamed('utcOffsetMinutes'),
      ),
    ).thenAnswer((_) async {});
    when(api.getInvitations(cursor: anyNamed('cursor'))).thenAnswer((_) async => (items: <Invitation>[], cursor: null));
    when(api.getClients(former: anyNamed('former'), cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <ClientSummary>[], cursor: null));
    when(api.getCoachFeed(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachFeedItem>[], cursor: null));
    when(api.getLibraryPrograms(cursor: anyNamed('cursor')))
        .thenAnswer((_) async => (items: <CoachProgram>[], cursor: null));
    when(api.getThreadItems(any, limit: anyNamed('limit')))
        .thenAnswer((_) async => (items: <ThreadItem>[], cursor: null));
    when(db.getThreads(any)).thenAnswer((_) async => []);
    when(db.storeThreads(any, any)).thenAnswer((_) async {});
    when(db.storeThread(any, any)).thenAnswer((_) async {});
    when(db.storeThreadItems(any, any)).thenAnswer((_) async {});
    when(db.getThreadItems(any, any)).thenAnswer((_) async => []);
  });

  Connection connection(String other, {required ConnectionRole role, required String name}) {
    return Connection(
      targetId: other,
      role: role,
      domain: .fitness,
      status: .active,
      createdAt: DateTime.utc(2026, 11, 8),
      connectionId: 'c-$other',
      acceptedAt: DateTime.utc(2026, 11, 8),
      name: name,
    );
  }

  /// The conversation with [other], as the server lists it: [unread] read
  /// when asked.
  void conversation(String other, String name) {
    final thread = Thread(id: 't-$other', connectionId: 'c-$other', otherId: other, otherName: name);
    when(api.openThread('c-$other')).thenAnswer((_) async => thread);
    when(api.getThreads()).thenAnswer(
      (_) async => [Thread(id: 't-$other', connectionId: 'c-$other', otherId: other, otherName: name, unread: unread)],
    );
  }

  /// Muffin, coached by Dana.
  void student() {
    when(api.getConnections()).thenAnswer((_) async => [connection('dana', role: .student, name: 'Dana')]);
    conversation('dana', 'Dana');
  }

  /// Muffin, a coach, with Sam to coach.
  void coach() {
    when(api.registerAccount(any)).thenAnswer((invocation) async {
      final user = invocation.positionalArguments.single as User;
      return User(id: user.id, email: user.email, settings: user.settings, entitlements: ['coach']);
    });
    when(api.getConnections()).thenAnswer((_) async => [connection('sam', role: .coach, name: 'Sam')]);
    conversation('sam', 'Sam');
  }

  Future<void> pump(WidgetTester tester, Map<String, Object> prefs, {Size size = const Size(400, 860)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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
      pushClient: client,
      keyVault: MemoryKeyVault(),
      settle: false,
    );
    await tester.pumpTimes();
  }

  BuildContext app(WidgetTester tester) => tester.element(find.byType(Navigator).first);

  void go(WidgetTester tester, String path) => GoRouter.of(app(tester)).go(path);

  Future<void> arrive(WidgetTester tester, Map<String, String> data, {String? title}) async {
    client.arrivals.add((push: Push.of(data)!, title: title));
    await tester.pumpTimes(4);
  }

  Finder note() => find.byKey(AppKeys.pushNote);

  /// The words the note says, as a screen reader hears them.
  String said(WidgetTester tester) => tester.getSemantics(note()).label;

  Program program({String name = 'Strength block'}) {
    return Program(
      id: 'p1',
      name: name,
      perWeek: 2,
      sessions: const [],
      createdAt: DateTime.utc(2026),
      coachId: 'dana',
      coachName: 'Dana',
    );
  }

  void sends(Program program) {
    when(api.getProgram('p1')).thenAnswer((_) async => program);
    when(api.getProgramActions('p1')).thenAnswer((_) async => []);
    when(api.getProgramBases('p1')).thenAnswer((_) async => []);
  }

  group("a student, Dana's", () {
    setUp(student);

    const on = {'feature-yourCoach': 'on'};

    testWidgets("a message says who wrote, in the app's words, and Profile counts it at once", (tester) async {
      await pump(tester, on);
      go(tester, '/profile');
      await tester.pumpTimes();
      expect(find.descendant(of: find.byKey(AppKeys.profileMessages), matching: find.text('1')), findsNothing);

      unread = 1;
      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Server words');

      expect(note(), findsOneWidget);
      expect(find.text('Dana messaged you'), findsOneWidget);
      expect(find.text('Server words'), findsNothing, reason: 'the app can name who wrote');
      final badge = tester.widget<UnreadBadge>(
        find.descendant(of: find.byKey(AppKeys.profileMessages), matching: find.byType(UnreadBadge)),
      );
      expect(badge.count, 1, reason: 'the inbox was read again as the push arrived');
    });

    testWidgets('a tap opens the conversation, as the push itself would', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      await tester.tap(note());
      await tester.pumpTimes();

      expect(find.byType(ThreadPage), findsOneWidget);
      expect(note(), findsNothing);
    });

    testWidgets('no note for a message in the conversation already open', (tester) async {
      await pump(tester, on);
      HeartRouter.of(app(tester)).openThread('c-dana');
      await tester.pumpTimes();
      expect(find.byType(ThreadPage), findsOneWidget);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

      expect(note(), findsNothing);
    });

    testWidgets('a program from the coach names it, lands where programs are, and a tap opens it', (tester) async {
      sends(program());
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.program_received', 'programId': 'p1'}, title: 'Dana sent you a program');

      expect(find.text('Dana sent you a program'), findsOneWidget);
      expect(find.descendant(of: note(), matching: find.text('Strength block')), findsOneWidget);
      expect(Programs.of(app(tester)).lookup('p1'), isNotNull, reason: 'fetched as it arrived');

      await tester.tap(note());
      await tester.pumpTimes();
      expect(inView((.program, 'p1')), isTrue);
    });

    testWidgets("a coach's change to a program, silent by the server's word, is said by the app", (tester) async {
      sends(program());
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(find.text('Dana changed Strength block'), findsOneWidget);
    });

    testWidgets('no note for a change to the program whose page is open', (tester) async {
      sends(program());
      await pump(tester, on);
      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});
      await tester.tap(note());
      await tester.pumpTimes();
      expect(inView((.program, 'p1')), isTrue);

      sends(program(name: 'Strength block II'));
      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(note(), findsNothing);
    });

    testWidgets('nor for one open over another tab, as a chart or History opens it', (tester) async {
      sends(program());
      await pump(tester, on);
      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpTimes();
      go(tester, '/history');
      await tester.pumpTimes();
      HeartRouter.of(app(tester)).pushProgramOver('p1');
      await tester.pumpTimes();
      expect(inView((.program, 'p1')), isTrue);

      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(note(), findsNothing);
    });

    testWidgets('a program the switches hide is as if never sent, whichever kind', (tester) async {
      // not a coach's: with Programs off, Your coach shows only theirs
      sends(
        Program(id: 'p1', name: 'Strength block', perWeek: 2, sessions: const [], createdAt: DateTime.utc(2026)),
      );
      await pump(tester, {...on, 'feature-programs': 'off'});

      await arrive(tester, {'topic': 'coaching.program_received', 'programId': 'p1'}, title: 'Dana sent you a program');
      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(note(), findsNothing);
    });

    testWidgets('no note for a kind the person silenced in the system', (tester) async {
      client.blocked.add('coaching.message');
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      expect(note(), findsNothing);

      await arrive(tester, {'topic': 'reaction.created'}, title: 'Dana reacted');
      expect(note(), findsOneWidget, reason: 'another kind still shows');
    });

    testWidgets('a conversation that failed to open is not on screen', (tester) async {
      when(api.openThread('c-dana')).thenThrow({'error': 'unavailable'});
      when(api.getThreads()).thenAnswer((_) async => []);
      await pump(tester, on);
      HeartRouter.of(app(tester)).openThread('c-dana');
      await tester.pumpTimes();
      conversation('dana', 'Dana');

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

      expect(note(), findsOneWidget);
    });

    testWidgets('a slow fetch for an older push never replaces a newer note', (tester) async {
      final slow = Completer<Program>();
      sends(program());
      when(api.getProgram('p1')).thenAnswer((_) => slow.future);
      await pump(tester, on);

      client.arrivals.add((
        push: Push.of({'topic': 'coaching.program_received', 'programId': 'p1'})!,
        title: 'Program',
      ));
      await tester.pump();
      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      expect(find.text('Dana messaged you'), findsOneWidget);

      slow.complete(program());
      await tester.pumpTimes(4);

      expect(find.text('Dana messaged you'), findsOneWidget);
      expect(find.text('Dana sent you a program'), findsNothing);
    });

    testWidgets('a push whose fetch outlives the switch shows nothing', (tester) async {
      final slow = Completer<Program>();
      sends(program());
      when(api.getProgram('p1')).thenAnswer((_) => slow.future);
      await pump(tester, on);

      client.arrivals.add((
        push: Push.of({'topic': 'coaching.program_received', 'programId': 'p1'})!,
        title: 'Program',
      ));
      await tester.pump();
      Preferences.of(app(tester)).answerOffer(.yourCoach, yes: false);
      await tester.pumpTimes(2);
      slow.complete(program());
      await tester.pumpTimes(4);

      expect(note(), findsNothing);
    });

    testWidgets('the note on its way out acts on its own push, and leaves the next note be', (tester) async {
      sends(program());
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.program_received', 'programId': 'p1'}, title: 'Dana sent you a program');
      client.arrivals.add((push: Push.of({'topic': 'reaction.created'})!, title: 'Dana reacted'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(note(), findsNWidgets(2), reason: 'one going, one coming');

      // what a screen reader's actions reach, whichever note is on top
      final going = tester.widget<Semantics>(find.ancestor(of: find.text('Dana sent you a program'), matching: note()));
      going.properties.onDismiss!();
      await tester.pump();
      expect(find.text('Dana reacted'), findsOneWidget, reason: "putting the old one away isn't putting this one away");
      going.properties.onTap!();
      await tester.pumpTimes();

      expect(inView((.program, 'p1')), isTrue);
      expect(find.text('Dana reacted'), findsOneWidget);
    });

    group('in front but not active', () {
      Future<void> inactive(WidgetTester tester) async {
        tester.binding.handleAppLifecycleStateChanged(.inactive);
        addTearDown(() => tester.binding.handleAppLifecycleStateChanged(.resumed));
      }

      testWidgets("Android's shade over it: the system's notification instead", (tester) async {
        await pump(tester, on);
        await inactive(tester);

        await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

        expect(client.calls, contains('show coaching.message Dana messaged you'));
        tester.binding.handleAppLifecycleStateChanged(.resumed);
        await tester.pumpTimes();
        expect(note(), findsNothing, reason: 'said once, in the tray');
      });

      testWidgets("iOS's Control Centre over it: the note waits for the app's return", (tester) async {
        client.posts = false;
        await pump(tester, on);
        await inactive(tester);

        await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
        expect(note(), findsNothing);

        tester.binding.handleAppLifecycleStateChanged(.resumed);
        await tester.pumpTimes();
        expect(find.text('Dana messaged you'), findsOneWidget);
      });
    });

    testWidgets('silent pushes stay silent', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.thread_cleared', 'threadId': 't-dana'});
      await arrive(tester, {'topic': 'security.queue_waiting', 'deviceId': 'elsewhere'});
      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'});

      expect(note(), findsNothing);
    });

    testWidgets('it goes by itself, and the next replaces it', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'reaction.created'}, title: 'Dana reacted to your workout');
      expect(find.text('Dana reacted to your workout'), findsOneWidget, reason: 'one this build never heard of');
      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      expect(note(), findsOneWidget);
      expect(find.text('Dana reacted to your workout'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpTimes();
      expect(note(), findsNothing);
    });

    testWidgets('a swipe up puts it away', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      await tester.fling(note(), const Offset(0, -200), 1000);
      await tester.pumpTimes();

      expect(note(), findsNothing);
      expect(find.byType(ThreadPage), findsNothing, reason: 'put away, not opened');
    });

    testWidgets('it takes no touch outside itself', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      final card = tester.getRect(note());
      final hit = tester.hitTestOnBinding(card.bottomCenter + const Offset(0, 24));

      expect(
        hit.path.any((entry) => entry.target == tester.renderObject(note())),
        isFalse,
        reason: 'just under it is the page',
      );
    });

    testWidgets('a screen reader hears it on Android, from its live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, on);
      tester.takeAnnouncements();

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

      expect(said(tester), 'Dana messaged you');
      expect(tester.takeAnnouncements(), isEmpty, reason: 'the live region says it, once');
      final data = tester.getSemantics(note()).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.hasAction(.tap), isTrue);
      expect(data.hasAction(.dismiss), isTrue);
      semantics.dispose();
    });

    testWidgets('a screen reader meets it first, and it waits for them', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        accessibleNavigation: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');
      final order = tester.semantics.simulatedAccessibilityTraversal().toList();
      final at = order.indexWhere((node) => node.label == 'Dana messaged you');
      expect(at, isNonNegative);
      expect(order.indexWhere((node) => node.label.contains('Profile')), greaterThan(at));

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpTimes();
      expect(note(), findsOneWidget, reason: 'no clock on it');
      semantics.dispose();
    });

    testWidgets('with less motion asked for, it is simply there', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pump(tester, on);

      client.arrivals.add((push: Push.of({'topic': 'reaction.created'})!, title: 'Dana reacted'));
      await tester.pump();
      await tester.pump();

      final fades = tester.widgetList<FadeTransition>(find.ancestor(of: note(), matching: find.byType(FadeTransition)));
      expect(fades.every((fade) => fade.opacity.value == 1), isTrue);
      expect(note(), findsOneWidget);
    });

    testWidgets('on a tablet it keeps to a banner\'s width, centred over the rail layout', (tester) async {
      await pump(tester, on, size: const Size(1194, 834));
      expect(find.byType(NavigationRail), findsOneWidget);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

      final card = tester.getRect(note());
      expect(card.width, lessThanOrEqualTo(420));
      expect(card.center.dx, moreOrLessEquals(1194 / 2, epsilon: 1));
    });

    testWidgets('off, nothing runs and nothing shows', (tester) async {
      await pump(tester, {});

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-dana'}, title: 'Dana messaged you');

      expect(note(), findsNothing);
    });
  });

  group("a coach, Sam's", () {
    setUp(coach);

    const on = {'feature-coachPeople': 'on', 'feature-recaps': 'off'};

    testWidgets("a client's message says who, and a tap opens it in Coaching", (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-sam'}, title: 'Sam messaged you');
      expect(find.text('Sam messaged you'), findsOneWidget);

      await tester.tap(note());
      await tester.pumpTimes();
      expect(find.byType(ThreadPage), findsOneWidget);
    });

    testWidgets('no note for the conversation open beside the inbox, and one once another tab is in front', (
      tester,
    ) async {
      await pump(tester, {...on, 'coachingSpace': true}, size: const Size(1600, 1000));
      HeartRouter.of(app(tester)).goToCoachingMessages();
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.inboxThread('t-sam'));
      await tester.pumpTimes();

      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-sam'}, title: 'Sam messaged you');
      expect(note(), findsNothing);

      // the branch keeps its page, the conversation and all, out of sight
      HeartRouter.of(app(tester)).goToCoachingClients();
      await tester.pumpTimes();
      await arrive(tester, {'topic': 'coaching.message', 'threadId': 't-sam'}, title: 'Sam messaged you');
      expect(note(), findsOneWidget);
    });

    testWidgets('an accepted invitation, which names nobody, says it in the server\'s words', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.invitation_accepted'}, title: 'Sam accepted your invitation');
      expect(find.text('Sam accepted your invitation'), findsOneWidget);

      await tester.tap(note());
      await tester.pumpTimes();
      expect(find.byType(ClientsPage), findsOneWidget);
    });

    testWidgets('the daily digest too', (tester) async {
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.workout_digest'}, title: 'Your clients trained today');

      expect(find.text('Your clients trained today'), findsOneWidget);
    });

    testWidgets("a student's change to a program the coach sent stays silent: there's no name for it", (tester) async {
      when(api.getProgram('p1')).thenAnswer(
        (_) async => Program(
          id: 'p1',
          name: 'Strength block',
          sessions: const [],
          createdAt: DateTime.utc(2026),
          coachId: 'muffin',
          coachName: 'Muffin',
        ),
      );
      when(api.getProgramActions('p1')).thenAnswer((_) async => []);
      when(api.getProgramBases('p1')).thenAnswer((_) async => []);
      await pump(tester, on);

      await arrive(tester, {'topic': 'coaching.program_changed', 'programId': 'p1'});

      expect(note(), findsNothing);
    });
  });
}
