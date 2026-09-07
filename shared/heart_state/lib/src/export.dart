import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'templates.dart';

/// The layout of the JSON envelope — its top-level keys and what each holds.
/// Not the shapes inside it: those are `heart_models`' own wire shapes and
/// carry no version. Bump when a key is added, renamed or changes meaning.
///
/// `2`: a workout's or template's `exercise` is the exercise's name rather than
/// a copy of its catalog row (heart-of-yours#113).
const exportSchemaVersion = 2;

/// What the local store holds for one user, read once and written as many
/// times as asked.
///
/// The store, not the server, on purpose: an export costs nothing and works
/// offline, and for a session without an account the mirror is all there is.
/// A signed-in user gets what has been paged down — the page says so.
///
/// Health data is never part of this. Nothing here reads the health tables,
/// and the two derived fields the models carry ([Workout.calories],
/// [WorkoutExercise.met]) are dropped on the way out — see
/// `docs/2026-09-05.health-data.md`, *Where it must never go*.
class ExportSnapshot {
  /// Finished workouts, oldest first.
  final List<Workout> workouts;

  final List<Template> templates;

  final List<TemplateFolder> folders;

  /// The user's own exercises; the library is the CDN's and not theirs to keep.
  final List<Exercise> exercises;

  final MeasurementUnit weightUnit;

  final MeasurementUnit distanceUnit;

  /// Per-exercise overrides of the two above, by exercise id.
  final Map<ExerciseId, MeasurementUnit> exerciseUnits;

  /// Live goals first, then the achieved ones.
  final List<Goal> goals;

  new({
    required Iterable<Workout> workouts,
    required Iterable<Template> templates,
    required Iterable<TemplateFolder> folders,
    required Iterable<Exercise> exercises,
    required this.weightUnit,
    required this.distanceUnit,
    required Map<ExerciseId, MeasurementUnit> exerciseUnits,
    required Iterable<Goal> goals,
  }) : workouts = workouts.where((each) => each.isCompleted).toList()..sort(_byStart),
       templates = templates.toList()..sort(),
       folders = folders.toList()..sort(),
       exercises = exercises.toList()..sort(_byName),
       // sorted keys: two exports of the same store are the same bytes
       exerciseUnits = SplayTreeMap.of(exerciseUnits),
       goals = goals.toList();

  /// Everything, as one envelope around the models' wire shapes.
  String toJson({required DateTime exportedAt}) {
    final envelope = {
      'schemaVersion': exportSchemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'units': {
        'weight': weightUnit.name,
        'distance': distanceUnit.name,
        'exercises': {
          for (final MapEntry(:key, :value) in exerciseUnits.entries) key: value.name,
        },
      },
      'workouts': workouts.map(_workoutJson).toList(),
      'templates': templates.map(_templateJson).toList(),
      'folders': folders.map((each) => each.toMap()).toList(),
      'exercises': exercises.map((each) => each.toMap()).toList(),
      'goals': goals.map((each) => each.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Workouts only, one row per set, flat enough for a spreadsheet.
  ///
  /// Weights and distances are in the unit the user sees them in — the
  /// exercise's own override, else the global setting — and the `unit` column
  /// names it. RFC 4180 quoting, LF line ends, no trailing newline games: the
  /// header row and one row per set, each ending in `\n`.
  String toCsv() {
    final rows = [
      _csvColumns,
      for (final workout in workouts)
        for (final exercise in workout)
          for (final (index, set) in exercise.indexed) _csvRow(workout, exercise, index + 1, set),
    ];
    return rows.map((row) => row.map(_csvField).join(',')).map((line) => '$line\n').join();
  }

  static const _csvColumns = [
    'workout_id',
    'start',
    'end',
    'exercise_id',
    'exercise_name',
    'set_index',
    'weight',
    'unit',
    'reps',
    'duration',
    'distance',
    'notes',
  ];

  List<String> _csvRow(Workout workout, WorkoutExercise exercise, int index, ExerciseSet set) {
    final ExerciseSet(:weight, :reps, :duration, :distance) = set;
    final id = exercise.exercise.id;
    final weightUnit = exerciseUnits[id] ?? this.weightUnit;
    final distanceUnit = exerciseUnits[id] ?? this.distanceUnit;
    // a set measures weight or distance, never both — one column names
    // whichever unit the row carries
    final unit = switch ((weight, distance)) {
      (double _, _) => _weightUnit(weightUnit),
      (null, double _) => _distanceUnit(distanceUnit),
      (null, null) => '',
    };

    return [
      workout.id,
      _instant(workout.start),
      _instant(workout.end),
      id,
      exercise.exercise.name,
      '$index',
      _measure(weight, (value) => _weight(value, weightUnit)),
      unit,
      _measure(reps, (value) => value),
      _measure(duration, (value) => value),
      _measure(distance, (value) => _distance(value, distanceUnit)),
      exercise.note ?? '',
    ];
  }
}

/// Gathers an [ExportSnapshot] from the local store.
class DataExport {
  final WorkoutService _workouts;
  final TemplateService _templates;
  final LocalTemplateFolderService _folders;
  final ExerciseService _exercises;
  final GoalService _goals;

  const new({
    required this._workouts,
    required this._templates,
    required this._folders,
    required this._exercises,
    required this._goals,
  });

  static DataExport of(BuildContext context) {
    return Provider.of<DataExport>(context, listen: false);
  }

  /// Everything the store holds under [userId].
  ///
  /// The global units are the device's preferences, which live outside the
  /// store; the caller passes them in.
  Future<ExportSnapshot> read(
    String userId, {
    required MeasurementUnit weightUnit,
    required MeasurementUnit distanceUnit,
  }) async {
    final (_, exercises) = await _exercises.getExercises(userId: userId);
    // the store answers one slice at a time, never the union
    final live = await _goals.getTargetUserGoals(requesterId: userId, targetUserId: userId);
    final achieved = await _goals.getTargetUserGoals(requesterId: userId, targetUserId: userId, archived: true);

    return ExportSnapshot(
      workouts: await _workouts.getWorkoutHistory(userId) ?? const [],
      templates: await _templates.getTemplates(userId),
      folders: await _folders.getFolders(userId),
      exercises: exercises.where((each) => each.isMine),
      weightUnit: weightUnit,
      distanceUnit: distanceUnit,
      exerciseUnits: await _exercises.getExerciseUnits(userId),
      goals: [...live, ...achieved],
    );
  }
}

int _byStart(Workout a, Workout b) {
  return switch (a.start.compareTo(b.start)) {
    0 => a.id.compareTo(b.id),
    final byStart => byStart,
  };
}

int _byName(Exercise a, Exercise b) {
  return switch (a.compareTo(b)) {
    0 => a.id.compareTo(b.id),
    final byName => byName,
  };
}

/// The wire shape, minus the field the health contract keeps off every wire.
Map<String, dynamic> _workoutJson(Workout workout) {
  final map = workout.toMap()..remove('calories');
  return map..['exercises'] = _exercisesJson(map['exercises'] as List);
}

Map<String, dynamic> _templateJson(Template template) {
  final map = template.toMap();
  return map..['exercises'] = _exercisesJson(map['exercises'] as List);
}

/// The mirror keeps no timestamp on an exercise or a set, and the models fill
/// the gap with the moment they were read — a fact about the export, not the
/// workout, so it goes. `met` goes for the same reason as `calories`.
///
/// The exercise each entry names is written as its **name** and nothing else.
///
/// A workout's wire shape carries the whole [Exercise]: instructions, both
/// asset links with their dimensions, muscle tagging, movement and health
/// classification. Written once per exercise per workout, that is the same
/// library row repeated thousands of times — an account of 568 workouts
/// exported to **11.2 MB**, nearly all of it catalog.
///
/// None of it is the user's to begin with. The library belongs to the CDN and
/// the export promises "custom exercises", not the catalog; the id is the
/// catalog's key and means nothing outside this app; and the name is already
/// the localized display copy, which is the only part of an exercise a person
/// reading their own file is looking for. A custom of theirs keeps everything
/// it has, in the envelope's own `exercises` list.
List<Map<String, dynamic>> _exercisesJson(List exercises) {
  return [
    for (final exercise in exercises.cast<Map<String, dynamic>>())
      {...exercise}
        ..remove('start')
        ..remove('met')
        ..['exercise'] = (exercise['exercise'] as Map<String, dynamic>)['name']
        ..['sets'] = [
          for (final set in (exercise['sets'] as List).cast<Map<String, dynamic>>()) {...set}..remove('started_at'),
        ],
  ];
}

String _instant(DateTime? at) => at?.toUtc().toIso8601String() ?? '';

String _measure<T extends num>(T? value, num Function(T) convert) {
  return switch (value) {
    T v => _number(convert(v)),
    null => '',
  };
}

double _weight(double kilograms, MeasurementUnit unit) {
  return switch (unit) {
    .imperial => kilograms.asPounds,
    .metric => kilograms,
  };
}

double _distance(double kilometers, MeasurementUnit unit) {
  return switch (unit) {
    .imperial => kilometers.asMiles,
    .metric => kilometers,
  };
}

String _weightUnit(MeasurementUnit unit) {
  return switch (unit) {
    .imperial => 'lb',
    .metric => 'kg',
  };
}

String _distanceUnit(MeasurementUnit unit) {
  return switch (unit) {
    .imperial => 'mi',
    .metric => 'km',
  };
}

/// Two decimals at most, no trailing zeros: a converted 60 kg is `132.28`,
/// not `132.27735731100002`, and an exact 60 stays `60`.
String _number(num value) {
  final rounded = (value * 100).round() / 100;
  return switch (rounded == rounded.truncateToDouble()) {
    true => rounded.toInt().toString(),
    false => rounded.toString(),
  };
}

/// RFC 4180: a field holding a comma, a quote or a line break is quoted, with
/// its quotes doubled.
String _csvField(String value) {
  return switch (value.contains(_needsQuoting)) {
    true => '"${value.replaceAll('"', '""')}"',
    false => value,
  };
}

final _needsQuoting = RegExp(r'[",\r\n]');
