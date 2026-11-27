import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [LocalAnomalyService] the [Anomalies]
/// notifier wants (#428) — the same joining [LocalStats] does, for the same
/// reason: the app is the one place that sees `heart_db` and `heart_state` at
/// once.
class LocalAnomalies implements LocalAnomalyService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<List<Anomaly>> getAnomalies(String userId) => _db.getAnomalies(userId);

  @override
  Future<List<Anomaly>> unsyncedAnomalies(String userId) => _db.unsyncedAnomalies(userId);

  @override
  Future<void> storeAnomalies(Iterable<Anomaly> anomalies, String userId) => _db.storeAnomalies(anomalies, userId);

  @override
  Future<void> storeAnomaly(Anomaly anomaly, String userId) => _db.storeAnomaly(anomaly, userId);

  @override
  Future<void> resolveAnomaly(String anomalyId, AnomalyStatus status, {required DateTime at}) {
    return _db.resolveAnomaly(anomalyId, status, at: at);
  }
}
