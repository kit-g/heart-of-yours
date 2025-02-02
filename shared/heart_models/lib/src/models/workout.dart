import 'dart:math';

import 'exercise.dart';
import 'exercise_set.dart';
import 'misc.dart';
import 'stats.dart';
import 'ts_for_id.dart';
import 'utils.dart';

/// A collection of sets of the same exercise performed during a single workout
/// E.g., squats 4x10
abstract interface class WorkoutExercise with Iterable<ExerciseSet>, UsesTimestampForId implements Model, Completes {
  Iterable<ExerciseSet> get sets;

  Exercise get exercise;

  double? get total;

  int? get order;

  set order(int? v);

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
}

/// A full workout
abstract interface class Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements Model {
  abstract String? name;

  DateTime? get end;

  Iterable<WorkoutExercise> get sets;

  factory Workout({String? name}) {
    return _Workout(
      start: DateTime.timestamp(),
      name: name,
    );
  }

  factory Workout.fromJson(Map json, ExerciseLookup lookForExercise) = _Workout.fromJson;

  factory Workout.fromRows(Iterable<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      throw ArgumentError('Rows cannot be empty');
    }

    if (rows.length == 1 && rows.first['workoutExerciseId'] == null) {
      return _Workout(
        start: DateTime.parse(rows.first['start']),
        name: rows.first['name'],
      );
    }

    final firstRow = rows.first;
    final workoutId = firstRow['workoutId'] as String;

    final exercisesById = rows.fold<Map<String, List<Map<String, Object?>>>>(
      {},
      (accumulator, row) {
        final workoutExerciseId = row['workoutExerciseId'] as String;
        (accumulator[workoutExerciseId] ??= []).add(row);
        return accumulator;
      },
    );

    final exercises = exercisesById.entries.map(
      (entry) {
        final exercise = Exercise.fromJson(entry.value.first);

        final sets = entry.value.map(
          (row) {
            row['completed'] = row['completed'] == 1;
            return ExerciseSet.fromJson(exercise, row);
          },
        ).toList();

        return _WorkoutExercise._(
          exercise: exercise,
          start: DateTime.parse(deSanitizeId(entry.key)),
          sets: sets,
        );
      },
    ).toList()
      ..sort();

    return _Workout(
      start: DateTime.parse(firstRow['start'] as String),
      name: firstRow['workoutName'] as String?,
      id: workoutId,
      exercises: exercises,
      end: switch (firstRow['end']) {
        String s => DateTime.tryParse(s),
        _ => null,
      },
    );
  }

  /// starts a new exercise
  WorkoutExercise startExercise(Exercise exercise);

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

  (WorkoutExercise, ExerciseSet)? nextIncomplete(WorkoutExercise exercise, ExerciseSet last);

  WorkoutSummary toSummary();

  String weekOf();
}

class _WorkoutExercise with Iterable<ExerciseSet>, UsesTimestampForId implements WorkoutExercise {
  final List<ExerciseSet> _sets;
  final Exercise _exercise;
  @override
  final DateTime start;

  @override
  int? order;

  _WorkoutExercise._({
    ExerciseSet? starter,
    DateTime? start,
    required Exercise exercise,
    List<ExerciseSet>? sets,
  })  : _exercise = exercise,
        start = start ?? DateTime.timestamp(),
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
  double? get total {
    try {
      return map((each) => each.total).reduce((a, b) => (a ?? 0) + (b ?? 0));
    } on StateError {
      return 0;
    }
  }

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
  int compareTo(WorkoutExercise other) {
    return switch ((other.order, order)) {
      ((int there, int here)) => here.compareTo(there),
      _ => super.compareTo(other),
    };
  }

  @override
  bool get isCompleted => every((set) => set.isCompleted);
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
    List<WorkoutExercise>? exercises,
    DateTime? end,
  })  : _sets = exercises ?? <WorkoutExercise>[],
        _id = id,
        _end = end;

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
              )..order = each['order'];
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
      end: json['end'],
      exercises: exercises,
    );
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
    var l = toList();
    return {
      'id': id,
      'name': name,
      'start': start,
      'end': end,
      'exercises': {
        for (var each in l)
          each.id: {
            ...each.toMap(),
            'order': l.indexOf(each),
          },
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
  WorkoutExercise startExercise(Exercise exercise) {
    final ex = WorkoutExercise(starter: ExerciseSet(exercise));
    _sets.add(ex);
    return ex;
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
  bool get isValid => isStarted && every((exercise) => exercise.isCompleted);

  @override
  (WorkoutExercise, ExerciseSet)? nextIncomplete(WorkoutExercise exercise, ExerciseSet last) {
    return switch (exercise._nextIncomplete(last)) {
      ExerciseSet set => (exercise, set),
      _ => switch (_nextIncomplete(exercise)) {
          WorkoutExercise next => (next, next.first),
          _ => null,
        }
    };
  }

  @override
  WorkoutSummary toSummary() {
    return WorkoutSummary(
      id: id,
      name: name,
    );
  }

  @override
  String weekOf() {
    return sanitizeId(getMonday(start));
  }
}

extension on Iterable<Completes> {
  Completes? _nextIncomplete(Completes element) {
    try {
      final l = toList();
      return l.sublist(l.indexOf(element)).firstWhere((each) => !each.isCompleted);
    } on StateError {
      return null;
    }
  }
}
