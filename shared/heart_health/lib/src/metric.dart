part of '../models.dart';

/// The health quantities Heart reads from the device's health store.
///
/// A deliberate subset, named on our terms. The `health` package's own
/// `HealthDataType` never leaves this package — the app's state and UI speak
/// [HealthMetric] only, the same way they speak `WorkoutService` rather than
/// SQLite. Adding a quantity means adding a case here and to [_dataType].
enum HealthMetric {
  restingHeartRate('restingHeartRate', HealthUnit.bpm),
  heartRate('heartRate', HealthUnit.bpm),

  /// Beat-to-beat variability. **Not comparable across platforms** — see
  /// [isPlatformDependent]. Apple reports SDNN, Health Connect reports RMSSD.
  heartRateVariability('heartRateVariability', HealthUnit.milliseconds),
  steps('steps', HealthUnit.count),
  activeEnergy('activeEnergy', HealthUnit.kilocalories),
  bodyMass('bodyMass', HealthUnit.kilograms),
  bodyFatPercentage('bodyFatPercentage', HealthUnit.percent),

  /// Sleep quantities arrive as **minutes**, not as an interval — the plugin
  /// converts the category sample's duration into its value.
  sleepAsleep('sleepAsleep', HealthUnit.minutes),
  sleepDeep('sleepDeep', HealthUnit.minutes),
  sleepRem('sleepRem', HealthUnit.minutes),
  ;

  final String value;

  /// The unit every sample of this metric is normalized to on the way in, so
  /// stored rows never carry a mixed unit for one metric.
  final HealthUnit unit;

  new(this.value, this.unit);

  factory fromString(String v) {
    return switch (v) {
      'restingHeartRate' => restingHeartRate,
      'heartRate' => heartRate,
      'heartRateVariability' => heartRateVariability,
      'steps' => steps,
      'activeEnergy' => activeEnergy,
      'bodyMass' => bodyMass,
      'bodyFatPercentage' => bodyFatPercentage,
      'sleepAsleep' => sleepAsleep,
      'sleepDeep' => sleepDeep,
      'sleepRem' => sleepRem,
      _ => throw ArgumentError(v),
    };
  }

  /// Whether the underlying platform quantity differs between iOS and Android
  /// in a way that makes values incomparable.
  ///
  /// Only HRV: Apple exposes SDNN, Health Connect exposes RMSSD. They are
  /// different computations over the same signal and routinely differ by a
  /// factor of two, so a chart must never plot one against the other, and a
  /// narrative must not describe a platform switch as a change in the user.
  bool get isPlatformDependent => this == heartRateVariability;

  /// Whether samples of this metric accumulate over their interval (and so
  /// must never be summed across overlapping sources — see [HealthSample.source]).
  ///
  /// Cumulative metrics are the ones the phone *and* the watch *and* a third
  /// app all report for the same hour. Instantaneous ones are point readings.
  bool get isCumulative {
    return switch (this) {
      steps || activeEnergy || sleepAsleep || sleepDeep || sleepRem => true,
      restingHeartRate || heartRate || heartRateVariability || bodyMass || bodyFatPercentage => false,
    };
  }
}

/// The unit a stored [HealthSample] is expressed in.
///
/// Canonically metric, matching the rest of the app — weights are kilograms
/// everywhere and converted only at the display edge (`Preferences.weightValue`).
enum HealthUnit {
  bpm('bpm'),
  milliseconds('ms'),
  count('count'),
  kilocalories('kcal'),
  kilograms('kg'),
  percent('%'),
  minutes('min'),
  ;

  final String value;

  new(this.value);

  factory fromString(String v) {
    return switch (v) {
      'bpm' => bpm,
      'ms' => milliseconds,
      'count' => count,
      'kcal' => kilocalories,
      'kg' => kilograms,
      '%' => percent,
      'min' => minutes,
      _ => throw ArgumentError(v),
    };
  }
}
