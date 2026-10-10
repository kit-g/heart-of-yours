import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The server's side, in memory: the list it would answer with, and the
/// refusals it is told to give.
class _Server implements ApiTokenService {
  final tokens = <ApiToken>[];

  /// Thrown by the next create, as the service would throw the body.
  Object? refuseCreate;

  /// Thrown by the next revoke.
  Object? refuseRevoke;

  var lists = 0;
  var minted = 0;
  final revoked = <String>[];

  @override
  Future<Iterable<ApiToken>> listApiTokens() async {
    lists++;
    return List.of(tokens);
  }

  @override
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) async {
    if (refuseCreate case final refusal?) throw refusal;
    minted++;
    final token = ApiToken(
      id: 'minted-$minted',
      name: name,
      purpose: purpose,
      hint: 'h$minted',
      createdAt: DateTime.utc(2026, 10, minted),
      expiresAt: switch (expiry) {
        .year => DateTime.utc(2027, 10, minted),
        .never => null,
      },
    );
    tokens.insert(0, token);
    return MintedApiToken(token: token, secret: 'hrt_secret_$minted');
  }

  @override
  Future<void> revokeApiToken(String tokenId) async {
    if (refuseRevoke case final refusal?) throw refusal;
    revoked.add(tokenId);
    final index = tokens.indexWhere((token) => token.id == tokenId);
    if (index >= 0) tokens[index] = _token(tokenId, revokedAt: DateTime.utc(2026, 10, 10));
  }
}

ApiToken _token(String id, {DateTime? revokedAt, DateTime? expiresAt}) {
  return ApiToken(
    id: id,
    name: id,
    hint: 'abcd',
    createdAt: DateTime.utc(2026, 1, 1),
    revokedAt: revokedAt,
    expiresAt: expiresAt,
  );
}

void main() {
  late _Server server;
  late List<Object> errors;
  late ApiTokens sut;

  setUp(() {
    server = _Server();
    errors = [];
    sut = ApiTokens(service: server, onError: (error, {stacktrace}) => errors.add(error));
  });

  group('load', () {
    test('starts idle and reads the list on demand', () async {
      server.tokens.addAll([_token('a'), _token('b', revokedAt: DateTime.utc(2026, 2, 1))]);
      expect(sut.status, ApiTokensStatus.idle);

      final seen = <ApiTokensStatus>[];
      sut.addListener(() => seen.add(sut.status));
      await sut.load();

      expect(seen, [ApiTokensStatus.loading, ApiTokensStatus.loaded]);
      expect(sut.all.map((t) => t.id), ['a', 'b']);
      expect(sut.active.map((t) => t.id), ['a']);
      expect(sut.inactive.map((t) => t.id), ['b']);
    });

    test('a token past its expiry is inactive', () async {
      server.tokens.add(_token('old', expiresAt: DateTime.utc(2020)));
      await sut.load();
      expect(sut.active, isEmpty);
      expect(sut.inactive.single.id, 'old');
    });

    test('a failed read is reported and marked', () async {
      final failing = ApiTokens(service: _BrokenServer(), onError: (error, {stacktrace}) => errors.add(error));
      await failing.load();

      expect(failing.status, ApiTokensStatus.failed);
      expect(errors, hasLength(1));
    });

    test('nothing leaves while the remote leg is closed', () async {
      final closed = ApiTokens(service: server, remote: RemoteAccess(allowed: false));
      await closed.load();
      expect(server.lists, 0);
      expect(closed.status, ApiTokensStatus.idle);
    });
  });

  group('create', () {
    test('lists the new token first and hands back the secret', () async {
      server.tokens.add(_token('a'));
      await sut.load();

      final minted = await sut.create(name: 'My sheet', expiry: .year, purpose: .spreadsheet);

      expect(minted.secret, 'hrt_secret_1');
      expect(sut.all.first.id, 'minted-1');
      expect(sut.all.first.purpose, ApiTokenPurpose.spreadsheet);
      expect(sut.all, hasLength(2));
    });

    test('a refusal at the cap is thrown as such and re-reads the list', () async {
      await sut.load();
      server.tokens.addAll(List.generate(5, (i) => _token('elsewhere-$i')));
      server.refuseCreate = {'code': 'token_limit', 'reason': 'you can have at most 5 active tokens'};

      await expectLater(
        () => sut.create(name: 'one more', expiry: .never),
        throwsA(isA<ApiTokenRejected>().having((r) => r.isAtCapacity, 'isAtCapacity', isTrue)),
      );
      expect(server.lists, 2);
      expect(sut.isAtCapacity, isTrue);
    });

    test('any other refusal is thrown without a re-read', () async {
      await sut.load();
      server.refuseCreate = {'code': 'bad_request', 'reason': 'name is too long'};

      await expectLater(
        () => sut.create(name: 'x' * 101, expiry: .never),
        throwsA(isA<ApiTokenRejected>().having((r) => r.reason, 'reason', 'name is too long')),
      );
      expect(server.lists, 1);
    });

    test('an outage is rethrown as it came', () async {
      server.refuseCreate = StateError('offline');
      await expectLater(() => sut.create(name: 'n', expiry: .never), throwsStateError);
    });
  });

  group('revoke', () {
    test('marks the row revoked at once', () async {
      server.tokens.add(_token('a'));
      await sut.load();

      await sut.revoke(sut.all.single);

      expect(server.revoked, ['a']);
      expect(sut.active, isEmpty);
      // the server's stamp, from the re-read that follows
      expect(sut.inactive.single.revokedAt, DateTime.utc(2026, 10, 10));
      expect(server.lists, 2);
    });

    test('a token the server no longer knows drops out on the re-read', () async {
      server.tokens.add(_token('a'));
      await sut.load();
      server.tokens.clear();
      server.refuseRevoke = {'code': 'not_found', 'message': 'token #a not found'};

      await sut.revoke(sut.all.single);

      expect(sut.all, isEmpty);
      expect(sut.status, ApiTokensStatus.loaded);
    });

    test('capacity frees up with a revoke', () async {
      server.tokens.addAll(List.generate(5, (i) => _token('t$i')));
      await sut.load();
      expect(sut.isAtCapacity, isTrue);

      await sut.revoke(sut.all.first);

      expect(sut.isAtCapacity, isFalse);
    });
  });

  test('sign-out forgets the list', () async {
    server.tokens.add(_token('a'));
    await sut.load();

    sut.onSignOut();

    expect(sut.all, isEmpty);
    expect(sut.status, ApiTokensStatus.idle);
  });

  group('ApiTokenRejected.from', () {
    test('reads a code and either wording', () {
      expect(ApiTokenRejected.from({'code': 'token_limit', 'reason': 'r'})?.reason, 'r');
      expect(ApiTokenRejected.from({'code': 'not_found', 'message': 'm'})?.reason, 'm');
    });

    test('a server error and an unnamed failure are not refusals', () {
      expect(ApiTokenRejected.from({'code': 'server_error'}), isNull);
      expect(ApiTokenRejected.from(Exception('timeout')), isNull);
    });
  });
}

class _BrokenServer implements ApiTokenService {
  @override
  Future<Iterable<ApiToken>> listApiTokens() async => throw StateError('offline');

  @override
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) async => throw StateError('offline');

  @override
  Future<void> revokeApiToken(String tokenId) async => throw StateError('offline');
}
