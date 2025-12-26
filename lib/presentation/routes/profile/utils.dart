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
