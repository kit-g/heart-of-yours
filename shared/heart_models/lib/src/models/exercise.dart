import 'misc.dart';

abstract interface class ExerciseFilter {
  String get value;
}

enum Category implements ExerciseFilter {
  weightedBodyWeight('Weighted Body Weight'),
  assistedBodyWeight('Assisted Body Weight'),
  repsOnly('Reps Only'),
  cardio('Cardio'),
  duration('Duration'),
  machine('Machine'),
  dumbbell('Dumbbell'),
  barbell('Barbell');

  @override
  final String value;

  const Category(this.value);

  factory Category.fromString(String v) {
    return switch (v) {
      'Weighted Body Weight' => weightedBodyWeight,
      'Assisted Body Weight' => assistedBodyWeight,
      'Reps Only' => repsOnly,
      'Cardio' => cardio,
      'Duration' => duration,
      'Machine' => machine,
      'Dumbbell' => dumbbell,
      'Barbell' => barbell,
      _ => throw ArgumentError('Invalid value for Category: $v'),
    };
  }

  @override
  String toString() => value;
}

enum Target implements ExerciseFilter {
  core('Core'),
  arms('Arms'),
  back('Back'),
  chest('Chest'),
  legs('Legs'),
  shoulder('Shoulders'),
  other('Other'),
  olympic('Olympic'),
  fullBody('Full Body'),
  cardio('Cardio');

  @override
  final String value;

  const Target(this.value);

  factory Target.fromString(String v) {
    return switch (v) {
      'Core' => core,
      'Arms' => arms,
      'Back' => back,
      'Chest' => chest,
      'Legs' => legs,
      'Shoulders' => shoulder,
      'Other' => other,
      'Olympic' => olympic,
      'Full Body' => fullBody,
      'Cardio' => cardio,
      _ => throw ArgumentError('Invalid value for Target: $v'),
    };
  }

  String get icon {
    return switch (this) {
      core => '🏋️',
      arms => '💪',
      back => '🦾',
      chest => '🏋️‍♀️',
      legs => '🦵',
      shoulder => '🤷‍♀️',
      other => '❓',
      olympic => '🏅',
      fullBody => '🤸‍♀️',
      cardio => '❤️',
    };
  }

  @override
  String toString() => value;
}

abstract interface class Exercise implements Searchable, Model {
  String get name;

  Category get category;

  Target get target;

  String? get asset;

  String? get thumbnail;

  factory Exercise.fromJson(Map json) = _Exercise.fromJson;

  bool fits(Iterable<ExerciseFilter> filters);
}

class _Exercise implements Exercise {
  @override
  final String name;
  @override
  final Category category;
  @override
  final Target target;
  @override
  final String? asset;
  @override
  final String? thumbnail;

  const _Exercise({
    required this.name,
    required this.category,
    required this.target,
    this.asset,
    this.thumbnail,
  });

  factory _Exercise.fromJson(Map json) {
    return _Exercise(
      name: json['name'],
      category: Category.fromString(json['category']),
      target: Target.fromString(json['target']),
      asset: json['asset'],
      thumbnail: json['thumbnail'],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'category': category.value,
      'name': name,
      'target': target.value,
      if (asset != null) 'asset': asset,
      if (thumbnail != null) 'thumbnail': thumbnail,
    };
  }

  @override
  String toString() => name;

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

  @override
  bool fits(Iterable<ExerciseFilter> filters) {
    final categories = filters.whereType<Category>();
    final targets = filters.whereType<Target>();

    final categoryMatches = categories.isEmpty || categories.contains(category);
    final targetMatches = targets.isEmpty || targets.contains(target);

    return categoryMatches && targetMatches;
  }
}

typedef ExerciseId = String;
typedef ExerciseLookup = Exercise? Function(ExerciseId);
