part of '../api.dart';

/// Suspicious entries (#428, heart-api#42).
mixin _AnomalyRoutes on Requests implements AnomalyService {
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
    final (json, code) = await get(
      Router.anomalies,
      query: {'limit': '$limit', 'cursor': ?cursor, 'status': ?status?.value},
    );
    return switch ((code, json)) {
      (200, {'anomalies': final List l}) => Page(
        items: _readable(l, Anomaly.fromJson),
        hasMore: json['cursor'] != null,
      ),
      _ => throw NetworkException(statusCode: code, body: json),
    };
  }

  /// What the user made of one anomaly, replacing an earlier decision. Null
  /// when the server has no such anomaly: the next sweep forgot it.
  @override
  Future<Anomaly?> resolveAnomaly({
    required String userId,
    required String anomalyId,
    required AnomalyStatus status,
  }) async {
    final (json, code) = await put(Router.anomaly(anomalyId), body: {'status': status.value});
    return switch ((code, json)) {
      (200, Map json) => Anomaly.fromJson(json),
      (404, _) => null,
      _ => throw NetworkException(statusCode: code, body: json),
    };
  }
}
