import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The status line's two numbers, in one unit.
///
/// `goalStatus` converts the target it is given but used to print `current` as
/// handed over, so the units it read in depended on which call site called it.
/// Invisible in metric, where the conversion is the identity — which is why it
/// survived to here.
void main() {
  Future<Preferences> settingsFor(MeasurementUnit unit) async {
    SharedPreferences.setMockInitialValues({'weightUnit': unit.name});
    final preferences = Preferences();
    await preferences.init();
    return preferences;
  }

  Goal bench({num target = 100}) {
    return Goal(
      id: 'goal-1',
      metric: .topSetWeight,
      exerciseId: 'exercise-1',
      stages: [GoalStage(id: 's0', target: target)],
    );
  }

  Future<String> statusOf(WidgetTester tester, Preferences settings, {required num? current}) async {
    late String status;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Builder(
          builder: (context) {
            status = goalStatus(context, bench(), settings: settings, current: current);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return status;
  }

  testWidgets('states both numbers in kilograms for a metric user', (tester) async {
    final settings = await settingsFor(MeasurementUnit.metric);

    expect(await statusOf(tester, settings, current: 80), '80 / 100 kg');
  });

  testWidgets('states both numbers in pounds for an imperial user', (tester) async {
    // 80 kg stored reads as ~176 lb, against a 100 kg target at ~220 lb. The
    // bug printed "80 / 220.5 lbs" — one number converted, one not.
    final settings = await settingsFor(MeasurementUnit.imperial);

    final status = await statusOf(tester, settings, current: 80);

    expect(status, contains('lbs'));
    expect(status, isNot(startsWith('80 /')), reason: 'the reading is stored in kg');
    expect(status, startsWith('176'));
  });

  testWidgets('says nothing about progress when there is none to report', (tester) async {
    final settings = await settingsFor(MeasurementUnit.imperial);

    expect(await statusOf(tester, settings, current: null), isNot(contains('/')));
  });
}
