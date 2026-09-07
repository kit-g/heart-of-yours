part of '../../heart_db.dart';

/// v12: the catalog cache learns what it is a copy of.
///
/// The library now arrives from the CDN as one file per locale behind a
/// manifest (heart-api#65), and the manifest's `version` plus the file's ETag
/// are what let a launch skip the download when nothing changed. They live on
/// the `syncs` row beside `synced_at` and `locale` — written in the same
/// transaction as the rows they describe, so neither can outlive the other.
/// `locale` itself now records the locale *file* the rows came from (`es_ES`)
/// rather than the device tag: two regional tags that resolve to one file
/// share one copy, and the file is what the ETag vouches for.
const addSyncsVersion = '''
ALTER TABLE syncs ADD COLUMN version TEXT;
''';

const addSyncsEtag = '''
ALTER TABLE syncs ADD COLUMN etag TEXT;
''';
