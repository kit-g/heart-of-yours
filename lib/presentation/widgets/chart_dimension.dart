import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/presentation/widgets/formatters.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The training quality a metric speaks to. Drives the chart color so a glance
/// separates strength from volume from endurance from conditioning. Hues are a
/// CVD-safe categorical set, themed per surface (see the dataviz validator).
enum _ChartFamily {
  strength(light: Color(0xFFE34948), dark: Color(0xFFE66767)),
  volume(light: Color(0xFF2A78D6), dark: Color(0xFF3987E5)),
  endurance(light: Color(0xFF1BAF7A), dark: Color(0xFF199E70)),
  cardio(light: Color(0xFFEB6834), dark: Color(0xFFD95926));

  const _ChartFamily({required this.light, required this.dark});

  final Color light;
  final Color dark;

  Color of(Brightness brightness) {
    return switch (brightness) {
      .dark => dark,
      .light => light,
    };
  }
}

/// Per-dimension presentation for [ChartPreferenceType] charts: the display
/// label, the y-value converter (unit-aware), the left-axis formatter and the
/// training-quality color.
///
/// Single source of truth shared by the profile dashboard and the per-exercise
/// chart page, so adding a dimension only needs updating here.
extension ChartDimension on ChartPreferenceType {
  String label(BuildContext context) {
    final l = L.of(context);
    return switch (this) {
      .maxConsecutiveReps => l.maxRepsInSet,
      .topSetWeight => l.topSetWeight,
      .estimatedOneRepMax => l.estimatedOneRepMax,
      .totalVolume => l.totalVolume,
      .averageWorkingWeight => l.averageWorkingWeight,
      .assistanceWeight => l.assistanceWeight,
      .totalReps => l.totalReps,
      .cardioDistance => l.cardioDistance,
      .cardioDuration => l.cardioDuration,
      .averagePace => l.averagePace,
      .totalTimeUnderTension => l.totalTimeUnderTension,
    };
  }

  /// Maps the raw stored metric to the value shown on the axis, honoring the
  /// user's unit settings. [unit] overrides the default for a specific exercise.
  double Function(num) converter(Preferences settings, {MeasurementUnit? unit}) {
    double weight(num v) => settings.weightValue(v, unit: unit);
    double distance(num v) => settings.distanceValue(v, unit: unit);
    double asIs(num v) => v.toDouble();
    return switch (this) {
      .topSetWeight => weight,
      .estimatedOneRepMax => weight,
      .totalVolume => weight,
      .averageWorkingWeight => weight,
      .assistanceWeight => weight,
      .cardioDistance => distance,
      .maxConsecutiveReps => asIs,
      .totalReps => asIs,
      .cardioDuration => asIs,
      .averagePace => asIs,
      .totalTimeUnderTension => asIs,
    };
  }

  /// The inverse of [converter]: takes a number the user typed in their own
  /// units and returns it in the metric the app stores, the same direction
  /// `set_item.dart` converts on input. Goal targets go through here so a
  /// target typed as `225 lb` is stored as kilograms like everything else.
  double storedValue(Preferences settings, double value, {MeasurementUnit? unit}) {
    double weight() {
      return switch (unit ?? settings.weightUnit) {
        .imperial => value.asKilograms,
        .metric => value,
      };
    }

    double distance() {
      return switch (unit ?? settings.distanceUnit) {
        .imperial => value.asKilometers,
        .metric => value,
      };
    }

    return switch (this) {
      .topSetWeight => weight(),
      .estimatedOneRepMax => weight(),
      .totalVolume => weight(),
      .averageWorkingWeight => weight(),
      .assistanceWeight => weight(),
      .cardioDistance => distance(),
      .maxConsecutiveReps => value,
      .totalReps => value,
      .cardioDuration => value,
      .averagePace => value,
      .totalTimeUnderTension => value,
    };
  }

  /// What a field accepting a value of this dimension will let through.
  ///
  /// Durations are typed right-to-left as `mm:ss`; counts are whole; everything
  /// else takes a decimal. Paired with [parseTyped], which is its inverse.
  List<TextInputFormatter> get formatters {
    if (_isTime) return [TimeFormatter()];
    return switch (this) {
      .maxConsecutiveReps ||
      .totalReps => [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
      _ => [const NDigitFloatingPointFormatter(), FilteringTextInputFormatter.singleLineFormatter],
    };
  }

  /// Reads back what [formatters] allowed, in the unit the field displays —
  /// still the user's, so [storedValue] converts afterwards. Null when the text
  /// does not describe a usable value.
  ///
  /// A duration is seconds behind `mm:ss`, which is why this cannot just be
  /// `double.tryParse` at the call site.
  double? parseTyped(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (_isTime) return parseDuration(trimmed)?.toDouble();
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  /// Whether this dimension's values are durations (formatted mm:ss / h:mm:ss).
  bool get _isTime => this == .cardioDuration || this == .totalTimeUnderTension;

  Widget Function(double y) leftLabel(TextStyle? style) {
    // The chart already snaps ticks to nice values (see HistoryChart), so we
    // label each one exactly — no rounding, no skipping, no duplicates.
    return (double y) => Text(_isTime ? _formatDuration(y.round()) : _trimNumber(y), style: style);
  }

  /// Tooltip formatter for durations; `null` falls back to the chart's default
  /// numeric tooltip.
  String Function(double y)? get tooltip {
    return _isTime ? (y) => _formatDuration(y.round()) : null;
  }

  /// Preferred axis tick steps for [HistoryChart]: time dimensions snap to
  /// conventional 15s/30s/1m/5m/… marks; the rest use generic nice numbers.
  List<double>? get yStepCandidates {
    return _isTime ? const [15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0] : null;
  }

  _ChartFamily get _family {
    return switch (this) {
      .topSetWeight || .estimatedOneRepMax || .averageWorkingWeight || .assistanceWeight => .strength,
      .totalVolume || .totalReps => .volume,
      .maxConsecutiveReps => .endurance,
      .cardioDistance || .cardioDuration || .averagePace || .totalTimeUnderTension => .cardio,
    };
  }

  /// The training-quality color for this dimension, themed for light/dark.
  Color color(BuildContext context) => _family.of(Theme.of(context).brightness);

  /// The y-axis unit shown in the title, for the dimensions whose raw number is
  /// ambiguous (weight and distance depend on the user's unit setting). Reps and
  /// times are self-evident, so they carry no suffix.
  String? unitLabel(BuildContext context, Preferences settings, {MeasurementUnit? unit}) {
    final l = L.of(context);
    return switch (this) {
      .topSetWeight ||
      .estimatedOneRepMax ||
      .totalVolume ||
      .averageWorkingWeight ||
      .assistanceWeight => switch (unit ?? settings.weightUnit) {
        .imperial => l.lbs,
        .metric => l.kg,
      },
      .cardioDistance => switch (unit ?? settings.distanceUnit) {
        .imperial => l.milesPlural,
        .metric => l.km,
      },
      _ => null,
    };
  }

  /// Chart title with its unit appended where one applies, e.g.
  /// "Top set weight · kg" / "Distance · mi".
  String title(BuildContext context, Preferences settings, {MeasurementUnit? unit}) {
    return switch (unitLabel(context, settings, unit: unit)) {
      String u => '${label(context)} · $u',
      null => label(context),
    };
  }

  /// How the sessions inside one period fold into the single number a recurring
  /// goal is measured by.
  ///
  /// "Per week" does not mean the same arithmetic for every dimension: 2000 kg
  /// of volume a week is a total you accumulate, while a 100 kg top set a week
  /// is the week's best lift — summing every session's top set would say you
  /// had pressed 300 kg.
  PeriodAggregate get periodAggregate {
    return switch (this) {
      // quantities that accumulate across the period
      .totalVolume || .totalReps || .totalTimeUnderTension || .cardioDistance || .cardioDuration => .sum,
      // peaks: the best single session in the period, not a running total.
      // Assistance is the odd one — less of it is the improvement — but the
      // model marks only pace as `lowerIsBetter`, so it follows the other
      // weights rather than inventing a second direction here.
      .topSetWeight || .estimatedOneRepMax || .maxConsecutiveReps || .assistanceWeight => .best,
      // already a per-session average, so the period averages those
      .averageWorkingWeight || .averagePace => .mean,
    };
  }
}

/// How several sessions in one period become one number. See
/// [ChartDimension.periodAggregate] for which dimension folds which way.
enum PeriodAggregate {
  sum,
  best,
  mean;

  /// [values] must not be empty — an empty period has no aggregate, and what
  /// to show instead is the caller's decision.
  num of(Iterable<num> values) {
    return switch (this) {
      sum => values.reduce((a, b) => a + b),
      best => values.reduce((a, b) => a > b ? a : b),
      mean => values.reduce((a, b) => a + b) / values.length,
    };
  }
}

String _trimNumber(double value) {
  return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatDuration(int totalSeconds) {
  final d = Duration(seconds: totalSeconds);
  String pad(int n) => n.toString().padLeft(2, '0');
  final minutes = pad(d.inMinutes.remainder(60));
  final seconds = pad(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${pad(d.inHours)}:$minutes:$seconds' : '$minutes:$seconds';
}
