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
  Future<(Iterable<Exercise>?, CatalogStamp)> getLibrary({CatalogStamp? cached}) {
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
  Future<void> storeCatalog(Iterable<Exercise> exercises, {required CatalogStamp stamp}) {
    return _db.storeExercises(exercises, locale: stamp.locale, version: stamp.version, etag: stamp.etag);
  }
}
