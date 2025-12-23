import 'dart:convert';

enum ChartPreferenceType {
  exerciseWeight('exerciseWeight'),
  exerciseReps('exerciseReps')
  ;

  final String value;

  const ChartPreferenceType(this.value);

  factory ChartPreferenceType.fromString(String v) {
    return switch (v) {
      'exerciseWeight' => exerciseWeight,
      'exerciseReps' => exerciseReps,
      _ => throw ArgumentError(v),
    };
  }
}

abstract interface class ChartPreference {
  String? get id;

  ChartPreferenceType get type;

  Map<String, dynamic>? get data;

  Map<String, dynamic> toRow();

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

  factory ChartPreference.exerciseWeight(String exerciseName) {
    return _ChartPreference(
      id: null,
      type: .exerciseWeight,
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
}
