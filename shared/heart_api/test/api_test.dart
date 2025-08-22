import 'package:heart_api/src/api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@GenerateNiceMocks(
  [
    MockSpec<http.Client>(),
    MockSpec<Exercise>(),
  ],
)
import 'api_test.mocks.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group('AccountService', () {
    test('registerAccount returns User on 200', () async {
      final user = User(id: '42', displayName: 'Jane');

      _response(
        client: client,
        method: 'POST',
        path: Router.accounts,
        statusCode: 200,
        body: user.toMap(),
      );

      final result = await api.registerAccount(user);
      expect(result, isA<User>());
      expect(result.id, equals('42'));
      expect(result.displayName, equals('Jane'));
    });

    test('registerAccount throws AccountDeleted on specific error', () async {
      final user = User(id: '42', displayName: 'Jane');

      _response(
        client: client,
        method: 'POST',
        path: Router.accounts,
        statusCode: 400,
        body: {'code': 'ACCOUNT_DELETED'},
      );

      expect(() => api.registerAccount(user), throwsA(isA<AccountDeleted>()));
    });

    test('registerAccount throws on unexpected error', () async {
      final user = User(id: '42', displayName: 'Jane');

      _response(
        client: client,
        method: 'POST',
        path: Router.accounts,
        statusCode: 500,
        body: {'error': 'unexpected'},
      );

      expect(() => api.registerAccount(user), throwsA(isA<Map>()));
    });

    test('deleteAccount returns null on success (<400)', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.accounts,
        statusCode: 204,
        body: {},
      );

      final result = await api.deleteAccount(accountId: '42');
      expect(result, isNull);
    });

    test('deleteAccount throws on error (>=400)', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.accounts,
        statusCode: 404,
        body: {'error': 'Not Found'},
      );

      expect(() => api.deleteAccount(accountId: '42'), throwsA(isA<Map>()));
    });

    test('getAvatarUploadLink returns PreSignedUrl on valid json', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 200,
        body: {
          'url': 'https://bucket.example.com/upload',
          'fields': {'key': 'value'}
        },
      );

      final result = await api.getAvatarUploadLink('42');
      expect(result, isNotNull);
      expect(result!.url, contains('bucket'));
      expect(result.fields, containsPair('key', 'value'));
    });

    test('getAvatarUploadLink returns null on invalid json', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 200,
        body: {'message': 'bad response'},
      );

      final result = await api.getAvatarUploadLink('42');
      expect(result, isNull);
    });

    test('removeAvatar returns true on success', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 200,
        body: {},
      );

      final result = await api.removeAvatar('42');
      expect(result, isTrue);
    });

    test('removeAvatar returns false on failure', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 500,
        body: {},
      );

      final result = await api.removeAvatar('42');
      expect(result, isFalse);
    });

    test('undoAccountDeletion returns null on success', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 200,
        body: {},
      );

      final result = await api.undoAccountDeletion('42');
      expect(result, isNull);
    });

    test('undoAccountDeletion throws on error', () async {
      _response(
        client: client,
        method: 'PUT',
        path: '${Router.accounts}/42',
        statusCode: 400,
        body: {'error': 'bad request'},
      );

      expect(() => api.undoAccountDeletion('42'), throwsA(isA<Map>()));
    });
  });

  group('RemoteExerciseService', () {
    test('getExercises returns list of Exercise when response is valid', () async {
      final list = [
        Exercise.fromJson({'id': '1', 'name': 'Squat', 'category': 'Reps Only', 'target': 'Chest'}).toMap(),
        Exercise.fromJson({'id': '2', 'name': 'Push-up', 'category': 'Reps Only', 'target': 'Chest'}).toMap(),
      ];

      _response(
        client: client,
        method: 'GET',
        path: Router.exercises,
        statusCode: 200,
        body: {'exercises': list},
      );

      final result = await api.getExercises();

      expect(result.length, equals(2));
      expect(result.first.name, equals('Squat'));
    });

    test('getExercises returns empty list when response is invalid', () async {
      _response(
        client: client,
        method: 'GET',
        path: Router.exercises,
        statusCode: 200,
        body: {'error': 'no data'},
      );

      final result = await api.getExercises();
      expect(result, isEmpty);
    });
  });

  group('RemoteTemplateService', () {
    test('deleteTemplate returns true if code is 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: '${Router.templates}/123',
        statusCode: 204,
        body: {},
      );

      final result = await api.deleteTemplate('123');
      expect(result, isTrue);
    });

    test('deleteTemplate returns false if code is not 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: '${Router.templates}/123',
        statusCode: 404,
        body: {'error': 'not found'},
      );

      final result = await api.deleteTemplate('123');
      expect(result, isFalse);
    });

    test('getTemplates returns list of Template when valid', () async {
      final templates = [
        {
          'id': 'a',
          'name': 'template A',
          'exerciseId': '1',
          'order': 0,
        },
        {
          'id': 'b',
          'name': 'template B',
          'exerciseId': '2',
          'order': 2,
        },
      ];

      _response(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 200,
        body: {'templates': templates},
      );

      final result = await api.getTemplates((id) => MockExercise());
      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result.first.name, contains('template'));
    });

    test('getTemplates returns null when JSON is invalid', () async {
      _response(
        client: client,
        method: 'GET',
        path: Router.templates,
        statusCode: 200,
        body: {'unexpected': []},
      );

      final result = await api.getTemplates((id) => MockExercise());
      expect(result, isNull);
    });
  });

  group('RemoteWorkoutService', () {
    test('deleteWorkout returns true when code is 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: '${Router.workouts}/abc123',
        statusCode: 204,
        body: {},
      );

      final result = await api.deleteWorkout('abc123');
      expect(result, isTrue);
    });

    test('deleteWorkout returns false for non-204 code', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: '${Router.workouts}/abc123',
        statusCode: 400,
        body: {},
      );

      final result = await api.deleteWorkout('abc123');
      expect(result, isFalse);
    });

    test('getWorkouts returns list of workouts on valid response', () async {
      final workoutJson = [
        {'id': 'w1', 'name': 'Morning Lift', 'exerciseId': 'x'},
        {'id': 'w2', 'name': 'Evening Run', 'exerciseId': 'y'},
      ];

      _response(
        client: client,
        method: 'GET',
        path: Router.workouts,
        statusCode: 200,
        body: {'workouts': workoutJson},
        query: {'pageSize': '2', 'since': 'abc'},
      );

      lookup(String id) => MockExercise();

      final result = await api.getWorkouts(lookup, pageSize: 2, since: 'abc');

      expect(result, isNotNull);
      expect(result!.length, equals(2));
    });

    test('getWorkouts returns null on malformed response', () async {
      _response(
        client: client,
        method: 'GET',
        path: Router.workouts,
        statusCode: 200,
        body: {'not_workouts': []},
        query: {},
      );

      lookup(String id) => MockExercise();
      final result = await api.getWorkouts(lookup);

      expect(result, isNull);
    });
  });
}

void _response({
  required http.Client client,
  required String method,
  required String path,
  required int statusCode,
  required Map<String, dynamic> body,
  Map<String, String>? headers,
  String gateway = 'api.example.com',
  Map<String, dynamic>? query,
}) {
  final uri = Uri.https(gateway, path, query?.map((k, v) => MapEntry(k, v.toString())));
  final request = http.Request(method, uri);
  final response = _Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: headers ?? const {},
  );

  return switch (method.toUpperCase()) {
    'GET' => when(client.get(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    'POST' =>
      when(client.post(uri, headers: anyNamed('headers'), body: anyNamed('body'))).thenAnswer((_) async => response),
    'PUT' =>
      when(client.put(uri, headers: anyNamed('headers'), body: anyNamed('body'))).thenAnswer((_) async => response),
    'DELETE' => when(client.delete(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    'HEAD' => when(client.head(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    _ => throw UnsupportedError('Unsupported HTTP method: $method')
  };
}

class _Response extends http.Response {
  _Response(
    super.body,
    super.statusCode, {
    required super.request,
    super.headers,
  });
}
