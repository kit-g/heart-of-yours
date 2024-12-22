import 'misc.dart';

abstract interface class Exercise implements Searchable {
  String get direction;

  String get name;

  String get joint;

  String get level;

  String get modality;

  String get muscleGroup;

  String get ulc;

  factory Exercise.fromJson(Map json) = _Exercise.fromJson;

  Map<String, dynamic> toMap();
}

class _Exercise implements Exercise {
  @override
  final String direction;
  @override
  final String name;
  @override
  final String joint;
  @override
  final String level;
  @override
  final String modality;
  @override
  final String muscleGroup;
  @override
  final String ulc;

  const _Exercise({
    required this.direction,
    required this.name,
    required this.joint,
    required this.level,
    required this.modality,
    required this.muscleGroup,
    required this.ulc,
  });

  factory _Exercise.fromJson(Map json) {
    return _Exercise(
      direction: json['direction'],
      name: json['exercise'],
      joint: json['joint'],
      level: json['level'],
      modality: json['modality'],
      muscleGroup: json['muscleGroup'],
      ulc: json['ulc'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'direction': direction,
      'name': name,
      'joint': joint,
      'level': level,
      'modality': modality,
      'muscleGroup': muscleGroup,
      'ulc': ulc,
    };
  }

  @override
  String toString() {
    return name;
  }

  @override
  bool contains(String query) {
    if (query.isEmpty) return true;
    return name.toLowerCase().contains(query.toLowerCase());
  }
}
