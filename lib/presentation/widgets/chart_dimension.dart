import 'package:flutter/services.dart';
import 'package:heart/presentation/widgets/formatters.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The training quality a metric speaks to. Drives the chart color so a glance
/// separates strength from volume from endurance from conditioning. Hues are a
/// CVD-safe categorical set, themed per surface (see the dataviz validator).
enum _ChartFamily {
  strength(light: Color(0xFFE34948), dark: Color(0xFFE66767)),
  volume(light: Color(0xFF2A78D6), dark: Color(0xFF3987E5)),
  endurance(light: Color(0xFF1BAF7A), dark: Color(0xFF199E70)),
  cardio(light: Color(0xFFEB6834), dark: Color(0xFFD95926));

  new({required this.light, required this.dark});

  final Color light;
  final Color dark;

  Color of(Brightness brightness) {
    return switch (brightness) {
      .dark => dark,
      .light => light,
    };
  }
}

/// What one exercise's numbers are read in: its own unit override (null for the
/// user's default) and its category, which puts a carry's distance in metres or
/// yards where a run's is in km or miles.
typedef ChartScale = ({MeasurementUnit? unit, Category? category});

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
  /// user's unit settings. [unit] overrides the default for a specific exercise,
  /// and [category] is that exercise's: a carry's distance reads in metres or
  /// yards (see [Preferences.shortDistance]).
  double Function(num) converter(Preferences settings, {MeasurementUnit? unit, Category? category}) {
    double weight(num v) => settings.weightValue(v, unit: unit);
    double distance(num v) {
      if (_isShort(category)) return settings.shortDistanceValue(v, unit: unit);
      return settings.distanceValue(v, unit: unit);
    }

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
  /// target typed as `225 lb` is stored as kilograms like everything else, and
  /// one typed as `30 m` on a carry as kilometres.
  double storedValue(Preferences settings, double value, {MeasurementUnit? unit, Category? category}) {
    double weight() {
      return switch (unit ?? settings.weightUnit) {
        .imperial => value.asKilograms,
        .metric => value,
      };
    }

    double distance() {
      if (_isShort(category)) return settings.shortDistanceStored(value, unit: unit);
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
    if (isDuration) return [TimeFormatter()];
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
    if (isDuration) return parseDuration(trimmed)?.toDouble();
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  /// Whether this dimension reads in metres or yards for an exercise of
  /// [category] — its distance, on the scale the category reads distance on.
  bool _isShort(Category? category) {
    if (this != .cardioDistance) return false;
    return switch (category?.distanceScale) {
      .short => true,
      .long || null => false,
    };
  }

  Widget Function(double y) leftLabel(TextStyle? style) {
    // The chart already snaps ticks to nice values (see HistoryChart), so we
    // label each one exactly — no rounding, no skipping, no duplicates.
    return (double y) => Text(isDuration ? _formatDuration(y.round()) : _trimNumber(y), style: style);
  }

  /// Tooltip formatter for durations; `null` falls back to the chart's default
  /// numeric tooltip.
  String Function(double y)? get tooltip {
    return isDuration ? (y) => _formatDuration(y.round()) : null;
  }

  /// Preferred axis tick steps for [HistoryChart]: time dimensions snap to
  /// conventional 15s/30s/1m/5m/… marks; the rest use generic nice numbers.
  List<double>? get yStepCandidates {
    return isDuration ? const [15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0] : null;
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
  String? unitLabel(BuildContext context, Preferences settings, {MeasurementUnit? unit, Category? category}) {
    final l = L.of(context);
    if (_isShort(category)) {
      return switch (unit ?? settings.distanceUnit) {
        .imperial => l.yardsShort,
        .metric => l.metresShort,
      };
    }
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
  String title(BuildContext context, Preferences settings, {MeasurementUnit? unit, Category? category}) {
    return switch (unitLabel(context, settings, unit: unit, category: category)) {
      String u => '${label(context)} · $u',
      null => label(context),
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
