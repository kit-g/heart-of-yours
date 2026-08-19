/// The workout-history import endpoint: what it accepts and what it reports.
library;

/// A third-party app whose export the server can ingest.
///
/// The server rejects anything else with a 400. Hevy is a planned follow-up
/// and becomes a new value here when it ships — nothing else changes.
enum ImportSource { strong }

/// The import endpoint's 400: the file was not a readable export.
///
/// [reason] is the server's developer-grade explanation — detail text for the
/// curious, never the headline.
class ImportRejected implements Exception {
  final String? reason;

  const new({this.reason});

  @override
  String toString() => 'ImportRejected(${reason ?? 'no reason given'})';
}

/// The server's tally of one import run.
///
/// Nothing from the export is dropped: every workout is either created or
/// skipped as already imported, and every exercise name either matched the
/// catalog or was created as one of the user's custom exercises. Only
/// [rowsSkipped] counts data that could not be read at all.
class WorkoutImportReport {
  final int workoutsFound;
  final int workoutsCreated;

  /// Already imported earlier — the import is idempotent, so re-uploading the
  /// same file lands here instead of duplicating.
  final int workoutsSkipped;
  final int setsCreated;
  final int exercisesMatched;

  /// Export names that matched nothing in the catalog or the user's customs
  /// and were created as the user's custom exercises.
  final List<String> exercisesCreated;

  /// Malformed rows the parser could not repair.
  final int rowsSkipped;

  const new({
    required this.workoutsFound,
    required this.workoutsCreated,
    required this.workoutsSkipped,
    required this.setsCreated,
    required this.exercisesMatched,
    required this.exercisesCreated,
    required this.rowsSkipped,
  });

  factory fromJson(Map json) {
    int count(String field) {
      return switch (json[field]) {
        num n => n.toInt(),
        _ => 0,
      };
    }

    return WorkoutImportReport(
      workoutsFound: count('workoutsFound'),
      workoutsCreated: count('workoutsCreated'),
      workoutsSkipped: count('workoutsSkipped'),
      setsCreated: count('setsCreated'),
      exercisesMatched: count('exercisesMatched'),
      exercisesCreated: switch (json['exercisesCreated']) {
        List l => l.map((each) => each.toString()).toList(),
        _ => const [],
      },
      rowsSkipped: count('rowsSkipped'),
    );
  }
}
