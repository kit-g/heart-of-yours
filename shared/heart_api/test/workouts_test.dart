import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_api/src/imports.dart';
import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:network_utils/network_utils.dart' show NetworkException;
import 'package:test/test.dart';

import 'support/http.dart';

void main() {
  late MockClient client;
  late Api api;

  setUp(() {
    client = MockClient();
    api = Api(gateway: 'api.example.com', client: client);
  });

  group('RemoteWorkoutService', () {
    test('deleteWorkout returns true when code is 204', () async {
      respond(
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
      respond(
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

      respond(
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
      respond(
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

      respond(
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

      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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
      respond(
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

    test('a Hevy export goes up as source=hevy and reads the same preview', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'hevy', 'dryRun': 'true'},
        statusCode: 200,
        body: {'source': 'hevy', 'workoutsFound': 12, 'setsFound': 140},
      );

      final preview = await api.previewImportedWorkouts(csv, source: .hevy);

      expect(preview.workoutsFound, 12);
      expect(preview.setsFound, 140);
    });

    test("Heart's own CSV goes up as source=heart and reads the same preview (#357)", () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.workoutImports,
        query: {'source': 'heart', 'dryRun': 'true'},
        statusCode: 200,
        body: {'source': 'heart', 'workoutsFound': 3, 'workoutsAlreadyImported': 3, 'setsFound': 27},
      );

      final preview = await api.previewImportedWorkouts(csv, source: .heart);

      expect(preview.workoutsFound, 3);
      expect(preview.workoutsAlreadyImported, 3);
    });

    test('a 202 is a parked file, on the dry run and the commit alike', () async {
      const body = {
        'source': 'hevy',
        'status': 'parked',
        'message': "We couldn't read this Hevy export automatically.",
        'reason': 'unreadable date "22.09.2026, 17:00"',
      };
      for (final query in [
        {'source': 'hevy', 'dryRun': 'true'},
        {'source': 'hevy'},
      ]) {
        respond(
          client: client,
          method: 'POST',
          path: Router.workoutImports,
          query: query,
          statusCode: 202,
          body: body,
        );
      }

      final parked = isA<ImportParked>().having((e) => e.reason, 'reason', contains('unreadable date'));
      expect(() => api.previewImportedWorkouts(csv, source: .hevy), throwsA(parked));
      expect(() => api.importWorkouts(csv, source: .hevy), throwsA(parked));
    });

    test('previewImportedWorkouts asks for the dry run and reads the unmatched names', () async {
      final query = {'source': 'strong', 'dryRun': 'true', 'tzOffset': '-04:00'};
      respond(
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
      respond(
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
      respond(
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
        (_) async => StubResponse('Unauthorized', 401, request: http.Request('POST', uri)),
      );

      expect(
        () => api.importWorkouts(csv),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('workout plans (#566)', () {
    const workoutId = '01a1b7d4-c1db-7eba-8005-c926c367acf8';
    const plan = WorkoutPlan({
      'exercises': [
        {
          'sets': [
            {'weight': 110, 'setId': '01a1b7d4-c1db-7fc9-b20f-e61fcc3b5aa5'},
          ],
        },
      ],
    });

    test('saveWorkoutPlan sends the plan under its key', () async {
      respond(client: client, method: 'PUT', path: Router.workoutPlan(workoutId), statusCode: 204, body: {});

      await api.saveWorkoutPlan(workoutId, plan);

      final sent = verify(
        client.put(
          Uri.https('api.example.com', Router.workoutPlan(workoutId)),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'plan': plan.plan});
    });

    test("saveWorkoutPlan throws the server's refusal whole", () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.workoutPlan(workoutId),
        statusCode: 400,
        body: {
          'error': 'bad request',
          'code': 'invalid_plan',
          'reason': 'plan must be {exercises: [{sets: [{weight, setId}]}]}',
        },
      );
      expect(api.saveWorkoutPlan(workoutId, plan), throwsA(containsPair('code', 'invalid_plan')));
    });
  });
}
