import 'exercise.dart';
import 'misc.dart';
import 'ts_for_id.dart';
import 'utils.dart';

abstract interface class Completes {
  bool get isCompleted;
}

/// A single set of an exercise
abstract interface class ExerciseSet with UsesTimestampForId implements Completes, Model, Storable {
  Exercise get exercise;

  double? get weight;

  int? get reps;

  int? get duration;

  double? get distance;

  @override
  abstract bool isCompleted;

  factory ExerciseSet(
    Exercise exercise, {
    DateTime? start,
    int? reps,
    double? weight,
    double? distance,
    int? duration,
  }) {
    return switch (exercise) {
      Exercise e => _ExerciseSet(
          exercise: e,
          start: start ?? DateTime.timestamp(),
        )
          ..reps = reps
          ..weight = weight
          ..distance = distance
          ..duration = duration,
    };
  }

  factory ExerciseSet.fromJson(Exercise exercise, Map json) {
    return ExerciseSet(
      exercise,
      reps: json['reps'],
      weight: switch (json['weight']) {
        num weight => weight.toDouble(),
        _ => null,
      },
      duration: (json['duration'] as num?)?.toInt(),
      distance: (json['distance'] as num?)?.toDouble(),
      start: DateTime.parse(deSanitizeId(json['id'] ?? json['setId'])),
    )..isCompleted = switch (json['completed']) {
        bool completed => completed,
        1 => true,
        _ => false,
      };
  }

  bool get canBeCompleted;

  double? get total;

  Category get category;

  bool operator >(covariant ExerciseSet other);

  bool operator >=(covariant ExerciseSet other);

  bool operator <(covariant ExerciseSet other);

  bool operator <=(covariant ExerciseSet other);

  ExerciseSet copy({DateTime? start});

  void setMeasurements({
    double? weight,
    int? reps,
    int? duration,
    double? distance,
  });
}

class _ExerciseSet with UsesTimestampForId implements ExerciseSet {
  @override
  final Exercise exercise;
  @override
  final DateTime start;
  @override
  double? weight;
  @override
  int? reps;
  @override
  int? duration;
  @override
  double? distance;

  _ExerciseSet({
    required this.exercise,
    required this.start,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'completed': isCompleted,
      if (reps != null) 'reps': reps,
      if (duration != null) 'duration': duration,
      if (distance != null) 'distance': distance,
      if (weight != null) 'weight': weight,
    };
  }

  @override
  bool operator >(covariant ExerciseSet other) {
    return (total ?? 0) > (other.total ?? 0);
  }

  @override
  bool operator >=(covariant ExerciseSet other) {
    return (total ?? 0) >= (other.total ?? 0);
  }

  @override
  bool operator <(covariant ExerciseSet other) {
    return (total ?? 0) < (other.total ?? 0);
  }

  @override
  bool operator <=(covariant ExerciseSet other) {
    return (total ?? 0) <= (other.total ?? 0);
  }

  @override
  bool isCompleted = false;

  @override
  bool get canBeCompleted {
    switch (category) {
      case Category.assistedBodyWeight:
      case Category.barbell:
      case Category.dumbbell:
      case Category.machine:
        return reps != null && weight != null;
      case Category.weightedBodyWeight:
      case Category.repsOnly:
        return reps != null;
      case Category.cardio:
        return duration != null && distance != null;
      case Category.duration:
        return duration != null;
    }
  }

  @override
  Category get category => exercise.category;

  @override
  ExerciseSet copy({DateTime? start}) {
    return _ExerciseSet(
      exercise: exercise,
      start: start ?? DateTime.timestamp(),
    )
      ..weight = weight
      ..duration = duration
      ..distance = distance
      ..reps = reps;
  }

  @override
  void setMeasurements({double? weight, int? reps, int? duration, double? distance}) {
    switch (category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.machine:
      case Category.barbell:
      case Category.dumbbell:
        this
          ..weight = weight ?? this.weight
          ..reps = reps ?? this.reps;
      case Category.repsOnly:
        this.reps = reps ?? this.reps;
      case Category.cardio:
        this
          ..distance = distance ?? this.distance
          ..duration = duration ?? this.duration;
      case Category.duration:
        this.duration = duration ?? this.duration;
    }
  }

  @override
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'reps': reps,
      'weight': weight,
      'duration': duration,
      'distance': distance,
      'completed': isCompleted ? 1 : 0,
    };
  }

  @override
  double? get total {
    switch (category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.barbell:
      case Category.dumbbell:
      case Category.machine:
        return switch ((weight, reps)) {
          (double w, int r) => w * r,
          _ => null,
        };
      case Category.repsOnly:
        return reps?.toDouble();
      case Category.cardio:
        return switch ((duration, distance)) {
          (int duration, int distance) => duration * distance.toDouble(),
          _ => null,
        };
      case Category.duration:
        return duration?.toDouble();
    }
  }
}
