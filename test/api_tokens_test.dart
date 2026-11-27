// Coverage for lib/presentation/routes/settings/api_tokens.dart (#271): the
// developer API's tokens from Settings for a signed-in user — the list with
// its two sections, the cap, a failed read, minting a token and seeing its
// secret once, the choices travelling with the request, and revoking.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

ApiToken _token(
  String id, {
  String? name,
  ApiTokenPurpose? purpose,
  DateTime? expiresAt,
  DateTime? revokedAt,
  DateTime? lastUsedAt,
}) {
  return ApiToken(
    id: id,
    name: name ?? id,
    purpose: purpose,
    hint: 'ab$id',
    createdAt: DateTime.utc(2026, 10, 5),
    expiresAt: expiresAt,
    revokedAt: revokedAt,
    lastUsedAt: lastUsedAt,
  );
}

const _secret = 'hrt_6PnLB1AcxbmXGK1ZeqJVevM9pFCAxx-i7iUShZD-hbo';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);
  });

  Future<void> pumpToTokens(WidgetTester tester, {Size size = const Size(1200, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    // dragged rather than ensureVisible: on a wide window that leaves a row
    // just below the fold where it is, and a tap then misses it
    await tester.dragUntilVisible(find.byKey(AppKeys.developerApi), find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpTimes();
    await tester.tapByKey(AppKeys.developerApi);
    await tester.pumpTimes();
    expect(find.byType(ApiTokensPage), findsOneWidget);
  }

  group('the list', () {
    testWidgets('shows live tokens with a revoke, past ones without, and offers a new one', (tester) async {
      when(api.listApiTokens()).thenAnswer(
        (_) async => [
          _token('live', name: 'My sheet', purpose: .spreadsheet, expiresAt: DateTime.utc(2027, 10, 5)),
          _token('gone', name: 'Old script', revokedAt: DateTime.utc(2026, 10, 1)),
          _token('stale', name: 'Last year', expiresAt: DateTime.utc(2025, 1, 1)),
        ],
      );
      await pumpToTokens(tester);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('No longer valid'), findsOneWidget);
      expect(find.text('My sheet'), findsOneWidget);
      expect(find.textContaining('A spreadsheet'), findsOneWidget);
      expect(find.textContaining('Expires'), findsOneWidget);
      expect(find.textContaining('Revoked'), findsOneWidget);
      expect(find.textContaining('Expired'), findsOneWidget);
      expect(find.textContaining('Never used'), findsNWidgets(3));
      expect(find.byKey(AppKeys.revokeApiToken('live')), findsOneWidget);
      expect(find.byKey(AppKeys.revokeApiToken('gone')), findsNothing);
      expect(find.byKey(AppKeys.revokeApiToken('stale')), findsNothing);
      expect(find.byKey(AppKeys.newApiToken), findsOneWidget);
    });

    testWidgets('says so when nothing was ever minted', (tester) async {
      when(api.listApiTokens()).thenAnswer((_) async => <ApiToken>[]);
      await pumpToTokens(tester);

      expect(find.text('Nothing minted yet.'), findsOneWidget);
      expect(find.byKey(AppKeys.newApiToken), findsOneWidget);
    });

    testWidgets('at the cap the create button gives way to the sentence that frees it', (tester) async {
      when(api.listApiTokens()).thenAnswer((_) async => List.generate(5, (i) => _token('t$i')));
      await pumpToTokens(tester);

      expect(find.byKey(AppKeys.newApiToken), findsNothing);
      expect(find.textContaining('Revoke one to make room'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry, which reads again', (tester) async {
      var reads = 0;
      when(api.listApiTokens()).thenAnswer((_) async {
        reads++;
        if (reads == 1) throw StateError('offline');
        return [_token('live', name: 'My sheet')];
      });
      await pumpToTokens(tester);

      expect(find.textContaining("didn't make it"), findsOneWidget);
      expect(find.byKey(AppKeys.newApiToken), findsNothing);

      await tester.tapByKey(AppKeys.retryApiTokens);
      await tester.pumpTimes();

      expect(find.text('My sheet'), findsOneWidget);
      expect(find.byKey(AppKeys.newApiToken), findsOneWidget);
    });
  });

  group('minting', () {
    setUp(() {
      when(api.listApiTokens()).thenAnswer((_) async => <ApiToken>[]);
      when(
        api.createApiToken(name: anyNamed('name'), expiry: anyNamed('expiry'), purpose: anyNamed('purpose')),
      ).thenAnswer((invocation) async {
        return MintedApiToken(
          token: _token(
            'new',
            name: invocation.namedArguments[#name] as String,
            purpose: invocation.namedArguments[#purpose] as ApiTokenPurpose?,
          ),
          secret: _secret,
        );
      });
    });

    testWidgets('shows the secret once, copies it, and lists the token on the way back', (tester) async {
      final clipboard = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          clipboard.add(call);
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpToTokens(tester);

      await tester.tapByKey(AppKeys.newApiToken);
      await tester.pumpTimes();
      expect(find.byType(NewApiTokenPage), findsOneWidget);

      // nothing to create until there is a name: the tap only puts the
      // caret back in the field
      await tester.tapByKey(AppKeys.createApiToken);
      await tester.pumpTimes();
      verifyNever(api.createApiToken(name: anyNamed('name'), expiry: anyNamed('expiry'), purpose: anyNamed('purpose')));
      expect(find.byType(NewApiTokenPage), findsOneWidget);
      await tester.enterText(find.byKey(AppKeys.apiTokenName), '  My sheet ');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.createApiToken);
      await tester.pumpTimes();

      verify(api.createApiToken(name: 'My sheet', expiry: ApiTokenExpiry.year, purpose: null)).called(1);
      expect(find.text(_secret), findsOneWidget);
      expect(find.text('Here it is'), findsOneWidget);

      await tester.tapByKey(AppKeys.copyApiToken);
      await tester.pumpTimes();
      final copied = clipboard.where((call) => call.method == 'Clipboard.setData').single;
      expect((copied.arguments as Map)['text'], _secret);
      expect(find.text('Copied'), findsOneWidget);

      await tester.tapByKey(AppKeys.apiTokenStored);
      await tester.pumpTimes();
      expect(find.byType(ApiTokensPage), findsOneWidget);
      expect(find.text('My sheet'), findsOneWidget);
      expect(find.text(_secret), findsNothing);
    });

    testWidgets('the expiry and purpose choices travel with the request', (tester) async {
      await pumpToTokens(tester);
      await tester.tapByKey(AppKeys.newApiToken);
      await tester.pumpTimes();

      await tester.tap(find.text('Never'));
      await tester.pumpTimes();
      await tester.tap(find.text('Not saying'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.apiTokenPurposeOption(ApiTokenPurpose.aiAssistant));
      await tester.pumpTimes();
      expect(find.text('An AI assistant'), findsOneWidget);

      await tester.enterText(find.byKey(AppKeys.apiTokenName), 'Claude');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.createApiToken);
      await tester.pumpTimes();

      verify(api.createApiToken(name: 'Claude', expiry: ApiTokenExpiry.never, purpose: ApiTokenPurpose.aiAssistant))
          .called(1);
      expect(find.text(_secret), findsOneWidget);
    });

    testWidgets('a refusal at the cap sends the form back to the list', (tester) async {
      when(
        api.createApiToken(name: anyNamed('name'), expiry: anyNamed('expiry'), purpose: anyNamed('purpose')),
      ).thenAnswer(
        (_) async => throw const ServerRefusal(
          status: 400,
          code: 'token_limit',
          method: 'POST',
          route: '/v1/accounts/tokens',
          details: {'reason': 'you can have at most 5 active tokens'},
        ),
      );
      await pumpToTokens(tester);
      await tester.tapByKey(AppKeys.newApiToken);
      await tester.pumpTimes();

      await tester.enterText(find.byKey(AppKeys.apiTokenName), 'One more');
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.createApiToken);
      await tester.pumpTimes();

      expect(find.byType(ApiTokensPage), findsOneWidget);
      expect(find.textContaining('Revoke one to make room'), findsWidgets);
      // the list re-read itself on the refusal
      verify(api.listApiTokens()).called(2);
    });
  });

  group('revoking', () {
    testWidgets('asks first, then moves the token to the past', (tester) async {
      // the server's list, which the revoke changes and the page re-reads
      var live = _token('live', name: 'My sheet');
      when(api.listApiTokens()).thenAnswer((_) async => [live]);
      when(api.revokeApiToken(any)).thenAnswer((_) async {
        live = _token('live', name: 'My sheet', revokedAt: DateTime.utc(2026, 10, 10));
      });
      await pumpToTokens(tester);

      await tester.tapByKey(AppKeys.revokeApiToken('live'));
      await tester.pumpTimes();
      expect(find.text('Revoke My sheet?'), findsOneWidget);
      verifyNever(api.revokeApiToken(any));

      await tester.tap(find.text('Keep it'));
      await tester.pumpTimes();
      expect(find.text('Revoke My sheet?'), findsNothing);
      expect(find.byKey(AppKeys.revokeApiToken('live')), findsOneWidget);

      await tester.tapByKey(AppKeys.revokeApiToken('live'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.confirmRevokeApiToken);
      await tester.pumpTimes();

      verify(api.revokeApiToken('live')).called(1);
      expect(find.byKey(AppKeys.revokeApiToken('live')), findsNothing);
      expect(find.text('No longer valid'), findsOneWidget);
      expect(find.textContaining('Revoked'), findsOneWidget);
    });
  });

  group('connected apps (#448)', () {
    ConnectedApp app(String id, {String? name, List<String> scopes = const ['read'], DateTime? lastUsedAt}) {
      return ConnectedApp(
        id: id,
        clientId: 'https://$id.example/metadata.json',
        name: name ?? id,
        scopes: scopes,
        resource: 'https://api.example.com/mcp',
        connectedAt: DateTime.utc(2026, 10, 18),
        lastUsedAt: lastUsedAt,
      );
    }

    setUp(() {
      when(api.listApiTokens()).thenAnswer((_) async => <ApiToken>[]);
    });

    testWidgets('the page is as it was for an account that let none in', (tester) async {
      when(api.listConnectedApps()).thenAnswer((_) async => <ConnectedApp>[]);
      await pumpToTokens(tester);

      expect(find.text('Connected apps'), findsNothing);
      expect(find.byKey(AppKeys.newApiToken), findsOneWidget);
    });

    testWidgets('a read that fails says so and can be asked again, and costs the tokens nothing', (tester) async {
      when(api.listConnectedApps()).thenThrow(Exception('offline'));
      await pumpToTokens(tester);

      expect(find.text('Connected apps'), findsOneWidget);
      expect(find.byKey(AppKeys.newApiToken), findsOneWidget);

      when(api.listConnectedApps()).thenAnswer((_) async => [app('writer', name: 'Assistant')]);
      await tester.tapByKey(AppKeys.retryConnectedApps);
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.retryConnectedApps), findsNothing);
      expect(find.text('Assistant'), findsOneWidget);
    });

    testWidgets('with both reads failed, the one Retry reads both again', (tester) async {
      when(api.listApiTokens()).thenThrow(Exception('offline'));
      when(api.listConnectedApps()).thenThrow(Exception('offline'));
      await pumpToTokens(tester);

      expect(find.byKey(AppKeys.retryApiTokens), findsOneWidget);
      expect(find.byKey(AppKeys.retryConnectedApps), findsNothing);

      when(api.listApiTokens()).thenAnswer((_) async => <ApiToken>[]);
      when(api.listConnectedApps()).thenAnswer((_) async => [app('writer', name: 'Assistant')]);
      await tester.tapByKey(AppKeys.retryApiTokens);
      await tester.pumpTimes();

      expect(find.text('Assistant'), findsOneWidget);
    });

    testWidgets('each app says what it may do, in words, beside when it connected', (tester) async {
      when(api.listConnectedApps()).thenAnswer(
        (_) async => [
          app(
            'writer',
            name: 'Assistant',
            scopes: ['read', 'write:templates'],
            lastUsedAt: DateTime.utc(2026, 11, 20, 12),
          ),
          app('reader', name: 'Reader'),
          app('coach', name: 'Coach desk', scopes: ['read', 'read:coaching']),
        ],
      );
      await pumpToTokens(tester);

      expect(find.text('Connected apps'), findsOneWidget);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.textContaining('Read your training · Create and change templates'), findsOneWidget);
      expect(find.textContaining('Last used Nov 20, 2026'), findsOneWidget);
      // one that only reads says only that
      final reader = tester.widget<Text>(
        find.descendant(of: find.byKey(AppKeys.connectedAppRow('reader')), matching: find.textContaining('Connected ')),
      );
      expect(reader.data, startsWith('Read your training\n'));
      expect(reader.data, contains('Never used'));
      expect(find.textContaining('Read your training · Read your clients’ training'), findsOneWidget);
      expect(find.byKey(AppKeys.disconnectApp('writer')), findsOneWidget);
      expect(find.byKey(AppKeys.disconnectApp('reader')), findsOneWidget);
    });

    testWidgets('a permission this build has no words for still shows, once', (tester) async {
      when(api.listConnectedApps()).thenAnswer(
        (_) async => [
          app('later', name: 'Later', scopes: ['read', 'write:workouts', 'write:programs']),
        ],
      );
      await pumpToTokens(tester);

      expect(find.textContaining('Read your training · Other access\n'), findsOneWidget);
    });

    testWidgets('disconnect asks first, then revokes the whole grant and drops the row', (tester) async {
      when(api.listConnectedApps()).thenAnswer(
        (_) async => [
          app('writer', name: 'Assistant', scopes: ['read', 'write:templates']),
        ],
      );
      when(api.disconnectApp(any)).thenAnswer((_) async {});
      await pumpToTokens(tester);

      await tester.tapByKey(AppKeys.disconnectApp('writer'));
      await tester.pumpTimes();
      expect(find.text('Disconnect Assistant?'), findsOneWidget);
      verifyNever(api.disconnectApp(any));

      await tester.tap(find.text('Keep it connected'));
      await tester.pumpTimes();
      expect(find.text('Disconnect Assistant?'), findsNothing);
      expect(find.byKey(AppKeys.connectedAppRow('writer')), findsOneWidget);

      await tester.tapByKey(AppKeys.disconnectApp('writer'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.confirmDisconnectApp);
      await tester.pumpTimes();

      // one call for the grant: read and write go together
      verify(api.disconnectApp('writer')).called(1);
      expect(find.byKey(AppKeys.connectedAppRow('writer')), findsNothing);
      expect(find.text('Connected apps'), findsNothing);
    });

    testWidgets('a disconnect that fails keeps the row and says so', (tester) async {
      when(api.listConnectedApps()).thenAnswer((_) async => [app('writer', name: 'Assistant')]);
      when(api.disconnectApp(any)).thenThrow(Exception('offline'));
      await pumpToTokens(tester);

      await tester.tapByKey(AppKeys.disconnectApp('writer'));
      await tester.pumpTimes();
      await tester.tapByKey(AppKeys.confirmDisconnectApp);
      await tester.pumpTimes();

      expect(find.byKey(AppKeys.connectedAppRow('writer')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('on a wide window the rows keep to the capped column', (tester) async {
      when(api.listConnectedApps()).thenAnswer((_) async => [app('writer', name: 'Assistant')]);
      await pumpToTokens(tester, size: const Size(1366, 1024));

      final row = tester.getRect(find.byKey(AppKeys.connectedAppRow('writer')));
      expect(row.width, lessThanOrEqualTo(640));
    });
  });

  group('on a wide window', () {
    testWidgets('the list is capped and centred like the settings it opened from', (tester) async {
      when(api.listApiTokens()).thenAnswer((_) async => [_token('live', name: 'My sheet')]);
      await pumpToTokens(tester, size: const Size(1366, 1024));

      final page = tester.getRect(find.byType(ApiTokensPage));
      final button = tester.getRect(find.byKey(AppKeys.newApiToken));
      expect(button.width, lessThanOrEqualTo(640));
      expect((button.center.dx - page.center.dx).abs(), lessThan(1));
    });

    testWidgets('the form is a readable column', (tester) async {
      when(api.listApiTokens()).thenAnswer((_) async => <ApiToken>[]);
      await pumpToTokens(tester, size: const Size(1366, 1024));
      await tester.tapByKey(AppKeys.newApiToken);
      await tester.pumpTimes();

      final field = tester.getRect(find.byKey(AppKeys.apiTokenName));
      expect(field.width, lessThanOrEqualTo(480));
    });
  });
}
