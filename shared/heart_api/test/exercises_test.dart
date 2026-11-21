import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_api/src/moves.dart';
import 'package:heart_api/src/renames.dart';
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

  group('RemoteExerciseService', () {
    test('getExercises returns list of Exercise when response is valid', () async {
      final list = [
        Exercise.fromJson({'id': '1', 'name': 'Squat', 'category': 'Reps Only', 'target': 'Chest'}).toMap(),
        Exercise.fromJson({'id': '2', 'name': 'Push-up', 'category': 'Reps Only', 'target': 'Chest'}).toMap(),
      ];

      respond(
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

    test('an exercise this build cannot read costs that exercise, not the list', () async {
      // a category from a server newer than the app in the user's hands
      respond(
        client: client,
        method: 'GET',
        path: Router.exercises,
        statusCode: 200,
        body: {
          'exercises': [
            {'id': '1', 'name': 'Squat', 'category': 'Reps Only', 'target': 'Legs'},
            {'id': '2', 'name': 'Yoke Carry', 'category': 'A Category From The Future', 'target': 'Legs'},
            {'id': '3', 'name': 'Push-up', 'category': 'Reps Only', 'target': 'Chest'},
          ],
        },
      );

      final result = await api.getExercises();

      expect(result.map((each) => each.name), ['Squat', 'Push-up']);
    });

    test('editExercise addresses the exercise by id, not by its display name', () async {
      // The route is `('/exercises/:exerciseId', .put)` and the query behind it
      // is `WHERE id = @exerciseId::uuid`. This call used to send
      // `exercise.name` — which is localized copy and cannot cast to a uuid, so
      // every edit of a custom exercise died in the database. The path shape
      // matched, so it never even surfaced as a 404, and nothing tested it.
      final custom = Exercise.fromJson({
        'id': '019e8b5d-c52d-729e-be9c-a5403b04fd1b',
        'name': 'Bench Press (Barbell)',
        'category': 'Barbell',
        'target': 'Chest',
        'own': 1,
      });

      respond(
        client: client,
        method: 'PUT',
        path: '${Router.exercises}/019e8b5d-c52d-729e-be9c-a5403b04fd1b',
        statusCode: 200,
        body: custom.toMap(),
      );

      final result = await api.editExercise(custom);
      expect(result.id, equals('019e8b5d-c52d-729e-be9c-a5403b04fd1b'));
    });

    group('editExercise (#616)', () {
      final custom = Exercise.fromJson({
        'id': '019e8b5d-c52d-729e-be9c-a5403b04fd1b',
        'name': 'Landmine Press',
        'category': 'Barbell',
        'target': 'Shoulders',
        'own': 1,
        'movement': {
          'groups': ['vertical_press'],
        },
      });
      final path = '${Router.exercises}/${custom.id}';

      Map<String, dynamic> sent() {
        final captured = verify(client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body'))).captured;
        return jsonDecode(captured.single as String) as Map<String, dynamic>;
      }

      test('an edit sends the pattern and leaves the name out', () async {
        respond(client: client, method: 'PUT', path: path, statusCode: 200, body: custom.toMap());

        await api.editExercise(custom);

        expect(sent(), allOf(containsPair('pattern', 'vertical_press'), isNot(contains('name'))));
      });

      test('a rename sends the name', () async {
        respond(client: client, method: 'PUT', path: path, statusCode: 200, body: custom.toMap());

        await api.renameExercise(custom);

        expect(sent(), containsPair('name', 'Landmine Press'));
      });

      test('no pattern is sent as null, so the server clears its own', () async {
        final bare = Exercise.fromJson({...custom.toMap()..remove('movement')});
        respond(client: client, method: 'PUT', path: path, statusCode: 200, body: bare.toMap());

        await api.editExercise(bare);

        expect(sent(), containsPair('pattern', null));
      });

      test('a name the account already has is ExerciseNameTaken', () async {
        respond(
          client: client,
          method: 'PUT',
          path: path,
          statusCode: 409,
          body: {'code': 'name_taken', 'reason': 'taken'},
        );

        expect(() => api.renameExercise(custom), throwsA(isA<ExerciseNameTaken>()));
      });
    });

    test('getExercises throws an answer it cannot read, never an empty catalog', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.exercises,
        statusCode: 200,
        body: {'error': 'no data'},
      );

      await expectLater(api.getExercises(), throwsA(isA<TypeError>()));
    });
  });

  group('exercise preferences', () {
    test('pin writes only the note and unpin uses the note query parameter', () async {
      when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body'), encoding: anyNamed('encoding')))
          .thenAnswer(
            (_) async => http.Response(
              '{}',
              200,
              request: http.Request('POST', Uri.https('api.example.com', Router.exercisePreferences)),
            ),
          );
      await api.setExerciseNote('e1', 'Pause');
      final request =
          verify(
                client.post(
                  any,
                  headers: anyNamed('headers'),
                  body: captureAnyNamed('body'),
                  encoding: anyNamed('encoding'),
                ),
              ).captured.single
              as String;
      expect(jsonDecode(request), {'exerciseId': 'e1', 'note': 'Pause'});
      when(client.delete(any, headers: anyNamed('headers'), body: anyNamed('body'), encoding: anyNamed('encoding')))
          .thenAnswer(
            (_) async => http.Response(
              '',
              204,
              request: http.Request(
                'DELETE',
                Uri.https('api.example.com', '${Router.exercisePreferences}/e1', {'pref': 'note'}),
              ),
            ),
          );
      await api.setExerciseNote('e1', null);
      final uri =
          verify(
                client.delete(
                  captureAny,
                  headers: anyNamed('headers'),
                  body: anyNamed('body'),
                  encoding: anyNamed('encoding'),
                ),
              ).captured.single
              as Uri;
      expect(uri.path, '/v1/exercise-preferences/e1');
      expect(uri.queryParameters, {'pref': 'note'});
    });

    test('getExercisePreferences parses every row, whichever fields it carries', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.exercisePreferences,
        statusCode: 200,
        body: {
          'preferences': [
            {'exerciseId': 'e1', 'unitSystem': 'imperial'},
            {'exerciseId': 'e2', 'restTimer': 90},
            {'exerciseId': 'e3', 'unitSystem': 'metric', 'restTimer': 60, 'note': 'Pause'},
            {'exerciseId': 'e4', 'note': 'Slow'},
          ],
        },
      );

      final result = (await api.getExercisePreferences()).toList();

      expect(result.map((each) => each.exerciseId), ['e1', 'e2', 'e3', 'e4']);
      expect(result.map((each) => each.unitSystem), [MeasurementUnit.imperial, null, MeasurementUnit.metric, null]);
      expect(result.map((each) => each.restTimer), [null, 90, 60, null]);
      expect(result.map((each) => each.note), [null, null, 'Pause', 'Slow']);
    });

    test('getExercisePreferences throws an answer that names nothing, never answering none', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.exercisePreferences,
        statusCode: 200,
        body: {'error': 'no data'},
      );

      // the caller replaces the device's notes with this: none would delete them
      await expectLater(api.getExercisePreferences(), throwsA(isA<TypeError>()));
    });

    test('getExercisePreferences throws a failure, never answering none', () async {
      for (final (status, body) in [
        (500, <String, dynamic>{}),
        (429, {'message': 'Too Many Requests'}),
      ]) {
        respond(client: client, method: 'GET', path: Router.exercisePreferences, statusCode: status, body: body);
        await expectLater(
          api.getExercisePreferences(),
          throwsA(isA<NetworkException>().having((e) => e.statusCode, 'status', status)),
        );
      }
    });
  });

  group('exercise history move', () {
    const report = {
      'sourceId': 'source',
      'targetId': 'target',
      'dryRun': true,
      'workoutExercises': 12,
      'templateExercises': 2,
      'preferences': 1,
      'preferencesDropped': 0,
      'chartPreferences': 0,
      'goals': 1,
      'sourceDeleted': true,
    };

    void answer(Object body, int status) {
      when(
        client.post(any, headers: anyNamed('headers'), body: anyNamed('body'), encoding: anyNamed('encoding')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode(body),
          status,
          request: http.Request('POST', Uri.https('api.example.com', Router.exerciseMoves('source'))),
        ),
      );
    }

    test('posts the target to the source\'s moves, with dryRun only on a preview', () async {
      answer(report, 200);
      final preview = await api.moveExerciseHistory('source', targetId: 'target', dryRun: true);
      expect(preview.workoutExercises, 12);
      expect(preview.sourceDeleted, isTrue);

      final [uri as Uri, body as String] = verify(
        client.post(
          captureAny,
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
          encoding: anyNamed('encoding'),
        ),
      ).captured;
      expect(uri.path, '/v1/exercises/source/moves');
      expect(uri.queryParameters, {'dryRun': 'true'});
      expect(jsonDecode(body), {'targetId': 'target'});

      answer({...report, 'dryRun': false}, 200);
      await api.moveExerciseHistory('source', targetId: 'target');
      final real =
          verify(
                client.post(
                  captureAny,
                  headers: anyNamed('headers'),
                  body: anyNamed('body'),
                  encoding: anyNamed('encoding'),
                ),
              ).captured.single
              as Uri;
      expect(real.queryParameters, isEmpty);
    });

    test('the named refusals are typed, any other refusal comes as it is', () async {
      answer({'error': 'bad request', 'code': 'same_exercise', 'reason': 'same'}, 400);
      await expectLater(
        api.moveExerciseHistory('source', targetId: 'source'),
        throwsA(isA<ExerciseMoveRefused>().having((e) => e.reason, 'reason', ExerciseMoveRefusal.sameExercise)),
      );

      answer({'error': 'not found', 'code': 'unknown_exercise', 'message': 'Exercise #x not found'}, 404);
      await expectLater(
        api.moveExerciseHistory('source', targetId: 'target'),
        throwsA(isA<ExerciseMoveRefused>().having((e) => e.reason, 'reason', ExerciseMoveRefusal.unknownExercise)),
      );

      answer({
        'error': 'bad request',
        'code': 'incompatible_exercise',
        'reason': 'Reps Only sets cannot move onto Cardio',
      }, 400);
      await expectLater(
        api.moveExerciseHistory('source', targetId: 'target'),
        throwsA(
          isA<ExerciseMoveRefused>().having((e) => e.reason, 'reason', ExerciseMoveRefusal.incompatibleExercise),
        ),
      );

      answer({'error': 'bad request', 'code': 'bad_request', 'reason': 'targetId missing'}, 400);
      await expectLater(api.moveExerciseHistory('source', targetId: ''), throwsA(refused('bad_request')));
    });
  });
}
