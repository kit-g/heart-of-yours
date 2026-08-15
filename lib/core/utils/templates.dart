import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalTemplateFolderService] the [Templates]
/// notifier wants.
///
/// Pure delegation, for the same reason `LocalGoals` exists: `heart_state`
/// depends on interfaces rather than on `heart_db`, and this one cannot live in
/// `heart_models` — that package is the server's, and mirroring folders locally
/// is bookkeeping the server has no notion of. The app is the one place that
/// sees both packages at once, so it does the joining.
class LocalTemplateFolders implements LocalTemplateFolderService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<Iterable<TemplateFolder>> getFolders(String userId) => _db.getTemplateFolders(userId);

  @override
  Future<void> storeFolders(Iterable<TemplateFolder> folders, String userId) {
    return _db.storeTemplateFolders(folders, userId: userId);
  }

  @override
  Future<void> storeFolder(TemplateFolder folder, String userId) {
    return _db.storeTemplateFolder(folder, userId: userId);
  }

  @override
  Future<void> deleteFolder(String folderId, String userId) {
    return _db.deleteTemplateFolder(folderId, userId: userId);
  }
}

/// Presents [Api] as the [RemoteTemplateFilingService] the [Templates] notifier
/// wants — the folder CRUD travels as [ApiTemplateFolderService], which [Api]
/// implements itself, and this carries the one call that interface lacks.
class RemoteTemplateFiling implements RemoteTemplateFilingService {
  final Api _api;

  const new(this._api);

  @override
  Future<Template> moveTemplate(Template template, {required String? folderId}) {
    return _api.moveTemplate(template, folderId: folderId);
  }
}
