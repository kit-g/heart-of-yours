import 'dart:async';

import 'package:feedback/feedback.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/health/section.dart';
import 'package:heart/presentation/widgets/redacted.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';

import 'support/health_fakes.dart';

/// The health section of the profile dashboard.
///
/// Pumped on its own rather than through the app harness: it needs [Health],
/// [Preferences] and the localizations, and booting the whole app would drag in
/// Firebase, the router and the database for a widget that reads two notifiers.
void main() {
  late FakeHealthDevice device;
  late FakeHealthStore store;
  late Health health;
  late Preferences preferences;

  const userId = 'user-123';

  Future<void> boot() async {
    preferences = await freshPreferences();
    device = FakeHealthDevice();
    store = FakeHealthStore();
    health = Health(device: device, local: store)..userId = userId;
  }

  setUp(boot);

  Future<void> pumpSection(WidgetTester tester, {bool feedback = false}) async {
    final section = MultiProvider(
      providers: [
        ChangeNotifierProvider<Health>.value(value: health),
        ChangeNotifierProvider<Preferences>.value(value: preferences),
        Provider<AppConfig>.value(value: AppConfig.test(allowsFeedbackFeature: feedback)),
      ],
      child: const MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(slivers: [HealthSection()]),
        ),
      ),
    );

    await tester.pumpWidget(feedback ? BetterFeedback(child: section) : section);
    await tester.pump();
  }

  group('when there is nothing to show', () {
    testWidgets('renders nothing at all on a platform with no health store', (tester) async {
      device.supported = false;
      await health.init();
      await pumpSection(tester);

      // Absent, not empty. An empty section invites the user to fix something
      // that cannot be fixed on this device.
      expect(find.text('Health'), findsNothing);
      expect(find.text('Health data'), findsNothing);
    });

    testWidgets('offers to read health data before it has ever asked', (tester) async {
      await health.init();
      await pumpSection(tester);

      // Header, not an in-card title — the same shape the goals card next to
      // it uses, and it puts the device-only promise on screen immediately.
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Show my health data'), findsOneWidget);
      expect(find.textContaining('on this device'), findsOneWidget);
    });

    testWidgets('the offer stays gone once waved away', (tester) async {
      await health.init();
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(find.text('Show my health data'), findsNothing);
      expect(find.text('Health'), findsNothing, reason: 'the whole section goes, header and all');

      // And it does not come back on the next launch — the whole point of
      // dismissing it.
      await pumpSection(tester);
      expect(find.text('Show my health data'), findsNothing);
    });

    // Once the question has been put, the section stops asking it. The header
    // is all that survives, greyed, so the feature is still visibly there —
    // but nothing is left to nag with or to press.
    testWidgets('goes quiet once the sheet has been answered and nothing came back', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pumpSection(tester);

      expect(find.text('Health'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      final context = tester.element(find.text('Health'));
      final theme = Theme.of(context);

      expect(tester.widget<Text>(find.text('Health')).style?.color, theme.disabledColor);

      // The header greys because the section is dormant. The button beside it
      // does not: it is live, it is the only way back, and a button that looks
      // disabled is one nobody presses.
      final button = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(Icons.info_outline_rounded), matching: find.byType(IconButton)),
      );
      expect(button.onPressed, isNotNull);
      expect(button.color, isNot(theme.disabledColor));
      expect(button.color, theme.colorScheme.onSurfaceVariant);
    });

    // Explaining is the smaller half. Knowing the permission lives in another
    // app does not get anybody there, which is why this is a dialog with a
    // button and not a tooltip.
    testWidgets('and explains it, then does the navigating', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('isn’t reading any health data'), findsOneWidget);
      expect(find.textContaining('Heart read'), findsOneWidget);
      // The switch that is kept away from the permission list, and without
      // which every read stops 30 days back however far the chart zooms out.
      expect(find.textContaining('past data'), findsOneWidget);

      // The two cases this covers — declined, and granted but no watch — are
      // indistinguishable to us, so none of these may appear.
      expect(find.textContaining('denied'), findsNothing);
      expect(find.textContaining('Denied'), findsNothing);
      expect(find.textContaining('Retry'), findsNothing);
      expect(find.textContaining('Connected'), findsNothing);

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(device.log, contains('openPermissions'));
      expect(find.textContaining('isn’t reading any health data'), findsNothing, reason: 'the dialog goes too');
    });

    testWidgets('and takes nobody anywhere they did not ask to go', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('isn’t reading any health data'), findsNothing);
      expect(device.log, isNot(contains('openPermissions')));
    });

    testWidgets('names the Health app when that is where the permission is', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('In the Health app'), findsOneWidget);
      expect(find.text('Open the Health app'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // What a user sees in the seconds after coming back from granting access.
    // A header that looks identical whether or not a read is running is the
    // same "nothing happened" the resume sync exists to stop, only shorter.
    testWidgets('shows that it is looking while it reads', (tester) async {
      await preferences.setHealthAsked(userId);
      device.gate = Completer<void>();

      final reading = health.init();
      await pumpSection(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);

      device.gate!.complete();
      await reading;
      await pumpSection(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('with data', () {
    setUp(() {
      store.daily
        ..[HealthMetric.restingHeartRate] = [
          (day: DateTime(2026, 7, 30), value: 62),
          (day: DateTime(2026, 7, 31), value: 61),
        ]
        ..[HealthMetric.sleepAsleep] = [
          (day: DateTime(2026, 7, 30), value: 430),
          (day: DateTime(2026, 7, 31), value: 451),
        ]
        ..[HealthMetric.steps] = [
          (day: DateTime(2026, 7, 30), value: 7000),
          (day: DateTime(2026, 7, 31), value: 8432),
        ];
    });

    testWidgets('shows a card per metric with its latest value', (tester) async {
      await health.init();
      await pumpSection(tester);

      expect(find.text('Health'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);

      expect(find.text('Resting heart rate'), findsOneWidget);
      expect(find.text('61'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);

      // Nothing here grades the user.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('goal'), findsNothing);
      expect(find.textContaining('Sync'), findsNothing);
    });

    // The sparkline is a shape, not a reading — no axes, no scale, bucketed
    // down to 24 points. Tapping is where the numbers are.
    group('the detail chart', () {
      testWidgets('opens on the card, on the app’s own chart', (tester) async {
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Resting heart rate'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryChart), findsOneWidget);
        expect(find.text('Resting heart rate'), findsWidgets, reason: 'the dialog is titled');
        // The reading the card was showing, unchanged by opening it.
        expect(find.text('61'), findsWidgets);
        // A bare date beside the number read as part of the measurement.
        expect(find.textContaining('Latest reading'), findsOneWidget);
      });

      testWidgets('closes again', (tester) async {
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryChart), findsNothing);
      });

      // A lone dot is not a trend, and the sparkline is already blank for the
      // same reason. An inert card beats one that opens onto nothing.
      testWidgets('is not offered for a single reading', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [(day: DateTime(2026, 7, 31), value: 8432)];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryChart), findsNothing);
      });

      // The window is the control; the scale follows it. A year of daily
      // readings drawn faithfully is 365 points across ~240pt of plot — more
      // data, less information, which is the failure this view exists to fix.
      testWidgets('opens on a quarter, day by day, with nothing to disclose', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [
            for (var i = 0; i < 364; i++) (day: DateTime(2025, 8, 17).add(Duration(days: i)), value: 8000 + i * 2),
          ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();

        // ~92 days of the 364 held, one point each.
        expect(tester.widget<HistoryChart>(find.byType(HistoryChart)).series.length, greaterThan(85));
        expect(find.text('Weekly average'), findsNothing, reason: 'a daily point is a reading, not a summary');
      });

      testWidgets('coarsens as the window widens, and says which scale it is on', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [
            for (var i = 0; i < 364; i++) (day: DateTime(2025, 8, 17).add(Duration(days: i)), value: 8000 + i * 2),
          ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();

        // 1Y is not offered here: a year and "all" are the same window for a
        // 364-day series, and two chips doing one thing is a lie about choice.
        expect(find.text('1Y'), findsNothing);

        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        expect(tester.widget<HistoryChart>(find.byType(HistoryChart)).series.length, 53);
        expect(find.text('Weekly average'), findsOneWidget);
      });

      testWidgets('goes monthly once the window is measured in years', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [
            for (var i = 0; i < 1095; i++)
              (day: DateTime(2023, 8, 17).add(Duration(days: i)), value: 8000 + i.toDouble()),
          ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        expect(tester.widget<HistoryChart>(find.byType(HistoryChart)).series.length, 37);
        expect(find.text('Monthly average'), findsOneWidget);

        // Three years of month names alone reads "Aug — Feb — Aug — Feb — Aug",
        // which is three different Augusts wearing one label.
        expect(find.textContaining("'24"), findsWidgets);
      });

      // A control offering a year to someone with three weeks of history does
      // nothing when tapped.
      testWidgets('offers only the windows the history can fill', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [
            for (var i = 0; i < 40; i++) (day: DateTime(2026, 7, 7).add(Duration(days: i)), value: 8000 + i.toDouble()),
          ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();

        expect(find.text('1M'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('3M'), findsNothing);
        expect(find.text('1Y'), findsNothing);
      });

      // The caption only applies at the coarse grains, and letting it come and
      // go changed the column's height — so the dialog resized under the finger
      // that had just tapped a chip.
      testWidgets('does not change height when the grain does', (tester) async {
        store.daily
          ..clear()
          ..[HealthMetric.steps] = [
            for (var i = 0; i < 1095; i++)
              (day: DateTime(2023, 8, 17).add(Duration(days: i)), value: 8000 + i.toDouble()),
          ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Steps'));
        await tester.pumpAndSettle();

        final daily = tester.getSize(find.byType(TimelineChart));
        expect(find.text('Monthly average'), findsNothing, reason: 'opens on the quarter');

        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        expect(find.text('Monthly average'), findsOneWidget);
        expect(tester.getSize(find.byType(TimelineChart)), daily);
      });

      testWidgets('plots body mass in the unit the card shows', (tester) async {
        await preferences.setWeightUnit(MeasurementUnit.imperial);
        store.daily[HealthMetric.bodyMass] = [
          (day: DateTime(2026, 7, 30), value: 80),
          (day: DateTime(2026, 7, 31), value: 81),
        ];
        await health.init();
        await pumpSection(tester);

        await tester.tap(find.text('Body mass'));
        await tester.pumpAndSettle();

        // 81 kg is 178.6 lbs. A chart plotting the stored kilograms under a
        // card reading pounds is the bug this guards.
        expect(find.textContaining('178.6'), findsWidgets);
        expect(find.textContaining('81 '), findsNothing);
      });
    });

    // An InkWell renders as its child and gets no button semantics for free, so
    // a screen reader would read three unrelated fragments and never say the
    // card opens anything. `docs/a11y.md`.
    testWidgets('the card announces itself as one control', (tester) async {
      await health.init();
      await pumpSection(tester);

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp('Resting heart rate, 61 bpm')),
        findsOneWidget,
      );
      handle.dispose();
    });

    // A screen reader cannot perceive a painted line, so it is given the same
    // thing as a sentence — summary level, never per point.
    testWidgets('the detail chart is a sentence, not a line', (tester) async {
      await health.init();
      await pumpSection(tester);

      await tester.tap(find.text('Resting heart rate'));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Resting heart rate from .* Trend:')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reads sleep as hours and minutes, not as 451', (tester) async {
      await health.init();
      await pumpSection(tester);

      expect(find.text('7h 31m'), findsOneWidget);
      expect(find.text('451'), findsNothing);
    });

    testWidgets('groups step counts', (tester) async {
      await health.init();
      await pumpSection(tester);

      expect(find.text('8,432'), findsOneWidget);
    });

    // Body mass is weighed when someone remembers the scale, so a fixed
    // three-month window can hold one reading — and one reading draws nothing.
    testWidgets('widens the window for a metric recorded every few weeks', (tester) async {
      store.daily
        ..clear()
        ..[HealthMetric.bodyMass] = [
          for (var i = 0; i < 12; i++) (day: DateTime(2025, 9, 1).add(Duration(days: i * 28)), value: 82 - i * .3),
        ];
      await health.init();
      await pumpSection(tester);

      // A quarter of that is three weigh-ins; the chart has to reach further or
      // there is no line on either surface.
      final spots = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first.spots;
      expect(spots.length, greaterThan(3));
    });

    // Reserving the plot's share of the width for a reading with no trend
    // behind it reads as a chart that failed, whether the space is left empty
    // or filled with a lone mark. The reading gets the whole card instead.
    testWidgets('gives a lone reading the whole card rather than a failed plot', (tester) async {
      store.daily
        ..clear()
        ..[HealthMetric.bodyMass] = [(day: DateTime(2026, 8, 15), value: 81.7)];
      await health.init();
      await pumpSection(tester);

      expect(find.text('Body mass'), findsOneWidget);
      expect(find.text('81.7'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing, reason: 'one point is not a line');

      final row = tester.widget<Flex>(
        find.ancestor(of: find.text('Body mass'), matching: find.byType(Row)).last,
      );
      expect(row.children, hasLength(1), reason: 'no space held back for a plot that cannot exist');
    });

    // The mirror reaches as far back as the platform does. A thumbnail drawing
    // three years beside a detail opening on three months cannot agree about
    // the shape of anything.
    testWidgets('the sparkline draws the window its detail opens on, not the whole mirror', (tester) async {
      store.daily
        ..clear()
        ..[HealthMetric.steps] = [
          for (var i = 0; i < 1095; i++)
            (day: DateTime(2023, 8, 17).add(Duration(days: i)), value: 8000 + i.toDouble()),
        ];
      await health.init();
      await pumpSection(tester);

      // Three years of a rising series bucketed whole would start near 8000;
      // the last quarter of it starts near the end.
      final spots = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first.spots;
      expect(spots.first.y, greaterThan(9000));
    });

    // Ninety daily readings across the ~180pt a sparkline gets is half a point
    // each, and health data is spiky day to day. Past a limit the line stops
    // being a trend and becomes a comb, so it is averaged into buckets.
    testWidgets('a long series is thinned out; a short one is left alone', (tester) async {
      store.daily[HealthMetric.restingHeartRate] = [
        for (var i = 0; i < 90; i++) (day: DateTime(2026, 5, 1).add(Duration(days: i)), value: 60 + (i % 5).toDouble()),
      ];
      await health.init();
      await pumpSection(tester);

      expect(_spots(tester), lessThanOrEqualTo(24));

      store.daily[HealthMetric.restingHeartRate] = [
        for (var i = 0; i < 9; i++) (day: DateTime(2026, 7, 1).add(Duration(days: i)), value: 60 + i.toDouble()),
      ];
      await health.init();
      await pumpSection(tester);

      expect(_spots(tester), 9, reason: 'nothing to gain from bucketing a series that already fits');
    });

    testWidgets('the big number stays the real latest reading, not a bucket average', (tester) async {
      store.daily[HealthMetric.restingHeartRate] = [
        for (var i = 0; i < 90; i++) (day: DateTime(2026, 5, 1).add(Duration(days: i)), value: 70),
        (day: DateTime(2026, 8, 1), value: 51),
      ];
      await health.init();
      await pumpSection(tester);

      expect(find.text('51'), findsOneWidget);
    });

    testWidgets('converts body mass to the chosen unit like every other weight', (tester) async {
      store.daily[HealthMetric.bodyMass] = [(day: DateTime(2026, 7, 31), value: 80)];

      await preferences.setWeightUnit(MeasurementUnit.metric);
      await health.init();
      await pumpSection(tester);

      expect(find.text('80'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);

      await preferences.setWeightUnit(MeasurementUnit.imperial);
      await tester.pump();

      expect(find.text('kg'), findsNothing);
      expect(find.text('lbs'), findsOneWidget);
      expect(find.text('80'), findsNothing);
    });
  });

  group('screenshot capture', () {
    testWidgets('hides the value while the bug reporter is capturing', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppConfig>.value(value: AppConfig.test(allowsFeedbackFeature: true)),
          ],
          child: const BetterFeedback(
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: RedactedInCapture(child: Text('61'))),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final value = find.text('61');
      expect(value, findsOneWidget);
      expect(_isHidden(tester, value), isFalse);

      BetterFeedback.of(tester.element(value)).show((_) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Still laid out — so nothing around it shifts — but invisible, so it
      // cannot end up in the uploaded PNG.
      expect(value, findsOneWidget);
      expect(_isHidden(tester, value), isTrue);
    });

    testWidgets('leaves the value alone when the reporter is not even built', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppConfig>.value(value: AppConfig.test(allowsFeedbackFeature: false)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: RedactedInCapture(child: Text('61'))),
            ),
          ),
        ),
      );
      await tester.pump();

      // No `BetterFeedback` above it, so `BetterFeedback.of` would throw. There
      // is also no screenshot to leak into.
      expect(find.text('61'), findsOneWidget);
    });
  });
}

/// Whether anything above [finder] has painted it out.
///
/// Any ancestor rather than the nearest one: `BetterFeedback` keeps its own
/// fully-opaque [Opacity] in the tree, so "the closest one" is not the
/// redaction's.
bool _isHidden(WidgetTester tester, Finder finder) {
  return tester
      .widgetList<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity)))
      .any((each) => each.opacity == 0);
}

/// How many points the first sparkline actually draws.
int _spots(WidgetTester tester) {
  final chart = tester.widgetList<LineChart>(find.byType(LineChart)).first;
  return chart.data.lineBarsData.first.spots.length;
}
