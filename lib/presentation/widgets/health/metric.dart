import 'package:flutter/material.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

/// Copy, units and axis behaviour for a health metric.
///
/// Lives here rather than on [HealthMetric] because the enum carries
/// identifiers, not words — the same split every other model in this app makes.
/// Shared by the dashboard card and its detail chart so a reading cannot say
/// 81.5 kg in one and 179.7 in the other.
extension HealthMetricDisplay on HealthMetric {
  String label(L l) {
    return switch (this) {
      .restingHeartRate => l.healthRestingHeartRate,
      .heartRateVariability => l.healthHeartRateVariability,
      .sleepAsleep => l.healthSleep,
      .steps => l.healthSteps,
      .activeEnergy => l.healthActiveEnergy,
      .bodyMass => l.healthBodyMass,
      _ => l.health,
    };
  }

  /// The value as shown, and its unit — separated so the unit can be set in a
  /// smaller style beside the number.
  (String, String) display(double value, Preferences settings, L l) {
    return switch (this) {
      .restingHeartRate => (value.round().toString(), l.healthBpm),
      .heartRateVariability => (value.round().toString(), l.healthMilliseconds),
      .steps => (NumberFormat.decimalPattern().format(value.round()), ''),
      .activeEnergy => (value.round().toString(), l.healthKilocalories),
      // Sleep arrives in minutes, and "451" is not a number anyone reads as a
      // night's sleep.
      .sleepAsleep => (_hoursAndMinutes(value, l), ''),
      // Stored in kg like every other weight in the app, converted only here.
      .bodyMass => (
        settings.weight(value),
        switch (settings.weightUnit) {
          .imperial => l.lbs,
          .metric => l.kg,
        },
      ),
      _ => (value.round().toString(), ''),
    };
  }

  /// A stored value in the units the user reads, ready to plot.
  ///
  /// Only body mass moves; the rest are already in their display unit. The chart
  /// is given converted numbers, so anything compared against them — an axis
  /// label, a tooltip — has to be converted too.
  double plot(double value, Preferences settings) {
    return switch (this) {
      .bodyMass => settings.weightValue(value),
      _ => value,
    };
  }

  /// Axis labels, in the units [plot] produced.
  Widget Function(double y) leftLabel(TextStyle? style, Preferences settings, L l) {
    return (double y) => Text(_axisLabel(y, settings, l), style: style);
  }

  /// The reading behind a touched point, unit included — the axis has room for
  /// numbers only, so this is where the unit gets said.
  String Function(double y) tooltip(Preferences settings, L l) {
    return (double y) {
      final label = _axisLabel(y, settings, l);
      return switch (unitSuffix(settings, l)) {
        String suffix when suffix.isNotEmpty => '$label $suffix',
        _ => label,
      };
    };
  }

  /// The unit as it appears next to a number, or empty where the number speaks
  /// for itself (steps) or already carries its own units (sleep).
  String unitSuffix(Preferences settings, L l) {
    return switch (this) {
      .restingHeartRate => l.healthBpm,
      .heartRateVariability => l.healthMilliseconds,
      .activeEnergy => l.healthKilocalories,
      .bodyMass => switch (settings.weightUnit) {
        .imperial => l.lbs,
        .metric => l.kg,
      },
      _ => '',
    };
  }

  /// Width to reserve for this metric's y-axis labels.
  ///
  /// `historyChartLeftAxisSize` is 60, sized for the longest label in the app
  /// (`1:30:00`). Health labels are nowhere near that — `300`, `12K`, `8h 0m` —
  /// and the unused reserve is dead space on the left of the plot, which inside
  /// a dialog reads as the whole chart sitting off to one side.
  double get axisWidth {
    return switch (this) {
      .sleepAsleep || .sleepDeep || .sleepRem => 46,
      .steps => 38,
      _ => 34,
    };
  }

  /// Preferred axis tick steps. Sleep is minutes, so left to generic nice
  /// numbers it lands on ticks like 380 and 460 — snapping to half and whole
  /// hours is what makes the axis readable as sleep rather than as a number.
  List<double>? get yStepCandidates {
    return switch (this) {
      .sleepAsleep || .sleepDeep || .sleepRem => const [15.0, 30.0, 60.0, 120.0, 180.0],
      _ => null,
    };
  }

  String _axisLabel(double y, Preferences settings, L l) {
    return switch (this) {
      .sleepAsleep || .sleepDeep || .sleepRem => _hoursAndMinutes(y, l),
      .steps => NumberFormat.compact().format(y.round()),
      // Body mass arrives here already converted by [plot], so this must not
      // convert again — `_trimmed` is the same one-decimal convention
      // `Preferences.weight` applies.
      _ => _trimmed(y),
    };
  }
}

String _hoursAndMinutes(double minutes, L l) {
  return '${minutes ~/ 60}${l.healthHoursShort} ${(minutes % 60).round()}${l.healthMinutesShort}';
}

String _trimmed(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
}
