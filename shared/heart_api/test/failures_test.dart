import 'package:heart_api/heart_api.dart';
import 'package:heart_api/src/api.dart' show Router;
import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:network_utils/network_utils.dart' show retryableByDefault;
import 'package:test/test.dart';

import 'support/http.dart';

/// How a failed request reaches a caller (#681): [Api.failure], in one place.
void main() {
  late MockClient client;
  late Api api;
  late List<Map<String, dynamic>> upgrades;

  setUp(() {
    client = MockClient();
    upgrades = [];
    api = Api(
      gateway: 'api.example.com',
      client: client,
      onUpgradeRequired: (json) {
        upgrades.add(json);
        return (json, 426);
      },
    );
  });

  /// [path] answering a GET with [body] exactly as written, JSON or not.
  void raw(String path, int statusCode, String body) {
    final uri = Uri.https('api.example.com', path);
    when(client.get(uri, headers: anyNamed('headers'))).thenAnswer(
      (_) async => StubResponse(body, statusCode, request: http.Request('GET', uri)),
    );
  }

  group('the order', () {
    test('a 426 is UpgradeRequired, coded or not, and the upgrade prompt still fires', () async {
      // a code the refusal would otherwise be read by: the upgrade comes first
      respond(
        client: client,
        method: 'GET',
        path: Router.accountSummary,
        statusCode: 426,
        body: {'code': 'upgrade_required'},
      );
      await expectLater(api.getAccountSummary(), throwsA(isA<UpgradeRequired>()));
      expect(upgrades, [
        {'code': 'upgrade_required'},
      ]);

      raw(Router.templates, 426, '');
      await expectLater(api.getTemplates(), throwsA(isA<UpgradeRequired>()));
      expect(upgrades, hasLength(2));
    });

    test('a deleted account is AccountDeleted, on any route, before it can be a refusal', () async {
      for (final path in [Router.accounts, Router.goals]) {
        respond(
          client: client,
          method: path == Router.accounts ? 'PUT' : 'POST',
          path: path,
          statusCode: 400,
          body: {'code': 'ACCOUNT_DELETED'},
        );
      }
      await expectLater(api.registerAccount(User(id: '42')), throwsA(isA<AccountDeleted>()));
      await expectLater(api.replayGoal(_goal), throwsA(isA<AccountDeleted>()));
    });

    test('an anonymous token is AnonymousSessionRejected, never a refusal', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 403,
        body: {'error': 'forbidden', 'code': 'anonymous_account'},
      );
      await expectLater(api.getTemplates(), throwsA(isA<AnonymousSessionRejected>()));
    });
  });

  group('a named refusal', () {
    test('carries its status, code, method, templated route and the rest of its body', () async {
      const goalId = '01936b2a-4c5e-7f00-8a00-0123456789ab';
      respond(
        client: client,
        method: 'PUT',
        path: Router.goal(goalId),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'goal_not_found', 'message': 'Goal $goalId not found'},
      );

      await expectLater(
        api.updateGoal(goalId, _goal, 'u1'),
        throwsA(
          const ServerRefusal(
            status: 404,
            code: 'goal_not_found',
            method: 'PUT',
            route: '/v1/goals/{id}',
            details: {'error': 'not found', 'message': 'Goal $goalId not found'},
          ),
        ),
      );
    });

    test('is never asked again by the default retry policy', () async {
      respond(client: client, method: 'GET', path: Router.templates, statusCode: 404, body: {'code': 'not_found'});
      final refusal = await api.getTemplates().then<Object>((_) => fail('answered'), onError: (Object e) => e);
      expect(retryableByDefault(refusal as Exception), isFalse);
    });

    test('our own 429 is a refusal to retry later: rate_limited, with when', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 429,
        body: {'code': 'rate_limited', 'retryAfter': 30},
      );
      final refusal = await api.getTemplates().then<Object>((_) => fail('answered'), onError: (Object e) => e);
      expect(refusal, refused('rate_limited', {'retryAfter': 30}));
      expect(retryableByDefault(refusal as Exception), isTrue);
    });
  });

  group('anything else is a NetworkException, never its body', () {
    test('a 5xx, even one that names a code', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 500,
        body: {'code': 'server_error', 'reason': 'Muffin sent this'},
      );
      final failure = await api.getTemplates().then<Object>((_) => fail('answered'), onError: (Object e) => e);
      expect(
        failure,
        isA<NetworkException>()
            .having((e) => e.statusCode, 'status', 500)
            .having((e) => e.method, 'method', 'GET')
            .having((e) => e.endpoint, 'endpoint', '/v1/templates')
            .having((e) => e.body, 'body', isNull),
      );
      expect('$failure', isNot(contains('Muffin')));
      expect(retryableByDefault(failure as Exception), isTrue);
    });

    test("a 4xx with no code: a gateway's own, like a 413 or a 401", () async {
      for (final status in [400, 401, 413]) {
        respond(
          client: client,
          method: 'GET',
          path: Router.templates,
          statusCode: status,
          body: {'message': 'Request Entity Too Large'},
        );
        await expectLater(
          api.getTemplates(),
          throwsA(
            isA<NetworkException>().having((e) => e.statusCode, 'status', status).having((e) => e.body, 'body', isNull),
          ),
        );
      }
    });

    test("a gateway's throttle and an HTML error page", () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 429,
        body: {'message': 'Too Many Requests'},
      );
      await expectLater(api.getTemplates(), throwsA(isA<NetworkException>()));

      raw(Router.templates, 502, '<html><body>Bad Gateway</body></html>');
      await expectLater(
        api.getTemplates(),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'status', 502)),
      );
    });

    test('a 2xx that cannot be read is an UnreadableAnswer: a NetworkException, and a FormatException', () async {
      raw(Router.templates, 200, '[1, 2, 3]');
      final failure = await api.getTemplates().then<Object>((_) => fail('answered'), onError: (Object e) => e);
      expect(failure, isA<UnreadableAnswer>());
      expect(failure, isA<FormatException>());
      expect(failure, isA<NetworkException>().having((e) => e.statusCode, 'status', 200));
      expect('$failure', 'NetworkException(200 GET /v1/templates)');
      // the server may already have acted on it
      expect(retryableByDefault(failure as Exception), isFalse);
    });
  });

  group('a read the caller syncs from never answers a failure as empty', () {
    for (final (status, body) in [
      (500, '{}'),
      (502, '<html></html>'),
      (401, '{"message": "Unauthorized"}'),
      (426, ''),
      (200, '"unreadable"'),
      (200, '{"error": "no goals key"}'),
    ]) {
      test('$status $body', () async {
        raw(Router.userGoals('u1'), status, body);
        await expectLater(api.getTargetUserGoals(requesterId: 'u1', targetUserId: 'u1'), throwsA(anything));

        raw(Router.accountTokens, status, body);
        await expectLater(api.listApiTokens(), throwsA(anything));

        raw(Router.exercisePreferences, status, body);
        await expectLater(api.getExercisePreferences(), throwsA(anything));
      });
    }
  });

  test('a 2xx without its list is an UnreadableAnswer on the route, never a cast error', () async {
    raw(Router.userGoals('u1'), 200, '{"error": "no goals key"}');
    await expectLater(
      api.getTargetUserGoals(requesterId: 'u1', targetUserId: 'u1'),
      throwsA(
        isA<UnreadableAnswer>()
            .having((e) => e.statusCode, 'status', 200)
            .having((e) => '$e', 'message', 'NetworkException(200 /v1/accounts/u1/goals)'),
      ),
    );
  });

  group('a 404 is gone, named or not', () {
    for (final (name, body) in [
      ('named', '{"error": "not found", "code": "not_found"}'),
      ("the gateway's", '{"message": "Not Found"}'),
      ('bodiless', ''),
    ]) {
      test(name, () async {
        raw(Router.invitationLink('tok'), 404, body);
        expect(await api.previewInvitation('tok'), isNull);

        raw(Router.clientWorkoutPlan('sam', 'w1'), 404, body);
        expect(await api.getClientWorkoutPlan('sam', 'w1'), isNull);
      });
    }

    test('and anything else still fails', () async {
      raw(Router.invitationLink('tok'), 500, '{}');
      await expectLater(api.previewInvitation('tok'), throwsA(isA<NetworkException>()));
    });
  });

  test('a write or a delete never swallows a failure', () async {
    for (final method in ['POST', 'DELETE']) {
      for (final path in [Router.exercisePreferences, Router.exercisePreference('e1'), Router.goal('g1')]) {
        respond(client: client, method: method, path: path, statusCode: 503, body: {});
      }
    }
    await expectLater(api.deleteGoal('g1', 'u1'), throwsA(isA<NetworkException>()));
    await expectLater(api.saveUnitPreference('e1', .metric), throwsA(isA<NetworkException>()));
    await expectLater(api.deleteUnitPreference('e1'), throwsA(isA<NetworkException>()));
    await expectLater(api.setExerciseNote('e1', 'grip wide'), throwsA(isA<NetworkException>()));
  });
}

final _goal = Goal(
  metric: .topSetWeight,
  exerciseId: 'exercise-1',
  stages: [GoalStage(id: 's0', target: 100)],
);
