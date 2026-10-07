// The app driven from outside it (#284): `heart://app/start[?template=<id>]`
// and `heart://app/finish`, as Siri, the Shortcuts app and launcher shortcuts
// open it. Driven through the real app and its router, the way the Live
// Activity's tap is tested in router_test.dart: the links are redirect
// side effects, not screens.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  const userId = 'u1';

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  /// A template the mirror would produce (see templates_test.dart).
  Template template({required String id, required String name}) {
    final draft = Template.empty(id: id, order: 0);
    draft
      ..name = name
      ..add(bench);
    return Template.fromJson(draft.toMap());
  }

  /// The link the platform reports as the initial route: a cold start.
  void coldStartOn(WidgetTester tester, String link) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = link;
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    stubStartup(db, api);
    // a catalog, or the workouts init that resolves the active workout never runs
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    when(db.startWorkout(any, any)).thenAnswer((_) async {});

    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(null)).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(userId)).thenAnswer((_) async => [template(id: 't1', name: 'Push')]);
    when(api.getTemplates()).thenAnswer((_) async => null);
    when(db.getTemplateFolders(userId)).thenAnswer((_) async => <TemplateFolder>[]);
    when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => <TemplateFolder>[]);
    when(db.storeTemplateFolders(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(db.storeTemplates(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
  });

  /// Launches the app signed in as [userId], with [active] already running if
  /// given, and lets the link do its work.
  ///
  /// The app's own `Workouts.init` and `Templates.init` sit behind `Zone.root`
  /// futures a widget test's clock never pumps (see templates_test.dart), so
  /// the templates are read directly, and the link's bounded wait for the
  /// active workout is ridden out: it then acts on what is known, which is
  /// exactly what the device would have read.
  Future<BuildContext> launch(WidgetTester tester, HeartRouter router, {Workout? active}) async {
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: userId, email: '$userId@test'),
        signedIn: true,
      ),
      router: router,
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    if (active case Workout workout) {
      await Workouts.of(context).startWorkout(source: .template, template: workout);
    }
    await Templates.of(context).init();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpTimes();
    return context;
  }

  /// Copy as the app shows it: read below the app's `Localizations`.
  L copy(WidgetTester tester) => L.of(tester.element(find.byType(Navigator).first));

  bool sheetOpen(HeartRouter router) {
    return router.config.routerDelegate.currentConfiguration.matches.any(
      (match) => match.matchedLocation == '/activeWorkout',
    );
  }

  testWidgets('a template link from a cold start starts that template, opens the sheet, and is the yes', (
    tester,
  ) async {
    coldStartOn(tester, 'heart://app/start?template=t1');
    final router = HeartRouter();
    final context = await launch(tester, router);

    expect(Workouts.of(context).activeWorkout?.name, 'Push');
    expect(sheetOpen(router), isTrue);
    // the reach is the yes: never offered in the app, on from the first use
    expect(Preferences.of(context).isOn(.shortcuts), isTrue);
  });

  testWidgets('a blank link while the app is running starts a workout with the default name', (tester) async {
    final router = HeartRouter();
    final context = await launch(tester, router);
    expect(Workouts.of(context).hasActiveWorkout, isFalse);

    // what the platform does with a link that reaches a running app
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', {'location': 'heart://app/start', 'state': null}),
      ),
      null,
    );
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpTimes();

    expect(Workouts.of(context).activeWorkout?.name, copy(tester).defaultWorkoutName());
    expect(sheetOpen(router), isTrue);
  });

  testWidgets('start over an active workout asks, and cancels nothing on its own', (tester) async {
    coldStartOn(tester, 'heart://app/start?template=t1');
    final router = HeartRouter();
    final context = await launch(tester, router, active: Workout(name: 'Legs')..add(bench));

    // the template card's question: keep the current one, or cancel and start
    expect(find.byKey(WorkoutDetailKeys.discardAndStart), findsOneWidget);
    expect(Workouts.of(context).activeWorkout?.name, 'Legs');
  });

  testWidgets('a template this device does not have starts nothing and lands on the workouts tab', (tester) async {
    coldStartOn(tester, 'heart://app/start?template=nope');
    final router = HeartRouter();
    final context = await launch(tester, router);

    expect(Workouts.of(context).hasActiveWorkout, isFalse);
    expect(sheetOpen(router), isFalse);
    expect(find.byType(WorkoutPage), findsOneWidget);
  });

  testWidgets('finish opens the active workout and asks the Finish question', (tester) async {
    coldStartOn(tester, 'heart://app/finish');
    final router = HeartRouter();
    final context = await launch(tester, router, active: Workout(name: 'Legs')..add(bench));

    expect(sheetOpen(router), isTrue);
    // the Finish button's own question — which, for a workout nothing has been
    // done in yet, is whether to cancel it (`showFinishWorkoutDialog`)
    expect(find.text(copy(tester).cancelWorkoutTitle), findsOneWidget);
    // and over the sheet, not under it: a dialog shown before the sheet's
    // page landed used to be covered by it
    expect(find.text(copy(tester).cancelWorkoutTitle).hitTestable(), findsOneWidget);
    // asked, not done: the workout is still running until the user says so
    expect(Workouts.of(context).activeWorkout?.name, 'Legs');
  });

  testWidgets('finish with no workout running lands on the workouts tab', (tester) async {
    coldStartOn(tester, 'heart://app/finish');
    final router = HeartRouter();
    await launch(tester, router);

    expect(sheetOpen(router), isFalse);
    expect(find.byType(WorkoutPage), findsOneWidget);
  });

  testWidgets('switched off, a link is one the app has no screen for', (tester) async {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-shortcuts': 'off'});
    coldStartOn(tester, 'heart://app/start?template=t1');
    final router = HeartRouter();
    final context = await launch(tester, router);

    expect(Workouts.of(context).hasActiveWorkout, isFalse);
    expect(find.byType(ProfilePage), findsOneWidget);
    // and a no stays a no
    expect(Preferences.of(context).featureAnswer(.shortcuts), FeatureAnswer.off);
  });
}
