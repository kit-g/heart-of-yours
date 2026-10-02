import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';
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

  // today and twenty days back: inside both windows, and only the month's
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 7);
  final threeWeeksAgo = DateTime(now.year, now.month, now.day - 20, 7);

  final benchPress = (
    start: today,
    muscles: MuscleTagging.fromJson(
      jsonDecode('{"primary": {"groups": ["chest"]}, "secondary": {"groups": ["arms"]}}'),
    ),
    sets: 4,
  );
  final untagged = (start: today, muscles: MuscleTagging.empty(), sets: 3);
  final raise = (
    start: today,
    muscles: MuscleTagging.fromJson(jsonDecode('{"primary": {"groups": []}, "secondary": {"groups": ["shoulders"]}}')),
    sets: 3,
  );
  final deadlift = (
    start: threeWeeksAgo,
    muscles: MuscleTagging.fromJson(jsonDecode('{"primary": {"groups": ["back"]}}')),
    sets: 5,
  );

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getMuscleSets(any, any, userId: anyNamed('userId')))
        .thenAnswer((_) async => [benchPress, untagged, deadlift, raise]);
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

  /// Settings › Features, a page of its own (#226).
  Future<void> openFeatures(WidgetTester tester) async {
    await tester.tap(find.tooltip('Settings'));
    await tester.pumpTimes();
    final row = find.byKey(AppKeys.features);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpTimes();
  }

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
      // once in the list, once as a heatmap row
      expect(inCard('Chest'), findsNWidgets(2));
      expect(inCard('4'), findsOneWidget);
      expect(inCard('Arms'), findsNWidgets(2));
      expect(inCard('2'), findsOneWidget);
      // the untagged sets are owned up to in the list's help, not under it
      final help = find.descendant(
        of: byKey(AppKeys.muscleMapCard),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip && (widget.message?.contains('3 sets from exercises without muscle data') ?? false),
        ),
      );
      expect(help, findsOneWidget);
      expect(find.textContaining('without muscle data'), findsNothing);
    });

    testWidgets('no earns one notice, and closing it leaves nothing behind', (tester) async {
      await pumpProfile(tester);

      await tester.ensureVisible(byKey(AppKeys.muscleMapDecline));
      await tester.tapByKey(AppKeys.muscleMapDecline);
      await tester.pumpTimes(2);

      expect(byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
      expect(find.text('You can always turn this on in Settings › Features.', skipOffstage: false), findsOneWidget);

      await tester.tap(find.tooltip('Close'));
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

  testWidgets('one read covers both windows and the eight weeks; the switcher only filters', (tester) async {
    await pumpProfile(tester, answer: 'on');
    // calendar days, not a Duration: a DST week is not 7 × 24h
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    Finder inCard(String text) => find.descendant(of: byKey(AppKeys.muscleMapCard), matching: find.text(text));
    Finder rowOf(String group) => find.ancestor(of: inCard(group), matching: find.byType(MergeSemantics)).first;

    final captured = verify(db.getMuscleSets(captureAny, captureAny, userId: anyNamed('userId'))).captured;
    // startup builds the aggregation more than once, and each new one
    // invalidates the cache; the last read is the one on screen
    final [from as DateTime, to as DateTime] = captured.sublist(captured.length - 2);
    expect(to, day(1));
    // eight calendar weeks back reaches further than thirty days
    expect(from.isBefore(day(-29)), isTrue);
    expect(from.weekday, DateTime.monday);

    // this week: back trained three weeks ago keeps its row, at zero
    await tester.ensureVisible(byKey(AppKeys.muscleMapCard));
    expect(find.descendant(of: rowOf('Back'), matching: find.text('0')), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await tester.pumpTimes(5);
    expect(find.descendant(of: rowOf('Back'), matching: find.text('5')), findsOneWidget);

    await tester.tap(find.text('7 days'));
    await tester.pumpTimes(5);
    expect(find.descendant(of: rowOf('Back'), matching: find.text('0')), findsOneWidget);
    // flipping filtered what was read; it read nothing new
    verifyNever(db.getMuscleSets(any, any, userId: anyNamed('userId')));
  });

  testWidgets('the heatmap: thirteen weeks by default, told in words, with empty weeks marked', (tester) async {
    await pumpProfile(tester, answer: 'on');
    final heatmap = byKey(AppKeys.muscleMapHeatmap);
    await tester.ensureVisible(heatmap);

    expect(find.descendant(of: heatmap, matching: find.text('Sets per week')), findsOneWidget);
    for (final group in ['Chest', 'Arms', 'Back', 'Shoulders']) {
      expect(find.descendant(of: heatmap, matching: find.text(group)), findsOneWidget);
    }

    final handle = tester.ensureSemantics();
    // thirteen weeks, oldest first: chest's four sets are this week's, the last
    expect(find.bySemanticsLabel(RegExp(r'^Chest, sets per week, oldest first: (0, ){12}4$')), findsOneWidget);
    handle.dispose();

    // a tap on a cell reads it out under the grid, and stays there
    final chestRow = find
        .ancestor(
          of: find.descendant(of: heatmap, matching: find.text('Chest')),
          matching: find.byType(GestureDetector),
        )
        .first;
    final row = tester.getRect(chestRow);
    final thisWeek = DateFormat.Md('en').format(getMonday(now));
    final caption = byKey(AppKeys.muscleMapCellCaption);

    await tester.tapAt(Offset(row.right - 4, row.center.dy));
    await tester.pumpTimes(2);
    expect(tester.widget<Text>(caption).data, 'Week of $thisWeek · Chest: 4 sets');
    await tester.pump(const Duration(seconds: 5));
    expect(caption, findsOneWidget);

    // the same cell again clears it, and the span comes back
    await tester.tapAt(Offset(row.right - 4, row.center.dy));
    await tester.pumpTimes(2);
    expect(caption, findsNothing);

    // dragging along the row moves through the weeks: the oldest is empty
    await tester.dragFrom(Offset(row.right - 4, row.center.dy), Offset(-(row.width - 100), 0));
    await tester.pumpTimes(2);
    expect(tester.widget<Text>(caption).data, endsWith('Chest: no sets'));
  });

  testWidgets('1Y reads a year once, on demand, and counts it by month', (tester) async {
    await pumpProfile(tester, answer: 'on');
    final heatmap = byKey(AppKeys.muscleMapHeatmap);
    await tester.ensureVisible(heatmap);
    clearInteractions(db);

    await tester.tap(find.descendant(of: heatmap, matching: find.text('1Y')));
    await tester.pumpTimes(3);

    final [from as DateTime, to as DateTime] = verify(
      db.getMuscleSets(captureAny, captureAny, userId: anyNamed('userId')),
    ).captured;
    expect(from, DateTime(now.year, now.month - 11));
    expect(to, DateTime(now.year, now.month, now.day + 1));
    expect(find.descendant(of: heatmap, matching: find.text('Sets per month')), findsOneWidget);

    // back and forth: the year is kept, not read again
    await tester.tap(find.descendant(of: heatmap, matching: find.text('3M')));
    await tester.pumpTimes(2);
    await tester.tap(find.descendant(of: heatmap, matching: find.text('1Y')));
    await tester.pumpTimes(2);
    verifyNever(db.getMuscleSets(any, any, userId: anyNamed('userId')));
  });

  testWidgets('each box explains itself behind a "?" in its corner, opened by a tap', (tester) async {
    await pumpProfile(tester, answer: 'on');
    final marks = find.descendant(of: byKey(AppKeys.muscleMapCard), matching: find.byIcon(Icons.help_outline_rounded));
    expect(marks, findsNWidgets(3));

    await tester.ensureVisible(marks.at(1));
    await tester.tap(marks.at(1));
    await tester.pumpTimes(3);
    expect(find.textContaining('one set of bench press adds 1 to Chest and ½ to Arms'), findsOneWidget);
    expect(find.textContaining('3 sets from exercises without muscle data'), findsOneWidget);

    // the whole 48pt square answers, not only the glyph
    final square = find.ancestor(of: marks.first, matching: find.byType(SizedBox)).first;
    expect(tester.getSize(square), const Size.square(48));
  });

  testWidgets('tapping a muscle names its group and that group\'s sets for the window', (tester) async {
    await pumpProfile(tester, answer: 'on');
    await tester.ensureVisible(byKey(AppKeys.muscleMapCard));
    // hit-testing the painted figure needs its SVG off the asset bundle, which
    // fake time never loads; the callback is what a hit resolves to
    final atlas = tester.widget<BodyAtlasView<MuscleInfo>>(find.byType(BodyAtlasView<MuscleInfo>).first);
    MuscleInfo muscleOf(MuscleGroup group) => MuscleCatalog.all.firstWhere((muscle) => muscle.group == group);

    atlas.onTapElement!(muscleOf(MuscleGroup.chest));
    await tester.pumpTimes(3);
    expect(find.text('Chest: 4 sets'), findsOneWidget);

    // a secondary muscle's half sets, and a group idle this week
    atlas.onTapElement!(muscleOf(MuscleGroup.shoulders));
    await tester.pumpTimes(3);
    expect(find.text('Shoulders: 1.5 sets'), findsOneWidget);
    atlas.onTapElement!(muscleOf(MuscleGroup.back));
    await tester.pumpTimes(3);
    expect(find.text('Back: no sets'), findsOneWidget);

    // and it fades on its own
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpTimes(3);
    expect(byKey(AppKeys.muscleMapFigureTip), findsNothing);
  });

  // The offer's two buttons are the house's 32pt density (`primaryButtonMinHeight`),
  // and the card's switcher is the house `SettingSwitcher`; both are named in the
  // a11y matrix's skip reason. The notice's close is the rest.
  testWidgets('the notice clears the tap target the matrix skips for the nav bar', (tester) async {
    final preferences = await pumpProfile(tester);
    await tester.pumpTimes();

    preferences.answerOffer(Feature.muscleMap, yes: false);
    await tester.pumpTimes(2);
    expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.close_rounded)).height, greaterThanOrEqualTo(48));
  });

  group('options (#213)', () {
    final figures = find.byType(BodyAtlasView<MuscleInfo>, skipOffstage: false);
    final breakdown = find.text('Sets per group', skipOffstage: false);
    final switcher = find.text('7 days', skipOffstage: false);

    testWidgets('each part can be left out, and the card closes up around the rest', (tester) async {
      final preferences = await pumpProfile(tester, answer: 'on');
      expect(figures, findsWidgets);
      expect(breakdown, findsOneWidget);
      expect(byKey(AppKeys.muscleMapHeatmap), findsOneWidget);

      preferences.setOption(.muscleMapFigures, on: false);
      await tester.pumpTimes(2);
      expect(figures, findsNothing);
      expect(breakdown, findsOneWidget);

      preferences.setOption(.muscleMapBreakdown, on: false);
      await tester.pumpTimes(2);
      expect(breakdown, findsNothing);
      expect(switcher, findsNothing, reason: 'the window switcher drives only the figures and the list');
      expect(byKey(AppKeys.muscleMapHeatmap), findsOneWidget);

      preferences.setOption(.muscleMapHeatmap, on: false);
      await tester.pumpTimes(2);
      expectNothingOfTheFeature();
    });

    testWidgets('they unfold under the switch while it is on, and the last one turns it off', (tester) async {
      final preferences = await pumpProfile(tester, answer: 'off');
      await openFeatures(tester);

      final toggle = byKey(const ValueKey('feature-muscleMap'));
      final option = byKey(const ValueKey('feature-muscleMap-heatmap'));
      await tester.ensureVisible(toggle);
      expect(option, findsNothing, reason: 'folded away while off');

      await tester.tap(toggle);
      await tester.pumpTimes(2);
      expect(option, findsOneWidget);
      bool? expanded() => tester
          .widget<Semantics>(find.ancestor(of: toggle, matching: find.byType(Semantics)).first)
          .properties
          .expanded;
      expect(expanded(), isTrue, reason: 'a switch that unfolds says it is expanded');

      for (final value in ['figures', 'breakdown']) {
        await tester.tap(byKey(ValueKey('feature-muscleMap-$value')));
        await tester.pumpTimes();
      }
      expect(preferences.isOn(Feature.muscleMap), isTrue, reason: 'one part is still kept');

      await tester.tap(option);
      await tester.pumpTimes(2);
      expect(preferences.isOn(Feature.muscleMap), isFalse);
      expect(option, findsNothing);

      await tester.tap(toggle);
      await tester.pumpTimes(2);
      expect(Feature.muscleMap.options.every(preferences.isOptionOn), isTrue, reason: 'on is on in full');
    });
  });

  testWidgets('Settings › Features flips it, and says it is on', (tester) async {
    final preferences = await pumpProfile(tester, answer: 'off');

    await openFeatures(tester);

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
