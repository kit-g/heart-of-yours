import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The target field's behaviour, once, instead of twice.
///
/// The new-goal form and the rung editor each carried their own copy of this —
/// which formatters a dimension takes, what counts as a usable target, and
/// which way the units convert. A fix to one left the other behind, and nothing
/// here was reachable by a test while it lived inside two dialogs.
void main() {
  Future<Preferences> settingsFor(MeasurementUnit unit) async {
    SharedPreferences.setMockInitialValues({'weightUnit': unit.name});
    final preferences = Preferences();
    await preferences.init();
    return preferences;
  }

  test('a target of zero is not a goal, so the field yields nothing', () {
    final input = GoalTargetInput(ChartPreferenceType.topSetWeight);
    addTearDown(input.dispose);

    input.controller.text = '0';
    expect(input.typed, isNull);

    input.controller.text = '';
    expect(input.typed, isNull);

    input.controller.text = '100';
    expect(input.typed, 100);
  });

  test('a workout count takes digits only, and few of them', () {
    // no dimension: a plain count, which brings no rules of its own
    final input = GoalTargetInput(null);
    addTearDown(input.dispose);

    expect(input.formatters, hasLength(2));
    expect(input.formatters.first, isA<FilteringTextInputFormatter>());
  });

  test('a duration reads back as seconds behind mm:ss', () {
    final input = GoalTargetInput(ChartPreferenceType.cardioDuration);
    addTearDown(input.dispose);

    input.controller.text = '05:30';
    expect(input.typed, 330);
  });

  group('units', () {
    test('shows a stored value in the user\'s own', () async {
      final input = GoalTargetInput(ChartPreferenceType.topSetWeight);
      addTearDown(input.dispose);

      input.prefill(await settingsFor(MeasurementUnit.imperial), 100);

      expect(input.controller.text, startsWith('220'));
    });

    test('converts a typed value back to what is persisted', () async {
      final input = GoalTargetInput(ChartPreferenceType.topSetWeight);
      addTearDown(input.dispose);

      final settings = await settingsFor(MeasurementUnit.imperial);
      expect(input.toStored(settings, 220.5), closeTo(100, .1));
    });

    test('round-trips, so an edit does not drift the target', () async {
      // prefill then submit without touching the field must give back what it
      // was handed — the case where a stray conversion shows up as a number
      // creeping every time a rung is opened and saved
      final input = GoalTargetInput(ChartPreferenceType.topSetWeight);
      addTearDown(input.dispose);

      final settings = await settingsFor(MeasurementUnit.imperial);
      input.prefill(settings, 100);

      expect(input.toStored(settings, input.typed!), closeTo(100, .5));
    });

    test('leaves the field empty until preferences have loaded', () {
      // its unit fields are `late`; an unconverted number would be worse than
      // an empty box
      final input = GoalTargetInput(ChartPreferenceType.topSetWeight);
      addTearDown(input.dispose);

      input.prefill(Preferences(), 100);

      expect(input.controller.text, isEmpty);
    });
  });
}
