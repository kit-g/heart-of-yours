import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/remote_failures.dart';
import 'package:heart_api/heart_api.dart' show NetworkException, UnreadableAnswer;
import 'package:heart_state/heart_state.dart' show RemoteFailure;
import 'package:http/http.dart' as http;

/// The one reading of a failure every notifier is handed (#681).
void main() {
  NetworkException failed(int status) => NetworkException(statusCode: status, method: 'GET', path: '/v1/goals');

  test('a 404 is gone, named or not', () {
    expect(remoteFailure(failed(404)), RemoteFailure.gone);
  });

  test('a server error, a throttle or a timeout may pass', () {
    for (final status in [408, 425, 429, 500, 502, 503]) {
      expect(remoteFailure(failed(status)), RemoteFailure.transient, reason: '$status');
    }
  });

  test("a gateway's 4xx with no code, a failed reauth and an unreadable 2xx are answers", () {
    for (final status in [400, 401, 403, 413]) {
      expect(remoteFailure(failed(status)), RemoteFailure.answered, reason: '$status');
    }
    expect(
      remoteFailure(const UnreadableAnswer(statusCode: 200, method: 'GET', path: '/v1/goals')),
      RemoteFailure.answered,
    );
  });

  test('no answer at all is unanswered', () {
    expect(remoteFailure(http.ClientException('Connection closed')), RemoteFailure.unanswered);
  });
}
