import 'dart:convert';

import 'exercise.dart' show Category;

enum ChartPreferenceType {
  exerciseTotalReps('exerciseTotalReps'),
  maxConsecutiveReps('maxConsecutiveReps'),
  topSetWeight('topSetWeight'),
  estimatedOneRepMax('estimatedOneRepMax'),
  totalVolume('totalVolume'),
  averageWorkingWeight('averageWorkingWeight'),
  addedWeightTopSet('addedWeightTopSet'),
  assistanceWeight('assistanceWeight'),
  maxRepsInSet('maxRepsInSet'),
  totalReps('totalReps'),
  cardioDistance('cardioDistance'),
  cardioDuration('cardioDuration'),
  averagePace('averagePace'),
  totalTimeUnderTension('totalTimeUnderTension'),
  ;

  final String value;

  const ChartPreferenceType(this.value);

  factory ChartPreferenceType.fromString(String v) {
    return switch (v) {
      'exerciseTotalReps' => exerciseTotalReps,
      'maxConsecutiveReps' => maxConsecutiveReps,
      'topSetWeight' => topSetWeight,
      'estimatedOneRepMax' => estimatedOneRepMax,
      'totalVolume' => totalVolume,
      'averageWorkingWeight' => averageWorkingWeight,
      'addedWeightTopSet' => addedWeightTopSet,
      'assistanceWeight' => assistanceWeight,
      'maxRepsInSet' => maxRepsInSet,
      'totalReps' => totalReps,
      'cardioDistance' => cardioDistance,
      'cardioDuration' => cardioDuration,
      'averagePace' => averagePace,
      'totalTimeUnderTension' => totalTimeUnderTension,
      _ => throw ArgumentError(v),
    };
  }

  static List<ChartPreferenceType> chartsByExerciseCategory(Category category) {
    switch (category) {
      case .weightedBodyWeight:
        return const [
          .topSetWeight,
          .totalVolume,
          .estimatedOneRepMax,
          .averageWorkingWeight,
          .addedWeightTopSet,
          .maxRepsInSet,
          .totalReps,
          .maxConsecutiveReps,
          .exerciseTotalReps,
        ];

      case .assistedBodyWeight:
        return const [
          .assistanceWeight,
          .topSetWeight,
          .totalVolume,
          .averageWorkingWeight,
          .maxRepsInSet,
          .totalReps,
          .maxConsecutiveReps,
          .exerciseTotalReps,
        ];

      case .repsOnly:
        return const [.maxConsecutiveReps, .maxRepsInSet, .totalReps, .exerciseTotalReps];

      case .cardio:
        return const [.cardioDistance, .cardioDuration, .averagePace];

      case .duration:
        return const [.totalTimeUnderTension];

      case .machine:
      case .dumbbell:
      case .barbell:
        return const [
          .topSetWeight,
          .estimatedOneRepMax,
          .totalVolume,
          .averageWorkingWeight,
          .maxRepsInSet,
          .totalReps,
          .maxConsecutiveReps,
          .exerciseTotalReps,
        ];
    }
  }
}

abstract interface class ChartPreference {
  String? get id;

  ChartPreferenceType get type;

  Map<String, dynamic>? get data;

  Map<String, dynamic> toRow();

  String? get exerciseName;

  ChartPreference copyWith({
    String? id,
    ChartPreferenceType? type,
    Map<String, dynamic>? data,
  });

  factory ChartPreference.fromRow(Map row) {
    return _ChartPreference(
      id: row['id']?.toString(),
      type: ChartPreferenceType.fromString(row['type']),
      data: switch (row['data']) {
        String raw => jsonDecode(raw),
        null => null,
        _ => throw ArgumentError(row),
      },
    );
  }

  factory ChartPreference.topSetWeight(String exerciseName) {
    return _ChartPreference(
      id: null,
      type: .topSetWeight,
      data: {'exerciseName': exerciseName},
    );
  }
}

class _ChartPreference implements ChartPreference {
  @override
  final String? id;
  @override
  final ChartPreferenceType type;
  @override
  final Map<String, dynamic>? data;

  const _ChartPreference({
    this.id,
    required this.type,
    required this.data,
  });

  @override
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'type': type.value,
      'data': ?switch (data) {
        Map<String, dynamic> d => jsonEncode(d),
        null => null,
      },
    };
  }

  @override
  ChartPreference copyWith({
    String? id,
    ChartPreferenceType? type,
    Map<String, dynamic>? data,
  }) {
    return _ChartPreference(
      type: type ?? this.type,
      data: data ?? this.data,
      id: id ?? this.id,
    );
  }

  @override
  String? get exerciseName => data?['exerciseName'];
}
