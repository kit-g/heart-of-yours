import 'package:heart_state/heart_state.dart';

/// The device's memory of a rest in progress (#141), in the app's
/// preferences: three keys, written as a unit and read back as one, so a
/// rest survives the process being killed — in the app, and for a lock
/// screen that acts on it while the app is gone.
class PreferencesRestStore implements RestStore {
  static const _exerciseId = 'rest.exerciseId';
  static const _end = 'rest.end';
  static const _total = 'rest.total';

  const new();

  @override
  Future<SavedRest?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return switch ((prefs.getString(_exerciseId), prefs.getInt(_end), prefs.getInt(_total))) {
      (String exerciseId, int end, int total) => (
        exerciseId: exerciseId,
        end: DateTime.fromMillisecondsSinceEpoch(end),
        total: total,
      ),
      _ => null,
    };
  }

  @override
  Future<void> write(SavedRest rest) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_exerciseId, rest.exerciseId),
      prefs.setInt(_end, rest.end.millisecondsSinceEpoch),
      prefs.setInt(_total, rest.total),
    ]);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_exerciseId), prefs.remove(_end), prefs.remove(_total)]);
  }
}
