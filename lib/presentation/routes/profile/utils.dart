part of 'profile.dart';

String _chartTypeCopy(BuildContext context, ChartPreferenceType option) {
  return switch (option) {
    .exerciseTotalReps => L.of(context).exerciseTotalReps,
    .maxConsecutiveReps => L.of(context).maxConsecutiveReps,
    .topSetWeight => L.of(context).topSetWeight,
    .estimatedOneRepMax => L.of(context).estimatedOneRepMax,
    .totalVolume => L.of(context).totalVolume,
    .averageWorkingWeight => L.of(context).averageWorkingWeight,
    .addedWeightTopSet => L.of(context).addedWeightTopSet,
    .assistanceWeight => L.of(context).assistanceWeight,
    .maxRepsInSet => L.of(context).maxRepsInSet,
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
