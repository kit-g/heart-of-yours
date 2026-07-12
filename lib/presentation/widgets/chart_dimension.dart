import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Per-dimension presentation for [ChartPreferenceType] charts: the display
/// label, the y-value converter (unit-aware) and the left-axis formatter.
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
