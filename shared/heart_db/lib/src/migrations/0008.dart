part of '../../heart_db.dart';

/// v8: template folders — the local mirror of the server's `template_folders`.
///
/// Shape follows the server table with SQLite's usual adjustments: `id` is
/// TEXT (a server-minted uuid — folders are created remote-first, so there is
/// no client-minted key to reconcile), and `created_at` is TEXT holding the
/// ISO timestamp the wire carries.
///
/// `templates.folder_id` is a bare column rather than a foreign key: SQLite
/// cannot add a constraint via ALTER TABLE, so "deleting a folder unfiles its
/// templates" is enforced in [_TemplateFolders] instead.
const templateFolders = '''
CREATE TABLE IF NOT EXISTS template_folders
(
    id          TEXT NOT NULL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    name        TEXT NOT NULL,
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT
);
''';

/// Every read is "this user's folders", same as the server's ownership scope.
const templateFoldersIndex = '''
CREATE INDEX IF NOT EXISTS template_folders_user_idx ON template_folders (user_id);
''';

const addTemplateFolderId = '''
ALTER TABLE templates ADD COLUMN folder_id TEXT;
''';
