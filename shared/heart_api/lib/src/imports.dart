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

/// What an import *would* do — the `dryRun=true` response.
///
/// Nothing is written on the server. The interesting half is
/// [exercisesUnmatched]: the names that would become the user's custom
/// exercises, each with the number of sets that ride on it — the input for
/// the "bring these over as your own?" consent step.
class WorkoutImportPreview {
  final int workoutsFound;

  /// Already in the user's history — a commit would skip these.
  final int workoutsAlreadyImported;
  final int setsFound;
  final int exercisesMatched;

  /// Names with no catalog or custom counterpart, with what declining each
  /// would cost, in export order.
  final List<({String name, int sets})> exercisesUnmatched;

  /// Malformed rows the parser could not repair.
  final int rowsSkipped;

  const new({
    required this.workoutsFound,
    required this.workoutsAlreadyImported,
    required this.setsFound,
    required this.exercisesMatched,
    required this.exercisesUnmatched,
    required this.rowsSkipped,
  });

  factory fromJson(Map json) {
    return WorkoutImportPreview(
      workoutsFound: _count(json, 'workoutsFound'),
      workoutsAlreadyImported: _count(json, 'workoutsAlreadyImported'),
      setsFound: _count(json, 'setsFound'),
      exercisesMatched: _count(json, 'exercisesMatched'),
      exercisesUnmatched: switch (json['exercisesUnmatched']) {
        List l => [
          for (final each in l)
            if (each case {'name': String name}) (name: name, sets: _count(each, 'sets')),
        ],
        _ => const [],
      },
      rowsSkipped: _count(json, 'rowsSkipped'),
    );
  }
}

/// The server's tally of one import run.
///
/// Nothing from the export vanishes silently: every workout is either created
/// or skipped as already imported, and every exercise name either matched the
/// catalog, was created as one of the user's custom exercises, or was
/// declined by the user — with the sets that cost counted in [setsSkipped].
/// Only [rowsSkipped] counts data that could not be read at all.
class WorkoutImportReport {
  final int workoutsFound;
  final int workoutsCreated;

  /// Already imported earlier — the import is idempotent, so re-uploading the
  /// same file lands here instead of duplicating.
  final int workoutsSkipped;
  final int setsCreated;

  /// Sets left out because the user declined their unmatched exercise.
  final int setsSkipped;
  final int exercisesMatched;

  /// Export names that matched nothing in the catalog or the user's customs
  /// and were created as the user's custom exercises.
  final List<String> exercisesCreated;

  /// Unmatched names the user declined to create.
  final List<String> exercisesSkipped;

  /// Malformed rows the parser could not repair.
  final int rowsSkipped;

  const new({
    required this.workoutsFound,
    required this.workoutsCreated,
    required this.workoutsSkipped,
    required this.setsCreated,
    required this.setsSkipped,
    required this.exercisesMatched,
    required this.exercisesCreated,
    required this.exercisesSkipped,
    required this.rowsSkipped,
  });

  factory fromJson(Map json) {
    return WorkoutImportReport(
      workoutsFound: _count(json, 'workoutsFound'),
      workoutsCreated: _count(json, 'workoutsCreated'),
      workoutsSkipped: _count(json, 'workoutsSkipped'),
      setsCreated: _count(json, 'setsCreated'),
      setsSkipped: _count(json, 'setsSkipped'),
      exercisesMatched: _count(json, 'exercisesMatched'),
      exercisesCreated: _strings(json, 'exercisesCreated'),
      exercisesSkipped: _strings(json, 'exercisesSkipped'),
      rowsSkipped: _count(json, 'rowsSkipped'),
    );
  }
}

int _count(Map json, String field) {
  return switch (json[field]) {
    num n => n.toInt(),
    _ => 0,
  };
}

List<String> _strings(Map json, String field) {
  return switch (json[field]) {
    List l => l.map((each) => each.toString()).toList(),
    _ => const [],
  };
}
