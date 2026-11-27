import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'support/http.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group('GoalService', () {
    const userId = 'user-1';

    Map<String, dynamic> goalBody() {
      return {
        'id': 'goal-1',
        'metric': 'topSetWeight',
        'exerciseId': 'exercise-1',
        'archived': false,
        'stages': [
          {'id': 's0', 'target': 100},
        ],
      };
    }

    test('reads the live goals from the account path', () async {
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/goals',
        statusCode: 200,
        body: {
          'goals': [goalBody()],
        },
      );

      final goals = await api.getTargetUserGoals(requesterId: userId, targetUserId: userId);

      expect(goals.map((each) => each.id), ['goal-1']);
    });

    test('a goal this build cannot read costs that goal, not the list (#277)', () async {
      // The caller replaces its synced goals with this list, so the goal
      // skipped here leaves the device's mirror — and only the mirror: no
      // remote delete follows from a refresh, the server keeps it, and a build
      // that can read it shows it again. Failing the list instead would stop
      // every goal from refreshing until the app is updated.
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/goals',
        statusCode: 200,
        body: {
          'goals': [
            goalBody(),
            {...goalBody(), 'id': 'goal-2', 'metric': 'aMetricFromTheFuture'},
          ],
        },
      );

      final goals = await api.getTargetUserGoals(requesterId: userId, targetUserId: userId);

      expect(goals.map((each) => each.id), ['goal-1']);
    });

    test('asks for the achieved slice with a query parameter, not a path', () async {
      // glued onto the path, the `?` is percent-encoded by `Uri.https` and the
      // server sees one long segment matching no route — a 404, not a slice
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/goals',
        query: const {'archived': 'true'},
        statusCode: 200,
        body: {
          'goals': [
            {...goalBody(), 'id': 'goal-done', 'archived': true},
          ],
        },
      );

      final goals = await api.getTargetUserGoals(
        requesterId: userId,
        targetUserId: userId,
        archived: true,
      );

      expect(goals.map((each) => each.id), ['goal-done']);
    });

    test('sends archived on write, so putting a goal away sticks', () async {
      final goal = Goal(
        id: 'goal-1',
        metric: GoalMetric.topSetWeight,
        exerciseId: 'exercise-1',
        archived: true,
        stages: [GoalStage(id: 's0', target: 100)],
      );

      respond(
        client: client,
        method: 'PUT',
        path: '${Router.goals}/goal-1',
        statusCode: 200,
        body: {...goalBody(), 'archived': true},
      );

      final saved = await api.updateGoal('goal-1', goal, userId);

      expect(saved.archived, isTrue);
      final captured = verify(
        client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured.single;
      expect(jsonDecode(captured as String), containsPair('archived', true));
    });
  });
}
