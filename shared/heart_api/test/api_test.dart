import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_api/src/imports.dart';
import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart' show NetworkException;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

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
        method: 'PUT',
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
        method: 'PUT',
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
        method: 'PUT',
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
          'fields': {'key': 'value'},
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
        path: Router.accounts,
        statusCode: 200,
        body: {},
      );

      final result = await api.undoAccountDeletion();
      expect(result, isNull);
    });

    test('undoAccountDeletion throws on error', () async {
      _response(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 400,
        body: {'error': 'bad request'},
      );

      expect(() => api.undoAccountDeletion(), throwsA(isA<Map>()));
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

      final result = await api.getTemplates();
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

      final result = await api.getTemplates();
      expect(result, isNull);
    });

    test('moveTemplate sends the full body plus an explicit folderId', () async {
      final template = Template.fromJson({'id': 't1', 'name': 'Push day', 'order': 0, 'exercises': []});

      _response(
        client: client,
        method: 'PUT',
        path: Router.template('t1'),
        statusCode: 200,
        body: {
          ...template.toMap(),
          'folder': {'id': 'f1', 'name': 'Push', 'order': 0},
        },
      );

      final result = await api.moveTemplate(template, folderId: 'f1');
      expect(result.folderId, 'f1');

      final body = verify(
        client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured.single;
      expect(jsonDecode(body), containsPair('folderId', 'f1'));
    });

    test('moveTemplate sends folderId: null to unfile — absence would leave the filing alone', () async {
      final template = Template.fromJson({'id': 't1', 'name': 'Push day', 'order': 0, 'exercises': []});

      _response(
        client: client,
        method: 'PUT',
        path: Router.template('t1'),
        statusCode: 200,
        body: template.toMap(),
      );

      final result = await api.moveTemplate(template, folderId: null);
      expect(result.folder, isNull);

      final body = verify(
        client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured.single;
      final decoded = jsonDecode(body) as Map;
      expect(decoded.containsKey('folderId'), isTrue);
      expect(decoded['folderId'], isNull);
    });
  });

  group('ApiTemplateFolderService', () {
    test('getFolders returns the folder list', () async {
      _response(
        client: client,
        method: 'GET',
        path: Router.templateFolders,
        statusCode: 200,
        body: {
          'folders': [
            {'id': 'f1', 'name': 'Push', 'order': 0, 'templateCount': 3},
            {'id': 'f2', 'name': 'Pull', 'order': 1, 'templateCount': 0},
          ],
        },
      );

      final result = await api.getFolders(userId: 'u1');
      expect(result, hasLength(2));
      expect(result.first.name, 'Push');
      expect(result.first.templateCount, 3);
    });

    test('createFolder round-trips the folder', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.templateFolders,
        statusCode: 200,
        body: {'id': 'f1', 'name': 'Push', 'order': 0, 'createdAt': '2026-08-01T00:00:00Z'},
      );

      final result = await api.createFolder(
        userId: 'u1',
        folder: TemplateFolder(name: 'Push'),
      );
      expect(result.id, 'f1');
      expect(result.createdAt, DateTime.utc(2026, 8, 1));
    });

    test('createFolder throws the error body on a duplicate name', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.templateFolders,
        statusCode: 400,
        body: {'error': 'bad request', 'code': 'bad_request', 'reason': 'you already have a folder called "Push"'},
      );

      expect(
        () => api.createFolder(
          userId: 'u1',
          folder: TemplateFolder(name: 'Push'),
        ),
        throwsA(containsPair('code', 'bad_request')),
      );
    });

    test('updateFolder round-trips the folder', () async {
      _response(
        client: client,
        method: 'PUT',
        path: Router.templateFolder('f1'),
        statusCode: 200,
        body: {'id': 'f1', 'name': 'Legs', 'order': 2},
      );

      final result = await api.updateFolder(
        userId: 'u1',
        folderId: 'f1',
        folder: TemplateFolder(name: 'Legs', order: 2),
      );
      expect(result.name, 'Legs');
      expect(result.order, 2);
    });

    test('deleteFolder completes on 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.templateFolder('f1'),
        statusCode: 204,
        body: {},
      );

      await api.deleteFolder(userId: 'u1', folderId: 'f1');
    });

    test('deleteFolder throws on somebody else\'s folder', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.templateFolder('f1'),
        statusCode: 404,
        body: {'error': 'not found'},
      );

      expect(() => api.deleteFolder(userId: 'u1', folderId: 'f1'), throwsA(isA<Map>()));
    });

    test('shareFolder returns one share per template assigned', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.folderShare('student-1', 'f1'),
        statusCode: 200,
        body: {
          'shares': [
            {
              'id': 's1',
              'masterTemplateId': 'm1',
              'studentTemplateId': 't1',
              'templateName': 'Push day',
              'assignedTo': {'id': 'student-1', 'username': 'alice'},
              'assignedAt': '2026-08-01T00:00:00Z',
            },
          ],
        },
      );

      final result = await api.shareFolder(coachId: 'u1', targetUserId: 'student-1', folderId: 'f1');
      expect(result, hasLength(1));
      expect(result.single.masterTemplateId, 'm1');
      expect(result.single.assignedTo.id, 'student-1');
    });

    test('shareFolder of an empty folder is an empty list, not an error', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.folderShare('student-1', 'f1'),
        statusCode: 200,
        body: {'shares': []},
      );

      final result = await api.shareFolder(coachId: 'u1', targetUserId: 'student-1', folderId: 'f1');
      expect(result, isEmpty);
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
      const userId = 'u1';
      final workoutJson = [
        {'id': 'w1', 'name': 'Morning Lift', 'start': '2025-01-21T12:00:00Z'},
        {'id': 'w2', 'name': 'Evening Run', 'start': '2025-01-21T13:00:00Z'},
      ];

      _response(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/workouts',
        statusCode: 200,
        body: {'workouts': workoutJson, 'cursor': 'w2'},
        query: {'limit': '2', 'cursor': 'abc'},
      );

      final result = await api.getWorkouts(userId, pageSize: 2, since: 'abc');

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      // cursor present on the wire => authoritative "more pages" signal
      expect(result, isA<Page<Workout>>());
      expect((result as Page<Workout>).hasMore, isTrue);
    });

    test('getWorkouts reports end of list when cursor is absent', () async {
      const userId = 'u1';
      _response(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/workouts',
        statusCode: 200,
        body: {
          'workouts': [
            {'id': 'w1', 'name': 'Morning Lift', 'start': '2025-01-21T12:00:00Z'},
          ],
        },
        query: {'limit': '2'},
      );

      final result = await api.getWorkouts(userId, pageSize: 2);

      expect(result, isA<Page<Workout>>());
      expect((result as Page<Workout>).hasMore, isFalse);
    });

    test('patchWorkout PATCHes the provided fields and parses the updated workout', () async {
      const id = 'w1';
      final start = DateTime.utc(2025, 1, 21, 12);
      final end = DateTime.utc(2025, 1, 21, 13);

      _response(
        client: client,
        method: 'PATCH',
        path: Router.workout(id),
        statusCode: 200,
        body: {'id': id, 'name': 'Renamed', 'start': start.toIso8601String(), 'end': end.toIso8601String()},
      );

      final result = await api.patchWorkout(id, start: start, end: end, name: 'Renamed');

      expect(result.id, equals(id));
      expect(result.name, equals('Renamed'));
      expect(result.start, equals(start));
      expect(result.end, equals(end));

      final captured = verify(
        client.patch(
          Uri.https('api.example.com', Router.workout(id)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(
        jsonDecode(captured as String),
        equals({'name': 'Renamed', 'start': start.toIso8601String(), 'end': end.toIso8601String()}),
      );
    });

    test('patchWorkout omits null fields from the request body', () async {
      const id = 'w2';
      final end = DateTime.utc(2025, 1, 21, 13);

      _response(
        client: client,
        method: 'PATCH',
        path: Router.workout(id),
        statusCode: 200,
        body: {'id': id, 'name': 'Kept', 'start': '2025-01-21T12:00:00.000Z', 'end': end.toIso8601String()},
      );

      await api.patchWorkout(id, end: end);

      final captured = verify(
        client.patch(
          Uri.https('api.example.com', Router.workout(id)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      // name and start were null, so they must not appear on the wire (partial update)
      expect(jsonDecode(captured as String), equals({'end': end.toIso8601String()}));
    });

    test('getWorkouts returns null on malformed response', () async {
      const userId = 'us1';
      _response(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/$userId/workouts',
        statusCode: 200,
        body: {'not_workouts': []},
        query: {},
      );

      final result = await api.getWorkouts(userId);

      expect(result, isNull);
    });
  });

  group('workout images', () {
    test('getWorkoutUploadLink returns (PreSignedUrl, destinationUrl) on valid json', () async {
      _response(
        client: client,
        method: 'PUT',
        path: Router.workoutImages('w1'),
        statusCode: 200,
        body: {
          'url': 'https://bucket.example.com/upload',
          'fields': {'key': 'value'},
          'destinationUrl': 'https://cdn.example.com/w1.jpg',
        },
      );

      final (cred, destinationUrl) = await api.getWorkoutUploadLink('w1');

      expect(cred, isNotNull);
      expect(cred!.url, contains('bucket'));
      expect(cred.fields, containsPair('key', 'value'));
      expect(destinationUrl, equals('https://cdn.example.com/w1.jpg'));
    });

    test('getWorkoutUploadLink returns (null, null) on invalid json shape', () async {
      _response(
        client: client,
        method: 'PUT',
        path: Router.workoutImages('w1'),
        statusCode: 200,
        body: {'message': 'nope'},
      );

      final (cred, destinationUrl) = await api.getWorkoutUploadLink('w1');

      expect(cred, isNull);
      expect(destinationUrl, isNull);
    });

    test('getWorkoutUploadLink coerces destinationUrl to String when not a String', () async {
      _response(
        client: client,
        method: 'PUT',
        path: Router.workoutImages('w1'),
        statusCode: 200,
        body: {
          'url': 'https://bucket.example.com/upload',
          'fields': {'key': 'value'},
          'destinationUrl': 12345,
        },
      );

      final (_, destinationUrl) = await api.getWorkoutUploadLink('w1');
      expect(destinationUrl, equals('12345'));
    });

    test('deleteWorkoutImage returns true when code is 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.workoutImages('w1'),
        statusCode: 204,
        body: {},
        query: {'key': '1'},
      );

      final result = await api.deleteWorkoutImage('w1', '1');
      expect(result, isTrue);
    });

    test('deleteWorkoutImage returns false when code is not 204', () async {
      _response(
        client: client,
        method: 'DELETE',
        path: Router.workoutImages('w1'),
        statusCode: 404,
        query: {'key': '1'},
        body: {'error': 'not found'},
      );

      final result = await api.deleteWorkoutImage('w1', '1');
      expect(result, isFalse);
    });

    test('getWorkoutGallery parses images and cursor (cursor passed as query)', () async {
      _response(
        client: client,
        method: 'GET',
        path: '${Router.workouts}/images',
        statusCode: 200,
        body: {
          'images': [
            {'workoutId': 'w1', 'id': 'p1', 'url': 'https://img.example.com/1.jpg', 'key': '1.jpg'},
            {'workoutId': 'w2', 'id': 'p2', 'url': 'https://img.example.com/2.jpg', 'key': '2.jpg'},
          ],
          'cursor': 'next-cursor',
        },
        query: {'cursor': 'c1'},
      );

      final result = await api.getWorkoutGallery(cursor: 'c1');

      expect(result.cursor, equals('next-cursor'));
      expect(result.images.length, equals(2));
      expect(result.images.first.workoutId, equals('w1'));
      expect(result.images.first.id, equals('p1'));
      expect(result.images.first.link, contains('https://img.example.com/1.jpg'));
    });

    test('getWorkoutGallery returns empty images when response is malformed', () async {
      _response(
        client: client,
        method: 'GET',
        path: '${Router.workouts}/images',
        statusCode: 200,
        body: {'unexpected': true},
        query: {},
      );

      final result = await api.getWorkoutGallery();
      expect(result.images, isEmpty);
    });
  });

  group('imports', () {
    const csv =
        'Date,"Workout Name","Exercise Name"\n'
        '2024-01-01 10:00:00,"Push Day, heavy","Bench Press (Barbell)"';

    Map<String, dynamic> report() {
      return {
        'source': 'strong',
        'workoutsFound': 537,
        'workoutsCreated': 530,
        'workoutsSkipped': 7,
        'setsCreated': 14210,
        'exercisesMatched': 61,
        'exercisesCreated': ['Bench Press (Barbell)'],
        'rowsSkipped': 3,
      };
    }

    test('importWorkouts sends the CSV as-is — jsonEncode would wrap it in quotes', () async {
      api.authenticate({'Authorization': 'Bearer token-1'});
      addTearDown(() => api.defaultHeaders = null);

      final query = {'source': 'strong', 'unit': 'imperial', 'tzOffset': '-04:00'};
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: query,
        statusCode: 200,
        body: report(),
      );

      final result = await api.importWorkouts(
        csv,
        unit: MeasurementUnit.imperial,
        tzOffset: const Duration(hours: -4),
      );

      expect(result.workoutsFound, 537);
      expect(result.workoutsCreated, 530);
      expect(result.workoutsSkipped, 7);
      expect(result.setsCreated, 14210);
      expect(result.exercisesMatched, 61);
      expect(result.exercisesCreated, ['Bench Press (Barbell)']);
      expect(result.rowsSkipped, 3);

      final [headers, body] = verify(
        client.post(
          Uri.https('api.example.com', Router.workoutImports, query),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;
      // the raw file, not jsonEncode's quoted-and-escaped copy of it
      expect(body, same(csv));
      expect(headers, containsPair('Authorization', 'Bearer token-1'));
      expect(headers, containsPair('Content-Type', 'text/csv'));
    });

    test('importWorkouts sends only the source when unit and offset are not given', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'strong'},
        statusCode: 200,
        body: report(),
      );

      final result = await api.importWorkouts(csv);
      expect(result.workoutsFound, 537);
    });

    test('importWorkouts zero-pads a positive half-hour offset', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'strong', 'tzOffset': '+05:30'},
        statusCode: 200,
        body: report(),
      );

      final result = await api.importWorkouts(
        csv,
        tzOffset: const Duration(hours: 5, minutes: 30),
      );
      expect(result.workoutsCreated, 530);
    });

    test('importWorkouts throws ImportRejected with the reason on a 400', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'strong'},
        statusCode: 400,
        body: {'reason': 'not a Strong export: missing "Workout Name" column'},
      );

      expect(
        () => api.importWorkouts(csv),
        throwsA(
          isA<ImportRejected>().having((e) => e.reason, 'reason', contains('Workout Name')),
        ),
      );
    });

    test('previewImportedWorkouts asks for the dry run and reads the unmatched names', () async {
      final query = {'source': 'strong', 'dryRun': 'true', 'tzOffset': '-04:00'};
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: query,
        statusCode: 200,
        body: {
          'source': 'strong',
          'workoutsFound': 537,
          'workoutsAlreadyImported': 7,
          'setsFound': 14210,
          'exercisesMatched': 61,
          'exercisesUnmatched': [
            {'name': 'Bench Press (Barbell)', 'sets': 412},
            {'name': 'Building Climbing', 'sets': 3},
          ],
          'rowsSkipped': 3,
        },
      );

      final preview = await api.previewImportedWorkouts(
        csv,
        tzOffset: const Duration(hours: -4),
      );

      expect(preview.workoutsFound, 537);
      expect(preview.workoutsAlreadyImported, 7);
      expect(preview.setsFound, 14210);
      expect(preview.exercisesMatched, 61);
      expect(preview.exercisesUnmatched, [
        (name: 'Bench Press (Barbell)', sets: 412),
        (name: 'Building Climbing', sets: 3),
      ]);
      expect(preview.rowsSkipped, 3);

      // still the raw file — a preview is the same request, minus the write
      final [_, body] = verify(
        client.post(
          Uri.https('api.example.com', Router.workoutImports, query),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;
      expect(body, same(csv));
    });

    test('importWorkouts carries the consent allowlist in a JSON envelope', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'strong'},
        statusCode: 200,
        body: {
          ...report(),
          'setsSkipped': 3,
          'exercisesSkipped': ['Building Climbing'],
        },
      );

      final result = await api.importWorkouts(
        csv,
        createCustom: const ['Bench Press (Barbell)'],
      );
      expect(result.setsSkipped, 3);
      expect(result.exercisesSkipped, ['Building Climbing']);

      final [headers, body] = verify(
        client.post(
          Uri.https('api.example.com', Router.workoutImports, {'source': 'strong'}),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;
      expect(headers, containsPair('Content-Type', 'application/json'));
      expect(
        jsonDecode(body),
        {
          'csv': csv,
          'createCustom': ['Bench Press (Barbell)'],
        },
      );
    });

    test('importWorkouts sends an empty allowlist as-is — decline-all is a real choice', () async {
      _response(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'strong'},
        statusCode: 200,
        body: report(),
      );

      await api.importWorkouts(csv, createCustom: const []);

      final [_, body] = verify(
        client.post(
          Uri.https('api.example.com', Router.workoutImports, {'source': 'strong'}),
          headers: captureAnyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured;
      expect(jsonDecode(body), containsPair('createCustom', isEmpty));
    });

    test('importWorkouts survives a plain-text error body — the gateway 401 is not JSON', () async {
      final uri = Uri.https('api.example.com', Router.workoutImports, {'source': 'strong'});
      when(
        client.post(uri, headers: anyNamed('headers'), body: anyNamed('body')),
      ).thenAnswer(
        (_) async => _Response('Unauthorized', 401, request: http.Request('POST', uri)),
      );

      expect(
        () => api.importWorkouts(csv),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
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
      _response(
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

    test('asks for the achieved slice with a query parameter, not a path', () async {
      // glued onto the path, the `?` is percent-encoded by `Uri.https` and the
      // server sees one long segment matching no route — a 404, not a slice
      _response(
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

      _response(
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
    'POST' => when(
      client.post(
        uri,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => response),
    'PUT' => when(
      client.put(
        uri,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => response),
    'PATCH' => when(
      client.patch(
        uri,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => response),
    'DELETE' => when(client.delete(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    'HEAD' => when(client.head(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    _ => throw UnsupportedError('Unsupported HTTP method: $method'),
  };
}

class _Response(
  super.body,
  super.statusCode, {
  required super.request,
  super.headers,
}) extends http.Response;
