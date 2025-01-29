import 'misc.dart';

enum ExerciseDirection {
  push,
  pull,
  static,
  other;

  factory ExerciseDirection.fromString(String? s) {
    return switch (s) {
      'Push' => push,
      'Pull' => pull,
      'Static' => static,
      _ => other,
    };
  }
}

abstract interface class Exercise implements Searchable, Model {
  ExerciseDirection get direction;

  String get name;

  String get joint;

  String get level;

  String get modality;

  String get muscleGroup;

  String get ulc;

  factory Exercise.fromJson(Map json) = _Exercise.fromJson;
}

class _Exercise implements Exercise {
  @override
  final ExerciseDirection direction;
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
      direction: ExerciseDirection.fromString(json['direction']),
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
    var dir = '${direction.name.substring(0, 1).toUpperCase()}${direction.name.substring(1)}';
    return {
      'direction': dir,
      'exercise': name,
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
    return name.trim().toLowerCase().contains(query.trim().toLowerCase());
  }

  /// name is the database identifier
  @override
  bool operator ==(Object other) {
    return other is Exercise && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

typedef ExerciseId = String;
typedef ExerciseLookup = Exercise? Function(ExerciseId);

