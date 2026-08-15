part of 'goals.dart';

/// The behaviour behind a goal's target field, shared by the two dialogs that
/// have one — the new-goal form and the rung editor.
///
/// Only the behaviour: they lay themselves out differently, one carrying
/// cadence chips and the other a deadline. What they had in common was the part
/// that is easy to get subtly wrong and impossible to see wrong — which
/// formatters a dimension takes, what counts as a usable target, and which
/// direction the units convert. Each kept its own copy, so a fix to one silently
/// left the other behind.
///
/// Units are the whole point of it. The field shows and parses in the user's
/// own units; [toStored] converts back to what the app persists. A target typed
/// as `225 lb` is stored as kilograms like everything else.
class GoalTargetInput {
  /// The dimension being targeted, or null for a plain count of workouts, which
  /// brings no rules of its own.
  final ChartPreferenceType? metric;

  final TextEditingController controller = TextEditingController();

  new(this.metric);

  void dispose() => controller.dispose();

  /// What the field will let through: durations right-to-left as `mm:ss`,
  /// counts whole, everything else decimal. A workout count is a small integer.
  List<TextInputFormatter> get formatters {
    return metric?.formatters ?? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)];
  }

  /// The typed target in display units, or null while the field cannot yield
  /// a usable one.
  ///
  /// A target of zero is not a goal, so it counts as "not filled in" and leaves
  /// the submit button disabled rather than saving something meaningless.
  double? get typed {
    final text = controller.text;
    final value = metric?.parseTyped(text) ?? double.tryParse(text.trim());
    return switch (value) {
      final double target when target > 0 => target,
      _ => null,
    };
  }

  /// Shows an existing target, converted into the user's units.
  ///
  /// Run through the field's own formatters, so a duration arrives as `mm:ss`
  /// rather than a raw count of seconds. A no-op until [Preferences] has
  /// loaded: its unit fields are `late`, and an unconverted number in the box
  /// would be worse than an empty one.
  void prefill(Preferences settings, num stored) {
    if (!settings.isInitialized) return;

    final shown = metric?.converter(settings)(stored) ?? stored.toDouble();
    controller.value = formatters.fold(
      TextEditingValue(text: shown.trimmed()),
      (value, formatter) => formatter.formatEditUpdate(TextEditingValue.empty, value),
    );
  }

  /// The inverse of [prefill]: what to persist for a value typed in the user's
  /// units, the same direction `set_item.dart` converts on input.
  num toStored(Preferences settings, double value) {
    return metric?.storedValue(settings, value) ?? value;
  }
}
