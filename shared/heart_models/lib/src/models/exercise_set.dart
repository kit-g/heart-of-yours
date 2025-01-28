import 'exercise.dart';
import 'misc.dart';
import 'ts_for_id.dart';
import 'utils.dart';

abstract interface class Completes {
  bool get isCompleted;
}

/// A single set of an exercise
sealed class ExerciseSet with UsesTimestampForId implements Completes, Model, Storable {
  final Exercise exercise;
  @override
  final DateTime start;

  @override
  bool isCompleted = false;

  ExerciseSet._({
    required this.exercise,
    required this.start,
  });

  factory ExerciseSet(Exercise exercise, {DateTime? start, int? reps, double? weight}) {
    return switch (exercise) {
      Exercise e => _WeightedSet(
          exercise: e,
          reps: reps,
          weight: weight,
          start: start ?? DateTime.timestamp(),
        ),
    };
  }

  factory ExerciseSet.fromJson(Exercise exercise, Map json) {
    return ExerciseSet(
      exercise,
      reps: json['reps'],
      weight: json['weight'],
      start: DateTime.parse(deSanitizeId(json['id'] ?? json['setId'])),
    )..isCompleted = json['completed'] ?? false;
  }

  bool get canBeCompleted;

  double? get total;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'completed': isCompleted,
    };
  }

  bool operator >(covariant ExerciseSet other) {
    return (total ?? 0) > (other.total ?? 0);
  }

  bool operator >=(covariant ExerciseSet other) {
    return (total ?? 0) >= (other.total ?? 0);
  }

  bool operator <(covariant ExerciseSet other) {
    return (total ?? 0) < (other.total ?? 0);
  }

  bool operator <=(covariant ExerciseSet other) {
    return (total ?? 0) <= (other.total ?? 0);
  }

  ExerciseSet copy();

  void setMeasurements({
    double? weight,
    int? reps,
    int? duration,
  }) {
    switch (this) {
      case CardioSet self:
        self.duration = duration;
      case WeightedSet self:
        self
          ..weight = weight ?? self.weight
          ..reps = reps ?? self.reps;
      case AssistedSet self:
        self
          ..weight = weight ?? self.weight
          ..reps = reps ?? self.reps;
    }
  }
}

/// A set meant to be executed in a number of repetitions
sealed class SetForReps extends ExerciseSet {
  SetForReps({
    required super.exercise,
    required super.start,
  }) : super._();

  abstract int? reps;

  @override
  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      ...super.toMap(),
    };
  }
}

/// A set for exercise executed with a weight, e.g. a dumbbell
abstract class WeightedSet extends SetForReps {
  abstract double? weight;

  WeightedSet({
    required super.exercise,
    required super.start,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      ...super.toMap(),
    };
  }
}

/// A set for exercise executed with help, e.g. assisted pull-ups
abstract class AssistedSet extends SetForReps {
  abstract double? weight;

  AssistedSet({
    required super.exercise,
    required super.start,
  });
}

/// A cardio exercise
abstract class CardioSet extends ExerciseSet {
  abstract int? duration; // milliseconds
  abstract double? distance;
  abstract int? reps;

  CardioSet({
    required super.exercise,
    required super.start,
  }) : super._();

  @override
  Map<String, dynamic> toMap() {
    throw UnimplementedError();
  }
}

sealed class _SetForReps extends SetForReps {
  @override
  int? reps;

  _SetForReps({
    required super.exercise,
    this.reps,
    required super.start,
  });
}

class _WeightedSet extends _SetForReps implements WeightedSet {
  @override
  double? weight;

  _WeightedSet({
    required super.exercise,
    super.reps,
    this.weight,
    required super.start,
  });

  @override
  bool get canBeCompleted => reps != null && weight != null;

  @override
  double? get total {
    return switch ((weight, reps)) {
      (double w, int r) => w * r,
      _ => null,
    };
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      ...super.toMap(),
    };
  }

  @override
  ExerciseSet copy() {
    return _WeightedSet(
      exercise: exercise,
      start: DateTime.timestamp(), // a different id
      weight: weight,
      reps: reps,
    );
  }

  @override
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'reps': reps,
      'weight': weight,
      'completed': isCompleted ? 1 : 0,
    };
  }
}

// ignore: unused_element
class _CardioSet extends SetForReps implements CardioSet {
  @override
  double? distance;
  @override
  int? duration;
  @override
  int? reps;

  _CardioSet({
    required super.exercise,
    required super.start,
  });

  @override
  bool get canBeCompleted => distance != null && duration != null && reps != null;

  @override
  ExerciseSet copy() {
    return _CardioSet(
      exercise: exercise,
      start: DateTime.timestamp(), // a different id
    )
      ..reps = reps
      ..duration = duration
      ..distance = distance;
  }

  @override
  double? get total {
    return switch ((duration, reps)) {
      (num duration, num reps) => (duration * reps).toDouble(),
      _ => null,
    };
  }

  @override
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'reps': reps,
      'duration': duration,
      'completed': isCompleted ? 1 : 0,
    };
  }
}
