part of 'profile.dart';

String _chartTypeCopy(BuildContext context, ChartPreferenceType option) {
  return switch (option) {
    .maxConsecutiveReps => L.of(context).maxRepsInSet,
    .topSetWeight => L.of(context).topSetWeight,
    .estimatedOneRepMax => L.of(context).estimatedOneRepMax,
    .totalVolume => L.of(context).totalVolume,
    .averageWorkingWeight => L.of(context).averageWorkingWeight,
    .assistanceWeight => L.of(context).assistanceWeight,
    .totalReps => L.of(context).totalReps,
    .cardioDistance => L.of(context).cardioDistance,
    .cardioDuration => L.of(context).cardioDuration,
    .averagePace => L.of(context).averagePace,
    .totalTimeUnderTension => L.of(context).totalTimeUnderTension,
  };
}

extension on Offset {
  RelativeRect position() {
    return RelativeRect.fromLTRB(dx, dy, dx, dy);
  }
}

double Function(num) _converter(ChartPreferenceType type, Preferences settings) {
  double asIs(num v) => v.toDouble();
  return switch (type) {
    .topSetWeight => settings.weightValue,
    .estimatedOneRepMax => settings.weightValue,
    .totalVolume => settings.weightValue,
    .averageWorkingWeight => settings.weightValue,
    .assistanceWeight => settings.weightValue,
    .cardioDistance => settings.distanceValue,
    .maxConsecutiveReps => asIs,
    .totalReps => asIs,
    .cardioDuration => asIs,
    .averagePace => asIs,
    .totalTimeUnderTension => asIs,
  };
}

extension on Duration {
  String formatted() {
    final minutes = _pad(inMinutes.remainder(60));
    final seconds = _pad(inSeconds.remainder(60));
    return switch (inHours) {
      > 0 => '${_pad(inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

Widget Function(double y) _getLeftLabel(ChartPreferenceType type, TextStyle? style) {
  switch (type) {
    case .cardioDuration:
    case .totalTimeUnderTension:
      return (double y) {
        final duration = Duration(seconds: y.toInt());
        if (y == 0) return const SizedBox.shrink();
        return Text(duration.formatted(), style: style);
      };
    case .maxConsecutiveReps:
    case .totalReps:
      return (double y) => y % 1 == 0 ? Text(y.toInt().toString(), style: style) : const SizedBox.shrink();
    default:
      return (double y) => y % 2 == 0 ? Text(y.toInt().toString(), style: style) : const SizedBox.shrink();
  }
}
