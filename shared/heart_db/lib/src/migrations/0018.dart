part of '../../heart_db.dart';

/// The library's search vocabulary (#135): each exercise's aliases in the
/// served locale (`ohp`, `rdl`), and the locale's glossary of abbreviations
/// and muscle words beside the catalog stamp it came with.
const addExerciseAliases = 'ALTER TABLE exercises ADD COLUMN aliases TEXT';
const addCatalogGlossary = 'ALTER TABLE syncs ADD COLUMN glossary TEXT';

/// The cached rows predate aliases, but their stamp still matches the CDN,
/// and a matching stamp means no download. Dropping it makes the next launch
/// fetch the whole file once, aliases and glossary included. The rows stay:
/// they are what an offline launch has.
const invalidateCatalogStamp = "UPDATE syncs SET version = NULL, etag = NULL WHERE table_name = 'exercises'";
