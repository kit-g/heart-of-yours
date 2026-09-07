import 'dart:convert';

import 'package:heart_api/heart_api.dart';
import 'package:heart_api/src/api.dart' show Router;
import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'api_test.mocks.dart';

/// The wire side of the upsync replay contract (heart-api#66): every create
/// carries the client id, `201` and `200` are told apart, a name match comes
/// back under the server's id, refusals are thrown whole, and an anonymous
/// token reaching the server trips its own exception.
void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  Map<String, dynamic> sentBody() {
    final captured = verify(client.post(any, headers: anyNamed('headers'), body: captureAnyNamed('body'))).captured;
    return jsonDecode(captured.single as String) as Map<String, dynamic>;
  }

  Exercise custom() {
    return Exercise.fromJson({
      'id': uuidV7(),
      'name': 'Cable Crossover, low',
      'category': 'Machine',
      'target': 'Chest',
      'own': 1,
    });
  }

  group('custom exercises', () {
    test('the create sends the client id and reports a 201 as created', () async {
      final exercise = custom();
      _post(client, Router.exercises, 201, {...exercise.toMap()});

      final (:row, :created) = await api.replayExercise(exercise);

      expect(created, isTrue);
      expect(row.id, exercise.id);
      expect(sentBody(), containsPair('id', exercise.id));
    });

    test('a name match comes back as the account\'s own row, under its id, not created', () async {
      final exercise = custom();
      final theirs = uuidV7();
      _post(client, Router.exercises, 200, {...exercise.toMap(), 'id': theirs});

      final (:row, :created) = await api.replayExercise(exercise);

      expect(created, isFalse);
      expect(row.id, theirs);
    });

    test('makeExercise is the same call, and takes a 201 in its stride', () async {
      final exercise = custom();
      _post(client, Router.exercises, 201, exercise.toMap());

      final made = await api.makeExercise(exercise);

      expect(made.id, exercise.id);
    });

    test('an id that belongs to someone else is thrown whole, code and all', () async {
      _post(client, Router.exercises, 403, {
        'error': 'forbidden',
        'code': 'id_taken',
        'reason': 'this id belongs to another account',
      });

      expect(() => api.replayExercise(custom()), throwsA(containsPair('code', 'id_taken')));
    });
  });

  test('a unit preference replay fails loudly on anything but success', () async {
    _post(client, Router.exercisePreferences, 200, {'exerciseId': 'e1', 'unitSystem': 'imperial'});
    await api.replayUnitPreference('e1', .imperial);
    expect(sentBody(), {'exerciseId': 'e1', 'unitSystem': 'imperial'});

    _post(client, Router.exercisePreferences, 500, {'error': 'server_error', 'code': 'server_error'});
    expect(() => api.replayUnitPreference('e1', .imperial), throwsA(containsPair('code', 'server_error')));
  });

  group('folders', () {
    test('sends the id when the folder has one', () async {
      final id = uuidV7();
      _post(client, Router.templateFolders, 201, {'id': id, 'name': 'Push', 'order': 0});

      final (:row, :created) = await api.replayFolder(TemplateFolder(id: id, name: 'Push'));

      expect(created, isTrue);
      expect(row.id, id);
      expect(sentBody(), {'id': id, 'name': 'Push', 'order': 0});
    });

    test('a folder made in the app carries no id yet, and none is sent', () async {
      _post(client, Router.templateFolders, 201, {'id': 'f1', 'name': 'Push', 'order': 0});

      await api.createFolder(
        userId: 'u1',
        folder: TemplateFolder(name: 'Push'),
      );

      expect(sentBody(), isNot(contains('id')));
    });

    test('a name match is the account\'s folder, not created', () async {
      _post(client, Router.templateFolders, 200, {'id': 'theirs', 'name': 'push', 'order': 2});

      final (:row, :created) = await api.replayFolder(TemplateFolder(id: uuidV7(), name: 'Push'));

      expect(created, isFalse);
      expect(row.id, 'theirs');
    });
  });

  group('templates', () {
    Template template(String id) {
      final t = Template.empty(id: id, order: 0);
      t.name = 'Push day';
      return t;
    }

    test('a platform id goes on the wire', () async {
      final id = uuidV7();
      _post(client, Router.templates, 201, {'id': id, 'name': 'Push day', 'order': 0, 'exercises': []});

      final (:row, :created) = await api.replayTemplate(template(id));

      expect(created, isTrue);
      expect(row.id, id);
      expect(sentBody(), containsPair('id', id));
    });

    test('a timestamp id from before the cutover is left for the server to mint', () async {
      _post(client, Router.templates, 201, {'id': uuidV7(), 'name': 'Push day', 'order': 0, 'exercises': []});

      final (:row, created: _) = await api.replayTemplate(template('2026-08-01T10:00:00.000Z'));

      expect(sentBody(), isNot(contains('id')));
      expect(isUuidV7(row.id), isTrue);
    });

    test('a retried id is found, not created', () async {
      final id = uuidV7();
      _post(client, Router.templates, 200, {'id': id, 'name': 'Push day', 'order': 0, 'exercises': []});

      final (row: _, :created) = await api.replayTemplate(template(id));

      expect(created, isFalse);
    });
  });

  group('workouts', () {
    test('the client id is on the wire and a retry is told from a create', () async {
      final workout = Workout(name: 'Morning')..finish(DateTime.timestamp());
      _post(client, Router.workouts, 200, workout.toMap());

      final (:row, :created) = await api.replayWorkout(workout);

      expect(created, isFalse);
      expect(row.id, workout.id);
      expect(sentBody(), containsPair('id', workout.id));
    });

    test('saveWorkout reads the row off the same call', () async {
      final workout = Workout(name: 'Morning')..finish(DateTime.timestamp());
      _post(client, Router.workouts, 201, workout.toMap());

      final saved = await api.saveWorkout(workout);

      expect(saved.id, workout.id);
    });
  });

  group('goals', () {
    Goal goal(String? id) {
      return Goal(
        id: id,
        metric: .topSetWeight,
        exerciseId: 'exercise-1',
        stages: [GoalStage(id: 's0', target: 100)],
      );
    }

    Map<String, dynamic> body(String id) {
      return {
        'id': id,
        'metric': 'topSetWeight',
        'exerciseId': 'exercise-1',
        'archived': false,
        'stages': [
          {'id': 's0', 'target': 100},
        ],
      };
    }

    test('the create carries the client id — an update never does', () async {
      final id = uuidV7();
      _post(client, Router.goals, 201, body(id));

      final (:row, :created) = await api.replayGoal(goal(id));

      expect(created, isTrue);
      expect(row.id, id);
      expect(sentBody(), containsPair('id', id));
    });

    test('a goal minted nowhere yet sends no id', () async {
      _post(client, Router.goals, 201, body(uuidV7()));

      await api.createGoal(goal(null), 'u1');

      expect(sentBody(), isNot(contains('id')));
    });

    test('the cap is a refusal with a name, thrown whole', () async {
      _post(client, Router.goals, 400, {'error': 'bad request', 'code': 'goal_limit'});

      expect(() => api.replayGoal(goal(uuidV7())), throwsA(containsPair('code', 'goal_limit')));
    });
  });

  group('the anonymous-account tripwire', () {
    test('a 403 anonymous_account on any verb is its own exception', () async {
      final uri = Uri.https('api.example.com', Router.templates);
      when(client.get(uri, headers: anyNamed('headers'))).thenAnswer(
        (_) async => _Response(
          jsonEncode({'error': 'forbidden', 'code': 'anonymous_account'}),
          403,
          request: http.Request('GET', uri),
        ),
      );

      expect(api.getTemplates, throwsA(isA<AnonymousSessionRejected>()));

      _post(client, Router.workouts, 403, {'error': 'forbidden', 'code': 'anonymous_account'});
      expect(() => api.replayWorkout(Workout(name: 'x')), throwsA(isA<AnonymousSessionRejected>()));
    });

    test('any other 403 passes through as before', () async {
      _post(client, Router.workouts, 403, {'error': 'forbidden', 'code': 'id_taken'});

      expect(() => api.replayWorkout(Workout(name: 'x')), throwsA(containsPair('code', 'id_taken')));
    });
  });
}

void _post(MockClient client, String path, int statusCode, Map<String, dynamic> body) {
  final uri = Uri.https('api.example.com', path);
  when(client.post(uri, headers: anyNamed('headers'), body: anyNamed('body'))).thenAnswer(
    (_) async => _Response(jsonEncode(body), statusCode, request: http.Request('POST', uri)),
  );
}

class _Response(
  super.body,
  super.statusCode, {
  required super.request,
}) extends http.Response;
