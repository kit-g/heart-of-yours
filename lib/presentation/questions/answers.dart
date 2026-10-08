import 'package:heart/core/utils/records.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

/// What the assistant asks about a person's training (#288), answered in
/// sentences from the device's own mirror: the app's queries, the app's copy,
/// the app's units. Training data only: nothing here reads the device's
/// medical store, and a test holds it to that, since an assistant's answer may
/// be processed off the device.
///
/// Built for the headless engine the intents run (`questionsMain` in
/// main.dart), so it takes its collaborators rather than reading them from a
/// widget tree.
class Answers {
  final LocalDatabase db;
  final L l;
  final Preferences prefs;
  final DateTime Function() now;

  const new({required this.db, required this.l, required this.prefs, DateTime Function()? now})
    : now = now ?? DateTime.now;

  /// "Your Bench Press record is 100 kg × 5, set on Oct 3": the headline
  /// record for [exerciseId], by what its category measures — the heaviest
  /// set, the longest distance, the most reps.
  Future<String> record(String? userId, String exerciseId) async {
    if (userId == null) return l.askNoWorkouts;
    final exercise = await _exercise(userId, exerciseId);
    if (exercise == null) return l.askUnknownExercise;
    final records = await db.getRecord(userId, exercise);
    final formats = RecordFormats(l: l, prefs: prefs, unit: null, category: exercise.category);
    for (final kind in RecordKind.values) {
      if (records?[kind.key] case Map record) {
        return l.askRecord(exercise.name, _described(formats, kind, record), _date(record['at']));
      }
    }
    return l.askNoRecord(exercise.name);
  }

  /// "You last did Bench Press on Oct 3, in Push day".
  Future<String> lastExercise(String? userId, String exerciseId) async {
    if (userId == null) return l.askNoWorkouts;
    final exercise = await _exercise(userId, exerciseId);
    if (exercise == null) return l.askUnknownExercise;
    final acts = await db.getExerciseHistory(userId, exercise);
    final latest = acts
        .where((act) => act.start != null)
        .fold<ExerciseAct?>(
          null,
          (best, act) => best == null || act.start!.isAfter(best.start!) ? act : best,
        );
    return switch (latest) {
      ExerciseAct(start: DateTime start, :final workoutName) => l.askLastExercise(
        exercise.name,
        _date(start),
        workoutName ?? l.workout,
      ),
      _ => l.askNeverDid(exercise.name),
    };
  }

  /// "You last did Push day on Oct 3": the last finished workout that took
  /// [template]'s name, which is what a workout started from a template keeps.
  Future<String> lastTemplate(String? userId, String template) async {
    if (userId == null) return l.askNoWorkouts;
    final history = await db.getWorkoutHistory(userId) ?? const <Workout>[];
    final latest = history
        .where((workout) => workout.end != null && workout.name == template)
        .fold<Workout?>(null, (best, workout) => best == null || workout.start.isAfter(best.start) ? workout : best);
    return switch (latest) {
      Workout(:final start) => l.askLastTemplate(template, _date(start)),
      null => l.askNeverDidTemplate(template),
    };
  }

  /// "3 workouts this week".
  Future<String> weekly(String? userId) async {
    if (userId == null) return l.askNoWorkouts;
    final count = await db.getWeeklyWorkoutCount(now(), userId: userId);
    return l.askWeekly(count);
  }

  Future<Exercise?> _exercise(String userId, String id) async {
    final (_, catalog) = await db.getExercises(userId: userId);
    return catalog.where((exercise) => exercise.id == id).firstOrNull;
  }

  /// The record as a set reads: "100 kg × 5" for a weight with its reps, else
  /// the value alone.
  String _described(RecordFormats formats, RecordKind kind, Map record) {
    final value = formats.value(kind, record);
    return switch ((kind, record['reps'])) {
      (.maxWeight, num reps) when reps > 0 => l.weightedSetRepresentation(value, reps.toInt()),
      _ => value,
    };
  }

  String _date(Object? at) {
    final parsed = switch (at) {
      DateTime at => at,
      String at => DateTime.tryParse(at),
      _ => null,
    };
    return switch (parsed) {
      DateTime at => DateFormat.yMMMd(l.localeName).format(at.toLocal()),
      null => '',
    };
  }
}
