import 'package:heart_api/src/api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:test/test.dart';

import 'support/http.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group('anomalies', () {
    Map<String, dynamic> anomaly(String id, {String reason = 'outlier_weight', String status = 'pending'}) {
      return {
        'id': id,
        'workoutId': 'w1',
        'setId': 's1',
        'exerciseId': 'bench',
        'exerciseName': 'Bench Press',
        'reason': reason,
        'observed': {'weight': 630, 'reps': 5},
        'typical': 100,
        'status': status,
        'detectedAt': '2026-10-17T03:37:00.000Z',
      };
    }

    test('a page reads every anomaly, a reason this build does not know included (#428)', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.anomalies,
        query: {'limit': 100},
        statusCode: 200,
        body: {
          'anomalies': [anomaly('a2', reason: 'duplicate_session'), anomaly('a1')],
          'cursor': 'a1',
        },
      );

      final page = await api.getAnomalies(userId: 'muffin');

      expect(page.map((each) => (each.id, each.reason)), [('a2', 'duplicate_session'), ('a1', 'outlier_weight')]);
      expect(page.hasMore, isTrue);
    });

    test('a decision goes up, and one the server forgot reads as none', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.anomaly('a1'),
        statusCode: 200,
        body: anomaly('a1', status: 'invalid'),
      );
      final resolved = await api.resolveAnomaly(userId: 'muffin', anomalyId: 'a1', status: .invalid);
      expect(resolved?.status, AnomalyStatus.invalid);

      respond(
        client: client,
        method: 'PUT',
        path: Router.anomaly('a2'),
        statusCode: 404,
        body: {'code': 'not_found'},
      );
      expect(await api.resolveAnomaly(userId: 'muffin', anomalyId: 'a2', status: .valid), isNull);
    });
  });
}
