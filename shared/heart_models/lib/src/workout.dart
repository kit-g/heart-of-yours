import 'dart:math';

import 'exercise.dart';
import 'misc.dart';
import 'ts_for_id.dart';

/// A single set of an exercise
sealed class ExerciseSet with UsesTimestampForId implements Model {
  final Exercise exercise;
  @override
  final DateTime start;

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
          start: start ?? DateTime.now(),
        ),
    };
  }

  factory ExerciseSet.fromJson(Exercise exercise, Map json) {
    return ExerciseSet(
      exercise,
      reps: json['reps'],
      weight: json['weight'],
      start: DateTime.parse(deSanitizeId(json['id'])),
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
  final Duration duration;
  final double distance;

  CardioSet({
    required this.duration,
    required this.distance,
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
      start: DateTime.now(), // a different id
      weight: weight,
      reps: reps,
    );
  }
}

/// A collection of sets of the same exercise performed during a single workout
/// E.g., squats 4x10
abstract interface class WorkoutExercise with Iterable<ExerciseSet>, UsesTimestampForId implements Model {
  Iterable<ExerciseSet> get sets;

  Exercise get exercise;

  double? get total;

  void add(ExerciseSet set);

  bool remove(ExerciseSet set);

  factory WorkoutExercise({required ExerciseSet starter}) {
    return _WorkoutExercise._(
      starter: starter,
      exercise: starter.exercise,
    );
  }

  ExerciseSet? get best;

  /// whether at least one set was marked as done
  bool get isStarted;

  /// whether all sets were marked as done
  bool get isValid;
}

/// A full workout
abstract interface class Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements Model {
  abstract String? name;

  DateTime? get end;

  Iterable<WorkoutExercise> get sets;

  factory Workout({String? name}) {
    return _Workout(
      start: DateTime.now(),
      name: name,
    );
  }

  factory Workout.fromJson(Map json, ExerciseLookup lookForExercise) = _Workout.fromJson;

  /// starts a new exercise
  void startExercise(Exercise exercise);

  /// removes the [WorkoutExercise] from the workout
  void removeExercise(WorkoutExercise exercise);

  /// the total metric (e.g., weight)
  /// in all sets of this exercise
  double? get total;

  /// places [toInsert] before [before]
  /// and moves all other exercises by 1.
  void swap(WorkoutExercise toInsert, WorkoutExercise before);

  /// adds an exercise to the end of the workout
  void append(WorkoutExercise exercise);

  /// marks the workout as complete
  void finish(DateTime end);

  /// whether the workout was marked as complete
  bool get isCompleted;

  /// how long it lasted from [start] to [end]
  Duration? get duration;

  /// whether the workout was actually started,
  /// i.e. at least one set was marked as done
  bool get isStarted;

  /// whether the workout is ready to be finished
  /// i.e. all selected sets are marked as complete
  bool get isValid;
}

class _WorkoutExercise with Iterable<ExerciseSet>, UsesTimestampForId implements WorkoutExercise {
  final List<ExerciseSet> _sets;
  final Exercise _exercise;
  @override
  final DateTime start;

  _WorkoutExercise._({
    ExerciseSet? starter,
    DateTime? start,
    required Exercise exercise,
    List<ExerciseSet>? sets,
  })  : _exercise = exercise,
        start = start ?? DateTime.now(),
        _sets = sets ?? [] {
    if (starter != null) {
      _sets.add(starter);
    }
  }

  @override
  void add(ExerciseSet set) {
    _sets.add(set);
  }

  @override
  Iterator<ExerciseSet> get iterator => _sets.iterator;

  @override
  bool remove(ExerciseSet set) {
    return _sets.remove(set);
  }

  @override
  Iterable<ExerciseSet> get sets => _sets;

  @override
  Exercise get exercise => _sets.firstOrNull?.exercise ?? _exercise;

  @override
  double? get total => map((each) => each.total).reduce((a, b) => (a ?? 0) + (b ?? 0));

  @override
  String toString() {
    return '$runtimeType $_exercise';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (firstOrNull case ExerciseSet s) 'exercise': s.exercise.name,
      'sets': {
        for (var each in this) each.id: each.toMap(),
      }
    };
  }

  @override
  ExerciseSet? get best {
    try {
      return reduce((one, two) => one >= two ? one : two);
    } on StateError {
      return null;
    }
  }

  @override
  bool get isStarted => any((set) => set.isCompleted);

  @override
  bool get isValid => every((set) => set.isCompleted);
}

class _Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements Workout {
  final List<WorkoutExercise> _sets;
  @override
  final DateTime start;

  final String? _id;
  DateTime? _end;

  @override
  String? name;

  _Workout({
    required this.start,
    this.name,
    String? id,
  })  : _sets = [],
        _id = id;

  factory _Workout.fromJson(Map json, ExerciseLookup lookForExercise) {
    final exercises = switch (json['exercises']) {
      Map m => m.values
          .map(
            (each) {
              final exercise = lookForExercise(each['exercise']);
              if (exercise == null) return null;
              return _WorkoutExercise._(
                exercise: exercise,
                start: DateTime.parse(deSanitizeId(each['id'])),
                sets: switch (each['sets']) {
                  Map sets => sets.values.map((set) => ExerciseSet.fromJson(exercise, set)).toList(),
                  _ => null,
                },
              );
            },
          )
          .nonNulls
          .toList()
        ..sort(),
      _ => <WorkoutExercise>[],
    };

    return _Workout(
      start: json['start'],
      name: json['name'],
      id: json['id'],
    )
      .._end = json['end']
      .._sets.addAll(exercises);
  }

  @override
  DateTime? get end => _end;

  @override
  String get id => _id ?? super.id;

  @override
  void finish(DateTime end) {
    _end = end;
  }

  @override
  Iterable<WorkoutExercise> get sets => _sets;

  @override
  void removeExercise(WorkoutExercise exercise) {
    _sets.remove(exercise);
  }

  @override
  Iterator<WorkoutExercise> get iterator => _sets.iterator;

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start': start,
      'end': end,
      'exercises': {
        for (var each in this) each.id: each.toMap(),
      },
    };
  }

  @override
  String toString() {
    return switch (name) {
      String n => n,
      null => 'Workout on ${_dateFormat(start)}',
    };
  }

  static String _dateFormat(DateTime d) {
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  static String _pad(int i) {
    return i.toString().padLeft(2, '0');
  }

  @override
  void startExercise(Exercise exercise) {
    _sets.add(WorkoutExercise(starter: ExerciseSet(exercise)));
  }

  @override
  double? get total {
    try {
      return map((each) => each.total).reduce((a, b) => (a ?? 0) + (b ?? 0));
    } on StateError {
      return null;
    }
  }

  @override
  void swap(WorkoutExercise toInsert, WorkoutExercise before) {
    final toInsertIndex = _sets.indexOf(toInsert);
    final beforeIndex = _sets.indexOf(before);
    final descending = beforeIndex > toInsertIndex;
    final newIndex = descending ? max(beforeIndex - 1, 0) : beforeIndex;

    _sets
      ..remove(toInsert)
      ..insert(newIndex, toInsert);
  }

  @override
  void append(WorkoutExercise exercise) {
    _sets
      ..remove(exercise)
      ..add(exercise);
  }

  @override
  bool get isCompleted => end != null;

  @override
  Duration? get duration {
    return switch (end) {
      DateTime end => end.difference(start),
      null => null,
    };
  }

  @override
  bool get isStarted => any((exercise) => exercise.isStarted);

  @override
  bool get isValid => isStarted && every((exercise) => exercise.isValid);
}
