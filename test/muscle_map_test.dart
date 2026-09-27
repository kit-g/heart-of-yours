import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// The muscle map on the profile (#136), the first opt-in feature (#138).
///
/// Through the real app rather than the section alone: "off means never built"
/// is a claim about the whole profile, and only the whole profile can show
/// that nothing of the feature is left on it.
void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  const feature = 'feature-muscleMap';

  final benchPress = (
    muscles: MuscleTagging.fromJson(
      jsonDecode('{"primary": {"groups": ["chest"]}, "secondary": {"groups": ["arms"]}}'),
    ),
    sets: 4,
  );
  final untagged = (muscles: MuscleTagging.empty(), sets: 3);

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getMuscleSets(any, any, userId: anyNamed('userId'))).thenAnswer((_) async => [benchPress, untagged]);
  });

  /// A profile with [history] — some finished workouts, or none — on a device
  /// whose answer about the muscle map is [answer] (absent: never asked).
  Future<Preferences> pumpProfile(WidgetTester tester, {bool history = true, String? answer}) async {
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      feature: ?answer,
    });
    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => history ? WorkoutAggregation.dummy() : WorkoutAggregation.empty());

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();
    return Preferences.of(tester.element(find.byType(MaterialApp)));
  }

  Finder byKey(Key key) => find.byKey(key, skipOffstage: false);

  void expectNothingOfTheFeature() {
    expect(byKey(AppKeys.muscleMapOffer), findsNothing);
    expect(byKey(AppKeys.featureDeclinedNotice), findsNothing);
    expect(byKey(AppKeys.muscleMapCard), findsNothing);
    expect(find.text('Muscle map', skipOffstage: false), findsNothing);
  }

  group('the offer', () {
    testWidgets('is made once there is history, and spends itself by being shown', (tester) async {
      final preferences = await pumpProfile(tester);

      expect(byKey(AppKeys.muscleMapOffer), findsOneWidget);
      expect(preferences.featureAnswer(Feature.muscleMap), FeatureAnswer.pending);
      // shown, not answered: the feature is still off
      expect(byKey(AppKeys.muscleMapCard), findsNothing);
    });

    testWidgets('is not made to a user with nothing to map', (tester) async {
      final preferences = await pumpProfile(tester, history: false);

      expectNothingOfTheFeature();
      expect(preferences.featureAnswer(Feature.muscleMap), FeatureAnswer.unasked);
    });

    testWidgets('yes shows the map, counted and listed', (tester) async {
      await pumpProfile(tester);

      await tester.ensureVisible(byKey(AppKeys.muscleMapAccept));
      await tester.tapByKey(AppKeys.muscleMapAccept);
      await tester.pumpTimes();

      expect(byKey(AppKeys.muscleMapOffer), findsNothing);
      expect(byKey(AppKeys.muscleMapCard), findsOneWidget);
      // chest primary (4), arms secondary (4 × ½), and the untagged sets owned up to
      Finder inCard(String text) => find.descendant(of: byKey(AppKeys.muscleMapCard), matching: find.text(text));
      expect(inCard('Chest'), findsOneWidget);
      expect(inCard('4'), findsOneWidget);
      expect(inCard('Arms'), findsOneWidget);
      expect(inCard('2'), findsOneWidget);
      expect(
        find.descendant(
          of: byKey(AppKeys.muscleMapCard),
          matching: find.textContaining('3 sets from exercises without muscle data'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no earns one notice, and closing it leaves nothing behind', (tester) async {
      await pumpProfile(tester);

      await tester.ensureVisible(byKey(AppKeys.muscleMapDecline));
      await tester.tapByKey(AppKeys.muscleMapDecline);
      await tester.pumpTimes(2);

      expect(byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
      expect(find.text('You can always turn this on in Settings.', skipOffstage: false), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpTimes(2);

      expectNothingOfTheFeature();
    });
  });

  group('off means never built', () {
    for (final answer in ['off', 'pending']) {
      testWidgets('a device that answered "$answer" sees no trace of the feature, and is not asked again', (
        tester,
      ) async {
        await pumpProfile(tester, answer: answer);

        expectNothingOfTheFeature();
        verifyNever(db.getMuscleSets(any, any, userId: anyNamed('userId')));
      });
    }

    testWidgets('the switch is live both ways: the card comes and goes without a restart', (tester) async {
      final preferences = await pumpProfile(tester, answer: 'on');
      expect(byKey(AppKeys.muscleMapCard), findsOneWidget);

      preferences.setFeature(Feature.muscleMap, on: false);
      await tester.pumpTimes(2);
      expectNothingOfTheFeature();

      preferences.setFeature(Feature.muscleMap, on: true);
      await tester.pumpTimes(2);
      expect(byKey(AppKeys.muscleMapCard), findsOneWidget);
    });
  });

  testWidgets('the window toggle reads 30 days on demand, and each window once', (tester) async {
    await pumpProfile(tester, answer: 'on');
    // calendar days, not a Duration: a DST week is not 7 × 24h
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

    final first = verify(db.getMuscleSets(captureAny, captureAny, userId: anyNamed('userId'))).captured;
    // startup builds the aggregation more than once, and each new one
    // invalidates the cache; the window read is what matters
    expect(first.sublist(first.length - 2), [day(-6), day(1)]);

    await tester.ensureVisible(find.text('30 days'));
    await tester.tap(find.text('30 days'));
    await tester.pumpTimes(2);
    final second = verify(db.getMuscleSets(captureAny, captureAny, userId: anyNamed('userId'))).captured;
    expect(second, [day(-29), day(1)]);

    // back to 7: cached, not read again
    await tester.tap(find.text('7 days'));
    await tester.pumpTimes(2);
    verifyNever(db.getMuscleSets(any, any, userId: anyNamed('userId')));
  });

  // The offer's two buttons are the house's 32pt density (`primaryButtonMinHeight`)
  // and are named in the a11y matrix's skip reason; these are the rest.
  testWidgets('the notice and the card clear the tap target the matrix skips for the nav bar', (tester) async {
    final preferences = await pumpProfile(tester);
    await tester.pumpTimes();

    preferences.answerOffer(Feature.muscleMap, yes: false);
    await tester.pumpTimes(2);
    expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.close_rounded)).height, greaterThanOrEqualTo(48));

    preferences.setFeature(Feature.muscleMap, on: true);
    await tester.pumpTimes();
    for (final segment in find.byType(SegmentedButton<int>).evaluate()) {
      expect(segment.size!.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('Settings › Features flips it, and says it is on', (tester) async {
    final preferences = await pumpProfile(tester, answer: 'off');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpTimes();

    final toggle = byKey(const ValueKey('feature-muscleMap'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpTimes(2);
    expect(preferences.isOn(Feature.muscleMap), isTrue);

    await tester.tap(toggle);
    await tester.pumpTimes(2);
    expect(preferences.isOn(Feature.muscleMap), isFalse);
  });
}
