// Localized-copy layout sweep. Runs the main screens under every locale the
// app ships, on a phone-sized surface, and fails on any exception a longer
// translation provokes — RenderFlex overflows included, which is the point:
// Russian/Spanish/French labels run well past their English siblings, and a
// button that fits "Save" does not necessarily fit "Сохранить".
//
// The screen list and baseline stubs mirror a11y_test.dart (which mirrors
// router_test.dart); a third consumer means the shared harness is the next
// home for them when any of this changes again.
//
// The mid-session locale-change contract — a device language change restates
// `Accept-Language` and re-fetches the catalog — is pinned in heart_state's
// suite (`Exercises.onLocaleChanged`): app startup runs through `Zone.root`
// (see `_initApp`), outside the fake-async test zone, so the full-app harness
// cannot deterministically observe the API side of it.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/widgets/heading_row.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

const _signInWithAppleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

enum _Screen {
  onboarding,
  login,
  profile,
  workout,
  history,
  exercises,
  settings,
  importData,
  coachingClients,
  coachingMessages,
  coachingPrograms,
  coachingMe,
  invitation,
}

/// A folder of two templates, neither in a program: what Programs offers to
/// make a program from, and what gives Templates its folder button's company.
final _split = TemplateFolder(id: 'f1', name: 'Split');

/// What makes every section heading and its conditional actions render: a
/// history (Weekly lens shows only with one), an active goal and an achieved
/// one (Goals' flip button), and [_split].
void _stubHeadingFixtures(MockLocalDatabase db, MockApi api) {
  when(
    db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
  ).thenAnswer((_) async => WorkoutAggregation.dummy());
  when(db.getLensSets(any, any, userId: anyNamed('userId'))).thenAnswer((_) async => <LensSets>[]);

  Goal goal(String id) => Goal(
    id: id,
    metric: .workouts,
    stages: [GoalStage(id: '$id-0', target: 3)],
  );
  when(
    db.getTargetUserGoals(
      requesterId: anyNamed('requesterId'),
      targetUserId: anyNamed('targetUserId'),
      archived: anyNamed('archived'),
    ),
  ).thenAnswer(
    (invocation) async => [
      goal(switch (invocation.namedArguments[#archived]) {
        true => 'achieved',
        _ => 'active',
      }),
    ],
  );

  Template session(String id, int order, String name) =>
      Template.empty(id: id, order: order, folder: _split)..name = name;
  when(db.getTemplates(any)).thenAnswer((_) async => [session('t1', 0, 'Push'), session('t2', 1, 'Pull')]);
  when(db.getTemplateFolders(any)).thenAnswer((_) async => [_split]);
  when(api.getTemplates()).thenAnswer((_) async => null);
  when(api.getFolders(userId: anyNamed('userId'))).thenAnswer((_) async => [_split]);
}

/// Scrolls the line headed [heading] into view and checks where its actions
/// went: beside the heading, under it, or — with [beside] null — either, so
/// long as they stay on the screen.
Future<void> _expectHeading(WidgetTester tester, String heading, {required bool? beside}) async {
  final text = find.descendant(of: find.byType(HeadingRow), matching: find.text(heading));
  await tester.scrollUntilVisible(text, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpTimes();

  final row = tester.widget<HeadingRow>(find.ancestor(of: text, matching: find.byType(HeadingRow)).first);
  final headingRect = tester.getRect(find.byWidget(row.heading));
  final actions = row.actions
      .map((action) => tester.getRect(find.byWidget(action)))
      .where((rect) => !rect.isEmpty)
      .reduce((a, b) => a.expandToInclude(b));
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  final shared = actions.top < headingRect.bottom;

  expect(actions.right, lessThanOrEqualTo(screen.width), reason: '"$heading": its actions run off the screen');
  if (beside != null) {
    expect(shared, beside, reason: '"$heading": its actions should be ${beside ? 'beside' : 'under'} it');
  }
  switch (shared) {
    case true:
      expect(actions.left, greaterThanOrEqualTo(headingRect.right), reason: '"$heading": its actions overlap it');
    case false:
      expect(actions.top, greaterThanOrEqualTo(headingRect.bottom), reason: '"$heading": its actions overlap it');
  }
}

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  // Real text metrics, or the sweep cries wolf: `flutter test` renders with
  // the Ahem block font, where every glyph is an em wide, and even English
  // overflows a phone-sized surface. The app bundles every family it uses
  // (display faces included), so load them all and measure what production
  // measures.
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(pastOnboarding());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _signInWithAppleChannel,
      (call) async => call.method == 'isAvailable' ? false : null,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _signInWithAppleChannel,
        null,
      ),
    );

    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    when(
      db.getWorkoutSummary(
        weeksBack: anyNamed('weeksBack'),
        userId: anyNamed('userId'),
      ),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(db.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(
      db.storeExercises(any, userId: anyNamed('userId'), locale: anyNamed('locale')),
    ).thenAnswer((_) async {});
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getChartRows(any)).thenAnswer((_) async => <Map<String, Object?>>[]);

    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);

    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));

    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer(
      (_) async => ProgressGalleryResponse.fromJson({}),
    );
  });

  Future<void> pumpTo(WidgetTester tester, _Screen screen, Locale locale, {Size phone = const Size(390, 844)}) async {
    // a phone-plausible surface: tight enough that copy that cannot fit says
    // so, wide enough that the fallback test font's metrics don't cry wolf
    const devicePixelRatio = 3.0;
    tester.view.physicalSize = phone * devicePixelRatio;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    // the one screen a device sees only before its first launch is over
    if (screen == _Screen.onboarding) {
      SharedPreferences.setMockInitialValues({});
    }

    // the Coaching space (#566): Coach people on, for an account that may coach
    final coaching = {
      _Screen.coachingClients: AppKeys.coachingClientsStack,
      _Screen.coachingMessages: AppKeys.coachingMessagesStack,
      _Screen.coachingPrograms: AppKeys.coachingProgramsStack,
      _Screen.coachingMe: AppKeys.coachingMeStack,
    };
    if (screen == _Screen.invitation) {
      when(api.previewInvitation('t1')).thenAnswer(
        (_) async => InvitationPreview.fromJson({'inviterName': 'Alexandra', 'good': true}),
      );
    }
    if (coaching.containsKey(screen)) {
      SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-coachPeople': 'on'});
      when(api.isAuthenticated).thenReturn(true);
      when(api.registerAccount(any)).thenAnswer((invocation) async {
        final user = invocation.positionalArguments.single as User;
        return User(id: user.id, email: user.email, settings: user.settings, entitlements: const ['coach']);
      });
      when(api.getConnections()).thenAnswer((_) async => []);
      when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    }

    // no user means an anonymous session; the login page is reached from its
    // profile's no-account dialog, never by redirect
    final firebase = switch (screen) {
      _Screen.onboarding || _Screen.login => MockFirebaseAuth(signedIn: false),
      _ => MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
    };

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

    switch (screen) {
      case _Screen.profile:
        break;
      case _Screen.onboarding:
        // every screen of the carousel gets laid out on the way to the last
        await tester.tapByKey(AppKeys.onboardingNext);
        await tester.pumpTimes(4);
        await tester.tapByKey(AppKeys.onboardingNext);
      case _Screen.login:
        await tester.tapByKey(AppKeys.noAccount);
        await tester.pumpTimes();
        await tester.tapByKey(AppKeys.noAccountLogIn);
      case _Screen.workout:
        await tester.tapByKey(AppKeys.workoutStack);
      case _Screen.history:
        await tester.tapByKey(AppKeys.historyStack);
      case _Screen.exercises:
        await tester.tapByKey(AppKeys.exercisesStack);
      case _Screen.settings:
        await tester.tap(find.byIcon(Icons.settings_rounded));
      case _Screen.importData:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        // below the fold since Settings › Screens grew a row (#611)
        await tester.scrollUntilVisible(
          find.byIcon(Icons.upload_file_rounded),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpTimes();
        await tester.tap(find.byIcon(Icons.upload_file_rounded));
      case _Screen.invitation:
        GoRouter.of(tester.element(find.byType(Navigator).first)).go('/invite.html?t=t1');
      case _Screen.coachingClients || _Screen.coachingMessages || _Screen.coachingPrograms || _Screen.coachingMe:
        await tester.tapByKey(AppKeys.coachingButton);
        await tester.pumpTimes();
        await tester.tapByKey(coaching[screen]!);
    }
    await tester.pumpTimes();
  }

  // Section headings share their line with their actions — Profile's Goals,
  // Weekly lens and Charts, the Workout tab's Programs and Templates. At large
  // text on the narrowest phones a longer language ran that line past the edge
  // (#701); the actions now go under the heading instead. One boot per locale
  // and text size visits all five, with what makes the conditional actions
  // render: an achieved goal beside an active one, and a folder of templates
  // that a program can be made from.
  for (final locale in L.supportedLocales) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('section headings at ${scale}x text under $locale on a 360dp phone', (tester) async {
        SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-programs': 'on'});
        _stubHeadingFixtures(db, api);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpTo(tester, _Screen.profile, locale, phone: const Size(360, 800));

        final l = L.of(tester.element(find.byType(Navigator).first));
        // English fits each line at 1x; the longer languages at 2x do not
        final beside = switch ((locale.languageCode, scale)) {
          ('en', 1.0) => true,
          ('es' || 'fr' || 'ru', 2.0) => false,
          _ => null,
        };
        for (final heading in [l.goals, l.charts]) {
          await _expectHeading(tester, heading, beside: beside);
        }
        // three choices beside the title outgrow a phone in any language
        await _expectHeading(tester, l.lensTitle, beside: false);

        await tester.tapByKey(AppKeys.workoutStack);
        await tester.pumpTimes();
        // the startup chain that would load them runs in the root zone, which
        // a widget test never pumps (see templates_test.dart's openWorkoutTab)
        final templates = Templates.of(tester.element(find.byType(MaterialApp)));
        await templates.init();
        templates.notifyListeners();
        await tester.pumpTimes();
        for (final heading in [l.programs, l.templates]) {
          await _expectHeading(tester, heading, beside: beside);
        }
      });
    }
  }

  for (final locale in L.supportedLocales) {
    for (final screen in _Screen.values) {
      testWidgets(
        '${screen.name} lays out under $locale',
        (tester) async {
          await pumpTo(tester, screen, locale);

          // an overflow or any other layout exception fails the test on its
          // own, with the full error details in the log
        },
      );
    }
  }
}
