import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/headers.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Cdn] as the [ExerciseLibraryService] the [Exercises] notifier
/// wants.
///
/// Pure delegation, for the same reason `RemoteTemplateFiling` exists:
/// `heart_state` depends on interfaces, and this one cannot live in
/// `heart_models` — the library's manifest and freshness stamp are a client
/// concern the server has no model for. The record types on both sides are
/// the same shape, so nothing is translated.
class CdnExerciseLibrary implements ExerciseLibraryService {
  final Cdn _cdn;

  const new(this._cdn);

  @override
  Future<(CatalogLibrary?, CatalogStamp)> getLibrary({CatalogStamp? cached}) {
    return _cdn.getExerciseLibrary(cached: cached);
  }
}

/// Presents [Api] as the [RemoteExercisePreferenceService] the [Exercises]
/// notifier wants — the exercise CRUD travels as `RemoteExerciseService`,
/// which [Api] implements itself, and this carries the one read that
/// server-shared interface cannot grow.
class RemoteExercisePreferences implements RemoteExercisePreferenceService {
  final Api _api;

  const new(this._api);

  @override
  Future<Iterable<ExercisePreference>> getExercisePreferences() {
    return _api.getExercisePreferences();
  }
}

/// [Api.renameExercise] as the notifier asks for it (#616).
class RemoteExerciseRenames implements RemoteExerciseRenameService {
  final Api _api;

  const new(this._api);

  @override
  Future<Exercise> renameExercise(Exercise exercise) => _api.renameExercise(exercise);

  @override
  bool isNameTaken(Object error) => error is ExerciseNameTaken;
}

/// The mirror's mark on an own exercise whose edit the account has not had
/// (#616), as the notifier asks for it.
class UnsentExerciseEdits implements UnsentExerciseEditService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<Map<String, UnsentExerciseEdit>> read(String userId) async {
    return {
      for (final MapEntry(key: id, value: renamed) in (await _db.getUnsentExerciseEdits(userId)).entries)
        id: renamed ? .renamed : .named,
    };
  }

  @override
  Future<void> mark(String exerciseId, String userId, UnsentExerciseEdit? edit) {
    return _db.setExerciseEditUnsent(exerciseId, userId, unsent: edit != null, renamed: edit == .renamed);
  }
}

/// Local pins and their account copy share the same adapter during replay.
class ExerciseNotes implements ExerciseNoteService {
  final LocalDatabase _db;
  final Api _api;

  const new(this._db, this._api);

  @override
  Future<Map<String, String>> read(String userId) => _db.getExerciseNotes(userId);

  @override
  Future<void> store(String exerciseId, String userId, String? note, {bool pending = false}) =>
      _db.setExerciseNote(exerciseId, userId, note, pending: pending);

  @override
  Future<void> sync(String exerciseId, String? note) => _api.setExerciseNote(exerciseId, note);
}

/// The account's move and the mirror's copy of it (#338), like [ExerciseNotes]:
/// the server answers, and the device re-keys its rows the way the answer says.
class ExerciseMoves implements ExerciseMoveService {
  final LocalDatabase _db;
  final Api _api;

  const new(this._db, this._api);

  @override
  Future<ExerciseMoveReport> move(String sourceId, String targetId, {bool dryRun = false}) {
    return _api.moveExerciseHistory(sourceId, targetId: targetId, dryRun: dryRun);
  }

  @override
  Future<void> mirror(ExerciseMoveReport report, {required String userId}) {
    return _db.moveExerciseHistory(
      sourceId: report.sourceId,
      targetId: report.targetId,
      userId: userId,
      deleteSource: report.sourceDeleted,
    );
  }
}

/// Presents [LocalDatabase] as the [LocalCatalogService] the [Exercises]
/// notifier wants — the catalog rows travel as `ExerciseService`, which the
/// database implements itself, and this carries the stamp that interface
/// cannot.
class LocalCatalog implements LocalCatalogService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<CatalogStamp?> getCatalogStamp() => _db.getCatalogStamp();

  @override
  Future<void> storeCatalog(Iterable<Exercise> exercises, {required CatalogStamp stamp, SearchGlossary? glossary}) {
    return _db.storeExercises(
      exercises,
      locale: stamp.locale,
      version: stamp.version,
      etag: stamp.etag,
      glossary: glossary?.toMap(),
    );
  }

  @override
  Future<SearchGlossary?> getSearchGlossary() async {
    return switch (await _db.getSearchGlossary()) {
      Map<String, dynamic> json => SearchGlossary.fromJson(json),
      null => null,
    };
  }
}

/// Exercises in the account's own History or templates that the device's
/// catalog has no copy of, so they show the server's name, which for a
/// library exercise is English (#612). Counts and the language only: nothing
/// about which exercises, or whose.
class const UnnamedExercises(final int unnamed, final int of, final String locale) implements Exception {
  @override
  String toString() => 'UnnamedExercises: $unnamed of $of exercises left with the server\'s name ($locale)';
}

bool _unnamedReported = false;

/// Reports [UnnamedExercises] once per run: every page of History would
/// otherwise report the same gap again. Once is enough to say the catalog
/// and the server disagree on this device; how often is Sentry's count of
/// devices, not of pages.
void reportUnnamedExercises(int unnamed, int of) {
  if (_unnamedReported) return;
  _unnamedReported = true;
  reportToSentry(UnnamedExercises(unnamed, of, languageTag()), stacktrace: StackTrace.current);
}
