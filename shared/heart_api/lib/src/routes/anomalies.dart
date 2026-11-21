part of '../api.dart';

/// Suspicious entries (#428, heart-api#42).
mixin _AnomalyRoutes on Requests, _ExerciseNaming implements AnomalyService {
  /// One page of the account's suspicious entries (#428, heart-api#42),
  /// newest found first. [userId] is the token's: the route reads no other.
  /// An anomaly this build cannot read is left out of the page rather than
  /// failing it, and a reason it does not know is read as it came.
  @override
  Future<Page<Anomaly>> getAnomalies({
    required String userId,
    AnomalyStatus? status,
    String? cursor,
    int limit = 100,
  }) async {
    final (anomalies, page) = await _listAt(
      Router.anomalies,
      'anomalies',
      query: {'limit': '$limit', 'cursor': ?cursor, 'status': ?status?.value},
    );
    return Page(
      items: _readable(anomalies, (each) => Anomaly.fromJson(_namedAnomaly(each))),
      hasMore: page['cursor'] != null,
    );
  }

  /// What the user made of one anomaly, replacing an earlier decision. Null
  /// when the server has no such anomaly: the next sweep forgot it.
  @override
  Future<Anomaly?> resolveAnomaly({
    required String userId,
    required String anomalyId,
    required AnomalyStatus status,
  }) async {
    try {
      final (json, _) = await put(Router.anomaly(anomalyId), body: {'status': status.value});
      return Anomaly.fromJson(_namedAnomaly(json));
    } on Exception catch (error) {
      if (_gone(error)) return null;
      rethrow;
    }
  }
}
