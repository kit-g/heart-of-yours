import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'exercise.dart';
import 'exercise_set.dart';
import 'misc.dart';
import 'stats.dart';
import 'ts_for_id.dart';

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

  static List<WorkoutExercise> fromCollection(Map json, ExerciseLookup lookForExercise) {
    return _exercisesFromCollection(json['exercises'], lookForExercise);
  }
}

abstract interface class HasExercises {
  /// starts a new exercise
  WorkoutExercise add(Exercise exercise);

  /// removes the [WorkoutExercise] from the workout
  bool remove(WorkoutExercise exercise);

  /// places [toInsert] before [before]
  /// and moves all other exercises by 1.
  void swap(WorkoutExercise toInsert, WorkoutExercise before);

  /// adds an exercise to the end of the workout
  void append(WorkoutExercise exercise);
}

/// A full workout
abstract interface class Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements HasExercises, Model {
  abstract String? name;

  abstract DateTime? end;

  Iterable<WorkoutExercise> get sets;

  abstract Uint8List? localImage;

  abstract WorkoutImage? remoteImage;

  factory Workout({String? name}) {
    return _Workout(
      start: DateTime.timestamp(),
      name: name,
    );
  }

  factory Workout.fromExercises(Iterable<WorkoutExercise> exercises, {String? name}) {
    return _Workout(
      start: DateTime.timestamp(),
      name: name,
      exercises: exercises.toList(),
    );
  }

  factory Workout.fromJson(Map json, ExerciseLookup lookForExercise) = _Workout.fromJson;

  /// the total metric (e.g., weight)
  /// in all sets of this exercise
  double? get total;

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

  /// Makes a copy of itself with a new set of IDs
  Workout copy({bool sameId});

  void completeAllSets();
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
  }) : _exercise = exercise,
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
      'sets': [
        for (var each in where((each) => each.isCompleted)) each.toMap(),
      ],
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

abstract interface class WorkoutImage implements Comparable<WorkoutImage>, Storable {
  String get workoutId;

  String get id;

  String? get link;

  Uint8List? get bytes;

  String get key;

  factory WorkoutImage.fromJson(Map json) = _WorkoutImage.fromJson;

  factory WorkoutImage.local(String url, String workoutId, Uint8List bytes) {
    final Uri(:String path) = Uri.parse(url);
    return _WorkoutImage(
      workoutId: workoutId,
      id: path.split('/').last.split('.').first,
      link: url,
      key: path,
      bytes: bytes,
    );
  }
}

class _WorkoutImage implements WorkoutImage {
  @override
  final String workoutId;
  @override
  final String id;
  @override
  final String link;
  @override
  final String key;
  @override
  final Uint8List? bytes;

  const _WorkoutImage({
    required this.workoutId,
    required this.id,
    required this.link,
    required this.key,
    this.bytes,
  });

  factory _WorkoutImage.fromJson(Map json) {
    return _WorkoutImage(
      workoutId: json['workoutId'],
      id: json['id'],
      link: json['url'],
      key: json['key'],
    );
  }

  @override
  Map<String, dynamic> toRow() {
    return {
      'workoutId': workoutId,
      'id': id,
      'url': link,
      'key': key,
    };
  }

  @override
  int compareTo(WorkoutImage other) {
    return other.id.compareTo(id);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutImage && key == other.key;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() {
    return 'Image $id';
  }
}

class _Workout with Iterable<WorkoutExercise>, UsesTimestampForId implements Workout {
  final List<WorkoutExercise> _sets;
  @override
  final DateTime start;

  final String? _id;

  @override
  String? name;

  @override
  Uint8List? localImage;

  @override
  WorkoutImage? remoteImage;

  _Workout({
    required this.start,
    this.name,
    String? id,
    List<WorkoutExercise>? exercises,
    this.end,
    this.remoteImage,
    this.localImage,
  }) : _sets = exercises ?? <WorkoutExercise>[],
       _id = id;

  factory _Workout.fromJson(Map json, ExerciseLookup lookForExercise) {
    return _Workout(
      start: DateTime.parse(json['start']),
      name: json['name'],
      id: json['id'],
      end: DateTime.tryParse(json['end'] ?? ''),
      exercises: _exercisesFromCollection(json['exercises'], lookForExercise),
      remoteImage: switch (json) {
        {'images': List l} when l.isNotEmpty => WorkoutImage.fromJson(l.first),
        {'image': Map m} => WorkoutImage.fromJson(m), // from SQLite
        _ => null,
      },
    );
  }

  @override
  DateTime? end;

  @override
  String get id => _id ?? super.id;

  @override
  void finish(DateTime end) {
    this.end = end;
  }

  @override
  Iterable<WorkoutExercise> get sets => _sets;

  @override
  bool remove(WorkoutExercise exercise) {
    return _sets.remove(exercise);
  }

  @override
  Iterator<WorkoutExercise> get iterator => _sets.iterator;

  @override
  Map<String, dynamic> toMap() {
    var l = toList();
    return {
      'id': id,
      'name': name,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'image': ?remoteImage,
      'exercises': [
        for (var each in l)
          if (each.isNotEmpty)
            {
              ...each.toMap(),
              'order': l.indexOf(each),
            },
      ],
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
  WorkoutExercise add(Exercise exercise) {
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
      },
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
  Workout copy({bool sameId = false}) {
    final workout = _Workout(
      name: name,
      start: sameId ? start : DateTime.timestamp(),
      remoteImage: remoteImage,
      localImage: localImage,
    );

    for (final each in this) {
      if (each.isNotEmpty) {
        final exercise = WorkoutExercise(starter: each.first.copy());

        for (var (index, set) in each.skip(1).indexed) {
          final start = DateTime.timestamp().add(Duration(milliseconds: 2 * index));
          exercise.add(set.copy(start: start));
        }

        workout.append(exercise);
      }
    }

    if (end case DateTime dt) {
      workout.finish(dt);
    }

    return workout;
  }

  @override
  void completeAllSets() {
    for (var each in this) {
      for (var set in each) {
        set.isCompleted = true;
      }
    }
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

List<WorkoutExercise> _exercisesFromCollection(dynamic collection, ExerciseLookup lookForExercise) {
  WorkoutExercise? parse(dynamic each) {
    final exercise = lookForExercise(each['exercise']);
    if (exercise == null) return null;
    return _WorkoutExercise._(
      exercise: exercise,
      start: DateTime.parse(each['id']),
      sets: switch (each['sets']) {
        List sets => sets.map((set) => ExerciseSet.fromJson(exercise, set)).toList()..sort(),
        Map sets => sets.values.map((set) => ExerciseSet.fromJson(exercise, set)).toList()..sort(),
        null => [],
        _ => null,
      },
    )..order = each['order'];
  }

  return switch (collection) {
    List l => l.map(parse).nonNulls.toList()..sort(),
    Map m => m.values.map(parse).nonNulls.toList()..sort(),
    String s => _exercisesFromCollection(jsonDecode(s), lookForExercise),
    _ => <WorkoutExercise>[],
  };
}

abstract interface class ProgressGalleryResponse {
  List<WorkoutImage> get images;

  String? get cursor;

  factory ProgressGalleryResponse.fromJson(Map json) = _ProgressGalleryResponse.fromJson;
}

class _ProgressGalleryResponse implements ProgressGalleryResponse {
  @override
  final List<WorkoutImage> images;
  @override
  final String? cursor;

  const _ProgressGalleryResponse({
    required this.images,
    required this.cursor,
  });

  factory _ProgressGalleryResponse.fromJson(Map json) {
    return _ProgressGalleryResponse(
      images: switch (json) {
        {'images': List images} => images.map((each) => WorkoutImage.fromJson(each)).toList(),
        _ => [],
      },
      cursor: json['cursor'],
    );
  }
}
