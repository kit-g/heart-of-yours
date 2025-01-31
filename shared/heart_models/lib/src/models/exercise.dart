import 'misc.dart';

abstract interface class Exercise implements Searchable, Model {
  String get name;

  String get category;

  String get target;

  factory Exercise.fromJson(Map json) = _Exercise.fromJson;
}

class _Exercise implements Exercise {
  @override
  final String name;
  @override
  final String category;
  @override
  final String target;

  const _Exercise({
    required this.name,
    required this.category,
    required this.target,
  });

  factory _Exercise.fromJson(Map json) {
    return _Exercise(
      name: json['name'],
      category: json['category'],
      target: json['target'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'name': name,
      'target': target,
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
