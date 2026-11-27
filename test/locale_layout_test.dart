// Localized-copy layout sweep. Runs the main screens under every locale the
// app ships, on a phone-sized surface, and fails on any exception a longer
// translation provokes — RenderFlex overflows included, which is the point:
// Russian/Spanish/French labels run well past their English siblings, and a
// button that fits "Save" does not necessarily fit "Сохранить".
//
// The screen list and baseline stubs mirror a11y.dart (which mirrors
// router_test.dart); a third consumer means the shared harness is the next
// home for them when any of this changes again.
//
// The mid-session locale-change contract — a device language change restates
// `Accept-Language` and re-fetches the catalog — is pinned in heart_state's
// suite (`Exercises.onLocaleChanged`): app startup runs through `Zone.root`
// (see `_initApp`), outside the fake-async test zone, so the full-app harness
// cannot deterministically observe the API side of it.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/widgets/heading_row.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/logo.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
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

/// The Workout tab's pinned Start header: the box its sliver pins.
final _startHeader = find.descendant(of: find.byType(PinnedHeaderSliver), matching: find.byType(ColoredBox)).first;

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

  // The largest accessibility text size (iOS's AX5 is 3.1x) on the narrowest
  // phones, in every language: the surfaces that are a fixed line or a fixed
  // height, where growing text was cut rather than made room for.
  for (final locale in L.supportedLocales) {
    for (final width in [320.0, 360.0]) {
      final phone = Size(width, 780);
      final where = 'at the largest text under $locale on a ${width.round()}dp phone';

      // Flutter does not hyphenate: a word wider than its line is broken where
      // the line ends, "Добро пожалова / ть" (#704)
      testWidgets('$where, onboarding breaks no word', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3.1;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = phone * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.localesTestValue = [locale];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await harness.pumpHeartApp(
          tester,
          db: db,
          api: api,
          cdn: cdn,
          firebaseAuth: MockFirebaseAuth(signedIn: false),
          hasLocalNotifications: false,
          settle: false,
        );
        await tester.pumpTimes();

        final l = L.of(tester.element(find.byType(Navigator).first));
        final screens = [
          [l.onboardingWelcomeTitle, l.onboardingWelcomeBody],
          [l.onboardingLocalTitle, l.onboardingLocalBody, l.onboardingLocalTrade],
          [l.onboardingAccountTitle, l.onboardingAccountBody],
        ];
        for (final copy in screens) {
          for (final text in copy) {
            final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
            expect(
              paragraph.getMinIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.constraints.maxWidth),
              reason: '"$text": its longest word is wider than its line',
            );
            expect(paragraph.textScaler.scale(10), greaterThan(10), reason: '"$text" still answers the text size');
          }
          // The copy has a window of its own between Skip and the dots, big
          // enough to read in, and all of it can be scrolled into that window:
          // none is painted under the dots or the button.
          final scrollable = find
              .ancestor(of: find.text(copy.first), matching: find.byType(SingleChildScrollView))
              .first;
          final window = tester.getRect(scrollable);
          final dots = tester.getRect(find.byKey(AppKeys.onboardingScreenCount));
          final action = tester.getRect(
            find.byKey(copy == screens.last ? AppKeys.onboardingContinue : AppKeys.onboardingNext),
          );
          expect(window.bottom, lessThanOrEqualTo(dots.top), reason: 'the copy runs under the dots');
          expect(dots.bottom, lessThanOrEqualTo(action.top));
          expect(action.bottom, lessThanOrEqualTo(phone.height));
          // two thirds of the phone until the last screen, whose second
          // button takes its share
          expect(
            window.height,
            greaterThanOrEqualTo(phone.height * (copy == screens.last ? 1 / 2 : 2 / 3)),
            reason: 'the footer leaves the copy too little room to read in',
          );
          expect(tester.getRect(find.text(copy.first)).top, greaterThanOrEqualTo(window.top));

          final position = tester
              .state<ScrollableState>(
                find.descendant(of: scrollable, matching: find.byType(Scrollable)).first,
              )
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          expect(
            tester.getRect(find.text(copy.last)).bottom,
            lessThanOrEqualTo(window.bottom - 16),
            reason: '"${copy.last}" cannot be scrolled clear of the footer',
          );
          if (copy != screens.last) {
            await tester.tapByKey(AppKeys.onboardingNext);
            await tester.pumpTimes(4);
          }
        }
        expect(tester.takeException(), isNull);
      });

      // pinned at 40pt flat, the label was cut top and bottom (#704)
      for (final pastWorkouts in [false, true]) {
        final beside = pastWorkouts ? ', beside Log past workout' : '';
        testWidgets('$where, the Start header grows to its label$beside', (tester) async {
          // Profile is laid out on the way to the Workout tab, and at this
          // size its weekly chart's axis labels outgrow their band. That is
          // fl_chart's trouble; anything else reported here is the header's.
          final reported = <FlutterErrorDetails>[];
          final onError = FlutterError.onError;
          FlutterError.onError = reported.add;
          addTearDown(() => FlutterError.onError = onError);

          tester.platformDispatcher.textScaleFactorTestValue = 3.1;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          if (pastWorkouts) {
            SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-pastWorkouts': 'on'});
          }
          await pumpTo(tester, _Screen.workout, locale, phone: phone);
          await tester.pumpTimes();
          FlutterError.onError = onError;
          expect(reported.where((error) => !'$error'.contains('fl_chart')), isEmpty);

          expect(find.byKey(WorkoutDetailKeys.logPastWorkout), pastWorkouts ? findsOneWidget : findsNothing);
          final l = L.of(tester.element(find.byType(Navigator).first));
          final label = find.text(l.startNewWorkout);
          final paragraph = tester.renderObject<RenderParagraph>(label);
          final whole = TextPainter(
            text: paragraph.text,
            textDirection: .ltr,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.constraints.maxWidth);
          addTearDown(whole.dispose);
          expect(paragraph.size.height, greaterThanOrEqualTo(whole.height), reason: 'the label is cut short');
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getMinIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.constraints.maxWidth),
            reason: 'a word of the label is wider than its line',
          );
          expect(paragraph.textScaler.scale(10), greaterThan(10), reason: 'the label still answers the text size');

          final button = tester.getRect(find.byKey(WorkoutDetailKeys.startNewWorkout));
          final header = tester.getRect(_startHeader);
          final text = tester.getRect(label);
          expect(button.top, lessThanOrEqualTo(text.top));
          expect(button.bottom, greaterThanOrEqualTo(text.bottom));
          expect(header.top, lessThanOrEqualTo(button.top));
          expect(header.bottom, greaterThanOrEqualTo(button.bottom));
          // pinned: what it takes, the list under it never gets back
          expect(header.height, lessThanOrEqualTo(phone.height / 4));
        });
      }
    }
  }

  // The logo stripe is one fixed line under the app bar. Scaled a second time
  // by `Text`, "Every beat counts." ran 89px off a 360dp phone at 1.3x (#762).
  // Larger text now grows the mark and the motto together and only while both
  // fit, so neither is clipped and the motto never pays for the mark.
  for (final locale in L.supportedLocales) {
    for (final width in [320.0, 360.0, 390.0, 430.0, 820.0]) {
      testWidgets('under $locale at ${width.round()}dp the logo stripe keeps the mark whole at any text size', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 780) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        // the stripe by itself, hung the way every page hangs it: the pages
        // under it have large-text trouble of their own
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: Scaffold(
              appBar: AppBar(
                bottom: const PreferredSize(preferredSize: Size.fromHeight(56), child: LogoStripe()),
              ),
            ),
          ),
        );

        final markText = find.text(LogoTitle.logotype);
        final motto = find.descendant(of: find.byType(LogoStripe), matching: find.byType(Motto));
        double? sizeOf(Finder text) =>
            text.evaluate().isEmpty ? null : tester.renderObject<RenderParagraph>(text).text.style?.fontSize;
        Finder drawn(Finder within) => find.descendant(of: within, matching: find.byType(RichText));

        for (final bold in [false, true]) {
          tester.platformDispatcher
            ..textScaleFactorTestValue = 1
            ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(boldText: bold);
          await tester.pump();
          final plainMark = sizeOf(markText)!;
          final plainMotto = sizeOf(drawn(motto));
          expect(plainMark, 28);

          for (final scale in [0.85, 1.0, 1.3, 2.0, 3.1]) {
            final at = '${scale}x${bold ? ', bold' : ''}';
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pump();
            expect(tester.takeException(), isNull, reason: at);

            final stripe = tester.getRect(find.byType(LogoStripe));
            expect(stripe.width, width);
            expect(stripe.height, lessThanOrEqualTo(56), reason: '$at: taller than the room every page gives it');

            final mark = tester.renderObject<RenderParagraph>(markText);
            final markRect = tester.getRect(markText);
            expect(mark.size.width, greaterThanOrEqualTo(mark.getMaxIntrinsicWidth(double.infinity)), reason: at);
            expect(sizeOf(markText), greaterThanOrEqualTo(plainMark), reason: '$at: the mark never shrinks');
            expect(markRect.left, greaterThanOrEqualTo(stripe.left), reason: at);
            expect(markRect.right, lessThanOrEqualTo(stripe.right), reason: at);
            expect(markRect.top, greaterThanOrEqualTo(stripe.top), reason: at);
            expect(markRect.bottom, lessThanOrEqualTo(stripe.bottom), reason: at);

            // the motto is part of the mark: English in every language, and
            // there at a larger text size wherever it is at the ordinary one
            switch (plainMotto) {
              case null:
                expect(motto, findsNothing, reason: at);
              case final plain:
                expect(find.descendant(of: motto, matching: find.text('Every beat counts.')), findsOneWidget);
                expect(sizeOf(drawn(motto)), greaterThanOrEqualTo(plain), reason: '$at: the motto gave way');
                expect(plain, greaterThanOrEqualTo(11));
                final mottoRect = tester.getRect(motto);
                expect(mottoRect.left, greaterThanOrEqualTo(markRect.right), reason: at);
                expect(mottoRect.right, lessThanOrEqualTo(stripe.right - 16 + .01), reason: at);
            }
          }
        }
        // a phone shows both halves; only a window under the mark's own
        // width would not
        expect(motto, width >= 360 ? findsOneWidget : anything);
      });
    }
  }

  // At ordinary text nothing moved: the header is the 40pt it always was.
  testWidgets('at 1x the Start header is 40pt', (tester) async {
    await pumpTo(tester, _Screen.workout, const Locale('en'));
    await tester.pumpTimes();
    expect(tester.getSize(_startHeader).height, 40);
    expect(tester.getSize(find.byKey(WorkoutDetailKeys.startNewWorkout)).height, 32);
  });
}
