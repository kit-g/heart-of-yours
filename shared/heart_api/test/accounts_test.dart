import 'dart:convert';

import 'package:heart_api/src/api.dart';
import 'package:heart_models/heart_models.dart';
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

  group('AccountService', () {
    test('registerAccount returns User on 200', () async {
      final user = User(id: '42', displayName: 'Jane');

      respond(
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

      respond(
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

      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 500,
        body: {'error': 'unexpected'},
      );

      expect(() => api.registerAccount(user), throwsA(isA<NetworkException>().having((e) => e.body, 'body', isNull)));
    });

    // Scheduling a deletion is an action on `PUT /accounts`, not `DELETE` —
    // the body is the point, so these assert on it rather than on the verb
    // alone. A stub that matches the method and ignores the payload would pass
    // against an app sending the wrong action, or half an Apple grant, which
    // the server rejects with `incomplete_apple_grant`.
    test('deleteAccount PUTs the scheduling action and returns null on success', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 200,
        body: {'id': '42', 'scheduledForDeletionAt': '2026-10-19T01:14:36.000Z'},
      );

      final result = await api.deleteAccount(accountId: '42');
      expect(result, isNull);

      final sent = verify(
        client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured.single;
      expect(jsonDecode(sent as String), {'action': 'scheduleAccountDeletion'});
    });

    test('deleteAccount carries both Apple fields when a grant is given', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 200,
        body: {'id': '42'},
      );

      await api.deleteAccount(
        accountId: '42',
        appleGrant: const AppleDeletionGrant(authorizationCode: 'c1a2b3', clientId: 'me.heart-of.ios'),
      );

      final sent = verify(
        client.put(any, headers: anyNamed('headers'), body: captureAnyNamed('body')),
      ).captured.single;
      expect(jsonDecode(sent as String), {
        'action': 'scheduleAccountDeletion',
        'appleAuthorizationCode': 'c1a2b3',
        'appleClientId': 'me.heart-of.ios',
      });
    });

    test('deleteAccount throws on error (>=400)', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 404,
        body: {'error': 'Not Found'},
      );

      expect(
        () => api.deleteAccount(accountId: '42'),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    // The path is the assertion here, not decoration: these four stubbed
    // `accounts/42` for years, so they passed against an app that PUT to a
    // route the API never registered and got `404 not_found` every time. The
    // user is read off the auth token; the id never belonged in the URL.
    test('getAvatarUploadLink returns PreSignedUrl on valid json', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
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
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 200,
        body: {'message': 'bad response'},
      );

      final result = await api.getAvatarUploadLink('42');
      expect(result, isNull);
    });

    test('removeAvatar returns true on success', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 200,
        body: {},
      );

      final result = await api.removeAvatar('42');
      expect(result, isTrue);
    });

    test('removeAvatar throws a failure', () async {
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 500,
        body: {},
      );

      await expectLater(api.removeAvatar('42'), throwsA(isA<NetworkException>()));
    });

    test('undoAccountDeletion returns null on success', () async {
      respond(
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
      respond(
        client: client,
        method: 'PUT',
        path: Router.accounts,
        statusCode: 400,
        body: {'error': 'bad request'},
      );

      expect(
        () => api.undoAccountDeletion(),
        throwsA(isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('account summary', () {
    test('getAccountSummary parses every collection it knows', () async {
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/summary',
        statusCode: 200,
        body: {
          'collections': {
            'customExercises': {'count': 7, 'latestId': '0197b3'},
            'workouts': {'count': 412, 'latestId': '0198d4'},
            'connections': {'count': 2},
          },
        },
      );

      final summary = await api.getAccountSummary();

      expect(summary[.customExercises].count, 7);
      expect(summary[.customExercises].latestId, '0197b3');
      expect(summary[.workouts].count, 412);
      // the one collection whose rows have no id of their own
      expect(summary[.connections].count, 2);
      expect(summary[.connections].latestId, isNull);
      // a collection the server did not report reads as zero
      expect(summary[.goals].count, 0);
      expect(summary.total, 421);
    });

    test('getAccountSummary skips a collection this build has never heard of', () async {
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/summary',
        statusCode: 200,
        body: {
          'collections': {
            'workouts': {'count': 3, 'latestId': '0198d4'},
            'somethingNewer': {'count': 99, 'latestId': '0199ff'},
          },
        },
      );

      final summary = await api.getAccountSummary();

      expect(summary.collections.keys, [ExportableCollection.workouts]);
      // the unknown collection does not silently inflate the total either
      expect(summary.total, 3);
    });

    test('getAccountSummary throws on a refusal rather than answering empty', () async {
      respond(
        client: client,
        method: 'GET',
        path: '${Router.accounts}/summary',
        statusCode: 500,
        body: {'code': 'boom'},
      );

      // an empty summary would read as "your mirror is complete"
      await expectLater(api.getAccountSummary, throwsA(anything));
    });
  });

  group('ApiTokenService (heart-api#111)', () {
    const minted = {
      'id': '01a10960-7cfa-7903-ab88-cd79b607caed',
      'name': 'My sheet',
      'purpose': 'spreadsheet',
      'hint': '-hbo',
      'scopes': ['read'],
      'createdAt': '2026-10-05T00:04:40.825245Z',
      'expiresAt': '2027-10-05T00:04:40.820101Z',
      'secret': 'hrt_6PnLB1AcxbmXGK1ZeqJVevM9pFCAxx-i7iUShZD-hbo',
    };

    test('listApiTokens reads every token, newest first, with its dates', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.accountTokens,
        statusCode: 200,
        body: {
          'tokens': [
            {
              'id': '01a10960-7d14-7cb5-9a4c-fe244bdb76c9',
              'name': 'n4',
              'hint': '2ruU',
              'scopes': ['read'],
              'createdAt': '2026-10-05T00:04:40.852563Z',
            },
            {
              ...minted,
              'revokedAt': '2026-10-05T00:04:40.840568Z',
            }..remove('secret'),
          ],
        },
      );

      final tokens = (await api.listApiTokens()).toList();

      expect(tokens.map((t) => t.name), ['n4', 'My sheet']);
      expect(tokens.first.expiresAt, isNull);
      expect(tokens.first.purpose, isNull);
      expect(tokens.first.isActive(), isTrue);
      expect(tokens.last.purpose, ApiTokenPurpose.spreadsheet);
      expect(tokens.last.revokedAt, isNotNull);
      expect(tokens.last.isActive(), isFalse);
    });

    test('listApiTokens keeps a token whose purpose this build cannot name', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.accountTokens,
        statusCode: 200,
        body: {
          'tokens': [
            {...minted, 'purpose': 'quantumToaster'}..remove('secret'),
          ],
        },
      );

      final token = (await api.listApiTokens()).single;

      expect(token.id, minted['id']);
      expect(token.purpose, isNull);
    });

    test('listApiTokens is empty for an account that never minted one', () async {
      respond(client: client, method: 'GET', path: Router.accountTokens, statusCode: 200, body: {'tokens': []});
      expect(await api.listApiTokens(), isEmpty);
    });

    test('createApiToken sends the choice and returns the secret once', () async {
      respond(client: client, method: 'POST', path: Router.accountTokens, statusCode: 201, body: minted);

      final result = await api.createApiToken(name: 'My sheet', expiry: .year, purpose: .spreadsheet);

      expect(result.secret, minted['secret']);
      expect(result.token.hint, '-hbo');
      expect(result.token.purpose, ApiTokenPurpose.spreadsheet);
      final sent = verify(
        client.post(
          Uri.https('api.example.com', Router.accountTokens),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'name': 'My sheet', 'expiry': 'year', 'purpose': 'spreadsheet'});
    });

    test('createApiToken leaves out a purpose that was not chosen', () async {
      respond(client: client, method: 'POST', path: Router.accountTokens, statusCode: 201, body: minted);

      await api.createApiToken(name: 'My sheet', expiry: .never);

      final sent = verify(
        client.post(
          Uri.https('api.example.com', Router.accountTokens),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single;
      expect(jsonDecode(sent as String), {'name': 'My sheet', 'expiry': 'never'});
    });

    test('createApiToken throws the cap as a refusal', () async {
      respond(
        client: client,
        method: 'POST',
        path: Router.accountTokens,
        statusCode: 400,
        body: {
          'error': 'bad request',
          'code': 'token_limit',
          'reason': 'you can have at most 5 active tokens; revoke one first',
        },
      );

      expect(
        () => api.createApiToken(name: 'one more', expiry: .year),
        throwsA(refused('token_limit')),
      );
    });

    test('revokeApiToken is quiet on 204', () async {
      respond(client: client, method: 'DELETE', path: Router.accountToken('t1'), statusCode: 204, body: {});
      await expectLater(api.revokeApiToken('t1'), completes);
    });

    test('revokeApiToken throws the 404 as a refusal', () async {
      respond(
        client: client,
        method: 'DELETE',
        path: Router.accountToken('nope'),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'not_found', 'message': 'token #nope not found'},
      );
      expect(() => api.revokeApiToken('nope'), throwsA(refused('not_found')));
    });
  });

  group('connected apps (#448)', () {
    const assistant = {
      'id': '01a1f717-611c-7353-b8d4-89b94a6856fd',
      'clientId': 'https://assistant.example/oauth/metadata.json',
      'name': 'Assistant',
      'scopes': ['read', 'write:templates'],
      'resource': 'https://api.example.com/mcp',
      'connectedAt': '2026-10-18T10:00:00.000Z',
      'lastUsedAt': '2026-11-20T08:30:00.000Z',
    };

    test('listConnectedApps reads each app with the scopes it holds', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.connectedApps,
        statusCode: 200,
        body: {
          'apps': [
            assistant,
            {
              ...assistant,
              'id': 'second',
              'name': 'Reader',
              'scopes': ['read'],
            }..remove('lastUsedAt'),
          ],
        },
      );

      final apps = (await api.listConnectedApps()).toList();

      expect(apps.map((app) => app.name), ['Assistant', 'Reader']);
      expect(apps.first.scopes, ['read', 'write:templates']);
      expect(apps.first.lastUsedAt, DateTime.utc(2026, 11, 20, 8, 30));
      expect(apps.last.scopes, ['read']);
      expect(apps.last.lastUsedAt, isNull);
    });

    test('listConnectedApps passes over a row this build cannot read', () async {
      respond(
        client: client,
        method: 'GET',
        path: Router.connectedApps,
        statusCode: 200,
        body: {
          'apps': [
            {'id': 'broken'},
            assistant,
          ],
        },
      );

      expect((await api.listConnectedApps()).map((app) => app.name), ['Assistant']);
    });

    test('listConnectedApps is empty for an account that connected none', () async {
      respond(client: client, method: 'GET', path: Router.connectedApps, statusCode: 200, body: {'apps': []});
      expect(await api.listConnectedApps(), isEmpty);
    });

    test('disconnectApp is quiet on 204', () async {
      respond(client: client, method: 'DELETE', path: Router.connectedApp('g1'), statusCode: 204, body: {});
      await expectLater(api.disconnectApp('g1'), completes);
    });

    test('disconnectApp throws the 404 as a refusal', () async {
      respond(
        client: client,
        method: 'DELETE',
        path: Router.connectedApp('nope'),
        statusCode: 404,
        body: {'error': 'not found', 'code': 'not_found', 'message': 'connected app #nope not found'},
      );
      expect(() => api.disconnectApp('nope'), throwsA(refused('not_found')));
    });
  });
}
