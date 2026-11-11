import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [CoachLibraryService] [CoachLibrary] wants (#557),
/// as `RemoteRoster` does for the roster.
class RemoteCoachLibrary implements CoachLibraryService {
  final Api _api;

  const new(this._api);

  @override
  Future<({List<CoachProgram> items, String? cursor})> getLibraryPrograms({String? cursor}) {
    return _api.getLibraryPrograms(cursor: cursor);
  }

  @override
  Future<CoachProgram> getLibraryProgram(String programId) => _api.getLibraryProgram(programId);

  @override
  Future<CoachProgram> saveLibraryProgram(String programId, Map<String, dynamic> body) {
    return _api.saveLibraryProgram(programId, body);
  }

  @override
  Future<void> deleteLibraryProgram(String programId) => _api.deleteLibraryProgram(programId);

  @override
  Future<List<CoachProgramHolder>> getLibraryHolders(String programId) => _api.getLibraryHolders(programId);

  @override
  Future<List<ProgramDelivery>> sendLibraryProgram(String programId, Iterable<String> connectionIds) {
    return _api.sendLibraryProgram(programId, connectionIds);
  }
}
