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

  Widget Function(double y) leftLabel(TextStyle? style) {
    switch (this) {
      case .cardioDuration:
      case .totalTimeUnderTension:
        return (double y) {
          return switch (_beautifyDuration(y.round())) {
            String label => Text(label, style: style),
            null => const SizedBox.shrink(),
          };
        };
      case .maxConsecutiveReps:
      case .totalReps:
        return (double y) => y % 1 == 0 ? Text(y.toInt().toString(), style: style) : const SizedBox.shrink();
      default:
        return (double y) => y % 2 == 0 ? Text(y.toInt().toString(), style: style) : const SizedBox.shrink();
    }
  }

  /// Tooltip formatter for the dimensions whose raw value isn't self-explanatory
  /// (times), or `null` to fall back to the chart's default numeric tooltip.
  String Function(double y)? get tooltip {
    return switch (this) {
      .cardioDuration || .totalTimeUnderTension => (y) => _formatDuration(y.toInt()),
      _ => null,
    };
  }
}

/// Rounds a duration-axis tick to a "nice" value — nearest 10s / 30s / 5min /
/// 15min by magnitude — and drops ticks that aren't whole minutes past 10 min,
/// so the axis reads 1:30 or 30:00 rather than 1:15 or 33:30. `null` hides the
/// label (including the zero tick).
String? _beautifyDuration(int seconds) {
  if (seconds == 0) return null;
  final roundTo = switch (seconds) {
    < 60 => 10, // nearest 10s
    < 600 => 30, // nearest 30s
    < 3600 => 300, // nearest 5min
    _ => 900, // nearest 15min
  };
  final rounded = (seconds / roundTo).round() * roundTo;
  // drop values that aren't full minutes once we're past 10 min
  if (rounded % 60 != 0 && rounded >= 600) return null;
  return _formatDuration(rounded);
}

String _formatDuration(int totalSeconds) {
  final d = Duration(seconds: totalSeconds);
  String pad(int n) => n.toString().padLeft(2, '0');
  final minutes = pad(d.inMinutes.remainder(60));
  final seconds = pad(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${pad(d.inHours)}:$minutes:$seconds' : '$minutes:$seconds';
}
