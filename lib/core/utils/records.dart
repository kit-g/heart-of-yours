import 'package:flutter/widgets.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

/// The headline records a set can hold, keyed into the map
/// `ExerciseService.getRecord` returns (see heart_db's fold for the shape).
/// Rep maxes stay out deliberately: on a first session every rep count is a
/// "record", and a celebration that lists twelve of them congratulates nobody.
enum RecordKind {
  maxWeight('heaviest'),
  oneRepMax('oneRepMax'),
  bestVolume('bestVolume'),
  mostReps('mostReps'),
  leastAssistance('lightestAssistance'),
  longestDistance('longestDistance'),
  longestDuration('longestDuration'),
  bestPace('bestPace');

  /// The record's key in the records map.
  final String key;

  new(this.key);
}

/// One record standing after a workout: which exercise, which kind, and the
/// record entry itself (value, set context, workoutId, at).
typedef AchievedRecord = ({Exercise exercise, RecordKind kind, Map record});

/// The records [workoutId] holds across every exercise in [workout].
///
/// Leans on the fold's tie-breaking: an equalled record stays credited to the
/// session that set it first, so matching `workoutId` means this session
/// genuinely beat everything before it (or performed the exercise for the
/// first time — a record too, just an easy one).
Future<List<AchievedRecord>> recordsSetBy(
  String workoutId,
  Workout workout, {
  required Future<Map?> Function(Exercise) lookup,
}) async {
  final seen = <String>{};
  final achieved = <AchievedRecord>[];

  for (final entry in workout) {
    final exercise = entry.exercise;
    if (!seen.add(exercise.id)) continue;

    final records = await lookup(exercise);
    if (records == null) continue;

    for (final kind in RecordKind.values) {
      if (records[kind.key] case Map record when record['workoutId'] == workoutId) {
        achieved.add((exercise: exercise, kind: kind, record: record));
      }
    }
  }

  return achieved;
}

/// Unit-aware rendering of record values, shared by the records tab and the
/// workout-done celebration.
class RecordFormats {
  final L l;
  final Preferences prefs;
  final MeasurementUnit? unit;

  const new({required this.l, required this.prefs, required this.unit});

  /// The record's value, formatted by its [kind].
  String value(RecordKind kind, Map record) {
    return switch (kind) {
      .maxWeight || .leastAssistance => weight(record['weight'] as num),
      .oneRepMax || .bestVolume => weight(record['value'] as num),
      .mostReps => '${(record['reps'] as num).toInt()}',
      .longestDistance => distance(record['distance'] as num),
      .longestDuration => time(record['duration'] as num),
      .bestPace => pace(record['pace'] as num),
    };
  }

  String weight(num value) {
    final suffix = switch (unit ?? prefs.weightUnit) {
      .imperial => l.lbs,
      .metric => l.kg,
    };
    return '${prefs.weight(value.toDouble(), unit: unit)} $suffix';
  }

  String distance(num value) {
    final suffix = switch (unit ?? prefs.distanceUnit) {
      .imperial => l.milesPlural,
      .metric => l.km,
    };
    return '${prefs.distance(value.toDouble(), unit: unit)} $suffix';
  }

  String time(num seconds) => _clock(Duration(seconds: seconds.round()));

  /// [secondsPerKm] → clock time per the display distance unit.
  String pace(num secondsPerKm) {
    final (seconds, suffix) = switch (unit ?? prefs.distanceUnit) {
      .imperial => (secondsPerKm * 1.609344, l.milesPlural),
      .metric => (secondsPerKm.toDouble(), l.km),
    };
    return '${_clock(Duration(seconds: seconds.round()))} / $suffix';
  }

  String date(String at) {
    return switch (DateTime.tryParse(at)) {
      DateTime parsed => DateFormat.yMMMd(l.localeName).format(parsed.toLocal()),
      null => '',
    };
  }

  String _clock(Duration elapsed) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final minutes = pad(elapsed.inMinutes.remainder(60));
    final seconds = pad(elapsed.inSeconds.remainder(60));
    return switch (elapsed.inHours) {
      > 0 => '${pad(elapsed.inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }
}

/// The label copy for a record kind — here rather than on the enum because
/// presentation owns copy; the enum carries identifiers only.
String recordKindLabel(BuildContext context, RecordKind kind) {
  final l = L.of(context);
  return switch (kind) {
    .maxWeight => l.maxWeight,
    .oneRepMax => l.estimatedOneRepMax,
    .bestVolume => l.bestSetVolume,
    .mostReps => l.mostReps,
    .leastAssistance => l.leastAssistance,
    .longestDistance => l.maxDistance,
    .longestDuration => l.maxDuration,
    .bestPace => l.bestPace,
  };
}
