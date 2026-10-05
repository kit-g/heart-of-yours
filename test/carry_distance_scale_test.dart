import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/chart_dimension.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// A carry's distance on charts and goals reads in metres or yards (#270).
///
/// Distances are stored in kilometres for every category, and the set row
/// already shows a carry in m/yd. The chart and the goal target used the run
/// scale: a 30 m Farmer's Walk plotted as 0.03 km.
void main() {
  Future<Preferences> settingsFor(MeasurementUnit unit) async {
    SharedPreferences.setMockInitialValues({'distanceUnit': unit.name});
    final preferences = Preferences();
    await preferences.init();
    return preferences;
  }

  const ChartPreferenceType distance = .cardioDistance;

  group('the chart', () {
    test('plots a carry in metres for a metric user', () async {
      final settings = await settingsFor(.metric);

      expect(distance.converter(settings, category: .weightedDistance)(0.03), closeTo(30, 1e-9));
    });

    test('plots a carry in yards for an imperial user', () async {
      final settings = await settingsFor(.imperial);

      // 30 yd is 27.432 m
      expect(distance.converter(settings, category: .weightedDistance)(0.027432), closeTo(30, 1e-9));
    });

    test("follows the exercise's own unit over the user's", () async {
      final settings = await settingsFor(.metric);

      final convert = distance.converter(settings, unit: .imperial, category: .weightedDistance);

      expect(convert(0.027432), closeTo(30, 1e-9));
    });

    test('keeps a run in kilometres', () async {
      final settings = await settingsFor(.metric);

      expect(distance.converter(settings, category: .cardio)(5), 5);
      expect(distance.converter(settings)(5), 5);
    });

    test('leaves the weight dimensions of a carry alone', () async {
      final settings = await settingsFor(.metric);

      expect(ChartPreferenceType.topSetWeight.converter(settings, category: .weightedDistance)(40), 40);
    });
  });

  group('a goal target', () {
    test('typed in metres on a carry is stored in kilometres', () async {
      final settings = await settingsFor(.metric);

      expect(distance.storedValue(settings, 50, category: .weightedDistance), closeTo(0.05, 1e-12));
    });

    test('typed in yards round-trips to the same yards', () async {
      final settings = await settingsFor(.imperial);

      final stored = distance.storedValue(settings, 50, category: .weightedDistance);

      expect(distance.converter(settings, category: .weightedDistance)(stored), closeTo(50, 1e-9));
    });

    test('on a run is still typed in kilometres', () async {
      final settings = await settingsFor(.metric);

      expect(distance.storedValue(settings, 5, category: .cardio), 5);
    });
  });

  group('the words', () {
    Future<(String?, String)> labelsFor(WidgetTester tester, Preferences settings, ChartScale scale) async {
      late String? label;
      late String status;
      final goal = Goal(
        id: 'goal-1',
        metric: .cardioDistance,
        exerciseId: 'farmers-walk',
        stages: [GoalStage(id: 's0', target: 0.05)],
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Builder(
            builder: (context) {
              final (:unit, :category) = scale;
              label = distance.unitLabel(context, settings, unit: unit, category: category);
              status = goalStatus(context, goal, settings: settings, scale: scale, current: 0.03);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return (label, status);
    }

    testWidgets('a carry reads in metres', (tester) async {
      final settings = await settingsFor(.metric);

      final (unit, status) = await labelsFor(tester, settings, (unit: null, category: .weightedDistance));

      expect(unit, 'm');
      expect(status, '30 / 50 m');
    });

    testWidgets('a carry reads in yards', (tester) async {
      final settings = await settingsFor(.imperial);

      final (unit, _) = await labelsFor(tester, settings, (unit: null, category: .weightedDistance));

      expect(unit, 'yd');
    });

    testWidgets('a run still reads in kilometres', (tester) async {
      final settings = await settingsFor(.metric);

      final (unit, _) = await labelsFor(tester, settings, (unit: null, category: .cardio));

      expect(unit, 'km');
    });
  });
}
