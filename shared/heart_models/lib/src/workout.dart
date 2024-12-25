import 'exercise.dart';
import 'ts_for_id.dart';

/// A single set of an exercise
sealed class ExerciseSet with UsesTimestampForId {
  final Exercise exercise;

  bool completed = false;

  ExerciseSet._({required this.exercise});

  factory ExerciseSet(Exercise exercise, {int? reps, double? weight}) {
    return switch (exercise) {
      Exercise e => _WeightedSet(
          exercise: e,
          reps: reps,
          weight: weight,
        ),
    };
  }
}

/// A set meant to be executed in a number of repetitions
sealed class SetForReps extends ExerciseSet {
  SetForReps({required super.exercise}) : super._();

  abstract int? reps;
}

/// A set for exercise executed with a weight, e.g. a dumbbell
abstract class WeightedSet extends SetForReps {
  abstract double? weight;

  WeightedSet({required super.exercise});
}

/// A set for exercise executed with help, e.g. assisted pull-ups
abstract class AssistedSet extends SetForReps {
  abstract double weight;

  AssistedSet({required super.exercise});
}

/// A cardio exercise
abstract class CardioSet extends ExerciseSet {
  final Duration duration;
  final double distance;

  CardioSet({
    required this.duration,
    required this.distance,
    required super.exercise,
  }) : super._();
}

sealed class _SetForReps extends SetForReps {
  @override
  int? reps;

  @override
  DateTime start;

  _SetForReps({
    required super.exercise,
    this.reps,
  }) : start = DateTime.now();

  @override
  String toString() {
    return '$exercise for $reps reps';
  }
}

class _WeightedSet extends _SetForReps implements WeightedSet {
  @override
  double? weight;

  _WeightedSet({
    required super.exercise,
    super.reps,
    this.weight,
  });
}

/// A collection of sets of the same performed during a single workout
/// E.g., squats 4x10
abstract interface class WorkoutExercise with Iterable<ExerciseSet> {
  Iterable<ExerciseSet> get sets;

  DateTime get start;

  Exercise get exercise;

  void add(ExerciseSet set);

  bool remove(ExerciseSet set);

  factory WorkoutExercise({required ExerciseSet starter}) = _WorkoutExercise;
}


/// A full workout
abstract interface class Workout with Iterable<WorkoutExercise> {
  abstract String? name;

  DateTime get start;

  String get id;

  DateTime? get end;

  Iterable<WorkoutExercise> get sets;

  void finish(DateTime end);

  void add(WorkoutExercise set);

  Map<String, dynamic> toMap();

  factory Workout({String? name}) {
    return _Workout(
      start: DateTime.now(),
      name: name,
    );
  }

  void startExercise(Exercise exercise);
}

class _WorkoutExercise with Iterable<ExerciseSet>, UsesTimestampForId implements WorkoutExercise {
  final _sets = <ExerciseSet>[];
  final Exercise _exercise;
  @override
  final DateTime start;

  _WorkoutExercise({required ExerciseSet starter})
      : start = DateTime.now(),
        _exercise = starter.exercise {
    _sets.add(starter);
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
}

class _Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements Workout {
  final List<WorkoutExercise> _sets;
  @override
  final DateTime start;
  DateTime? _end;

  @override
  String? name;

  _Workout({
    required this.start,
    this.name,
  }) : _sets = [];

  @override
  DateTime? get end => _end;

  @override
  void finish(DateTime end) {
    _end = end;
  }

  @override
  Iterable<WorkoutExercise> get sets => _sets;

  @override
  void add(WorkoutExercise set) {
    _sets.add(set);
  }

  @override
  Iterator<WorkoutExercise> get iterator => _sets.iterator;

  @override
  Map<String, dynamic> toMap() {
    // TODO: implement toMap
    return {
      'id': id,
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
}
