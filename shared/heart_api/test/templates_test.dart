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

  group('RemoteTemplateService', () {
    test('deleteTemplate returns true if code is 204', () async {
      respond(
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
      respond(
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

      respond(
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
      respond(
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

      respond(
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

      respond(
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
      respond(
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

    test('a folder this build cannot read costs that folder, not the list (#277)', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.templateFolders,
        statusCode: 200,
        body: {
          'folders': [
            {'id': 'f1', 'name': 'Push', 'order': 0, 'templateCount': 3},
            // a shape from a server newer than this build
            {
              'id': 'f2',
              'name': {'en': 'Pull'},
              'order': 1,
            },
          ],
        },
      );

      final result = await api.getFolders(userId: 'u1');
      expect(result.map((each) => each.id), ['f1']);
    });

    test('createFolder round-trips the folder', () async {
      respond(
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
      respond(
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
      respond(
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
      respond(
        client: client,
        method: 'DELETE',
        path: Router.templateFolder('f1'),
        statusCode: 204,
        body: {},
      );

      await api.deleteFolder(userId: 'u1', folderId: 'f1');
    });

    test('deleteFolder throws on somebody else\'s folder', () async {
      respond(
        client: client,
        method: 'DELETE',
        path: Router.templateFolder('f1'),
        statusCode: 404,
        body: {'error': 'not found'},
      );

      expect(() => api.deleteFolder(userId: 'u1', folderId: 'f1'), throwsA(isA<Map>()));
    });

    test('shareFolder returns one share per template assigned', () async {
      respond(
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
      respond(
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
}
