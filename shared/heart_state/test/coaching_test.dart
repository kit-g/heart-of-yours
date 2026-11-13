import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The server's side, in memory.
class _Server implements CoachingService {
  final connections = <Connection>[];
  final hidden = <String, DateTime>{};

  /// Thrown by the next write, as the service would throw the body.
  Object? refuse;

  var reads = 0;

  Connection _write(String id, Connection Function(Connection) change) {
    if (refuse case final refusal?) throw refusal;
    final index = connections.indexWhere((each) => each.connectionId == id);
    return connections[index] = change(connections[index]);
  }

  @override
  Future<List<Connection>> getConnections() async {
    reads++;
    return List.of(connections);
  }

  @override
  Future<Connection> setConnectionShares(String connectionId, Set<String> shares) async {
    return _write(connectionId, (each) => _with(each, shares: [...shares]));
  }

  @override
  Future<Connection> setConnectionStatus(String connectionId, ConnectionStatus status) async {
    return _write(connectionId, (each) => _with(each, status: status));
  }

  @override
  Future<void> endConnection(String connectionId) async {
    _write(connectionId, (each) => _with(each, status: .severed));
  }

  @override
  Future<List<HiddenWorkout>> getHiddenWorkouts() async {
    return [for (final MapEntry(:key, :value) in hidden.entries) HiddenWorkout(id: key, at: value)];
  }

  @override
  Future<void> hideWorkout(String workoutId, {DateTime? at}) async {
    if (refuse case final refusal?) throw refusal;
    hidden[workoutId] = at ?? DateTime.utc(2026);
  }

  @override
  Future<void> unhideWorkout(String workoutId) async {
    hidden.remove(workoutId);
  }

  // ---- invitations ----

  final invitations = <Invitation>[];
  final blocked = <BlockedPerson>[];
  final declined = <String>[];
  final blockedLinks = <String>[];
  var tokens = 0;

  /// Pages of two, as a paging server would hand them over.
  static const _page = 2;

  Invitation _invitation(String id, String name, {String status = 'pending', String? token}) {
    return Invitation(
      id: id,
      name: name,
      status: status,
      role: 'COACH',
      domain: 'fitness',
      expiresAt: DateTime.utc(2026, 11, 15),
      createdAt: DateTime.utc(2026, 11, 8),
      token: token,
    );
  }

  @override
  Future<Invitation> createInvitation(String name, {String? programId}) async {
    if (refuse case final refusal?) throw refusal;
    final invitation = _invitation('i${invitations.length}', name, token: 'token-${tokens++}');
    invitations.insert(0, invitation);
    return invitation;
  }

  @override
  Future<({List<Invitation> items, String? cursor})> getInvitations({String? cursor}) async {
    final start = int.parse(cursor ?? '0');
    final end = (start + _page).clamp(0, invitations.length);
    return (items: invitations.sublist(start, end), cursor: end < invitations.length ? '$end' : null);
  }

  @override
  Future<Invitation> resendInvitation(String invitationId) async {
    final old = invitations.firstWhere((each) => each.id == invitationId);
    return _invitation(old.id, old.name, token: 'token-${tokens++}');
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {}

  @override
  Future<InvitationPreview?> previewInvitation(String token) async {
    return switch (token) {
      'good' => InvitationPreview.fromJson({'inviterName': 'Alex', 'good': true}),
      'gone' => InvitationPreview.fromJson({'good': false}),
      _ => null,
    };
  }

  @override
  Future<AcceptedInvitation> acceptInvitation(String token, Set<ConnectionShare> shares) async {
    if (refuse case final refusal?) throw refusal;
    final connection = _connection('alex', .student, shares: [for (final share in shares) share.name]);
    connections.add(connection);
    return AcceptedInvitation(connection);
  }

  @override
  Future<void> declineInvitation(String token) async => declined.add(token);

  @override
  Future<void> blockInviter(String token) async => blockedLinks.add(token);

  @override
  Future<({List<BlockedPerson> items, String? cursor})> getBlocks({String? cursor}) async {
    return (items: List.of(blocked), cursor: null);
  }

  @override
  Future<void> liftBlock(String userId) async => blocked.removeWhere((each) => each.id == userId);
}

Connection _connection(
  String targetId,
  ConnectionRole role, {
  ConnectionStatus status = .active,
  List<String> shares = const [],
}) {
  return Connection(
    targetId: targetId,
    role: role,
    domain: .fitness,
    status: status,
    createdAt: DateTime.utc(2026, 11, 7),
    connectionId: 'connection-$targetId',
    acceptedAt: DateTime.utc(2026, 11, 7),
    shares: shares,
  );
}

Connection _with(Connection connection, {ConnectionStatus? status, List<String>? shares}) {
  return Connection(
    targetId: connection.targetId,
    role: connection.role,
    domain: connection.domain,
    status: status ?? connection.status,
    createdAt: connection.createdAt,
    connectionId: connection.connectionId,
    acceptedAt: connection.acceptedAt,
    shares: shares ?? connection.shares,
  );
}

void main() {
  late _Server server;
  late Coaching coaching;

  setUp(() {
    server = _Server();
    coaching = Coaching(service: server);
  });

  test('reads nothing until asked', () {
    expect(coaching.status, CoachingStatus.idle);
    expect(server.reads, 0);
  });

  test("sorts this account's clients from its coaches, live or paused, never ended", () async {
    server.connections.addAll([
      _connection('muffin', .coach),
      _connection('biscuit', .coach, status: .paused),
      _connection('pepper', .coach, status: .severed),
      _connection('alex', .student),
      _connection('sam', .peer),
    ]);

    await coaching.load();

    expect(coaching.status, CoachingStatus.loaded);
    expect(coaching.clients.map((each) => each.targetId), ['muffin', 'biscuit']);
    expect(coaching.coaches.map((each) => each.targetId), ['alex']);
    expect(coaching.hasCoach, isTrue);
    expect(coaching.all, hasLength(5));
  });

  test('a closed remote leg reads nothing: coaching needs an account', () async {
    coaching = Coaching(service: server, remote: RemoteAccess(allowed: false));
    await coaching.load();
    expect(server.reads, 0);
    expect(coaching.status, CoachingStatus.idle);
  });

  test('a failed read reports the error and says so', () async {
    final errors = [];
    coaching = Coaching(service: _Failing(), onError: (error, {stacktrace}) => errors.add(error));
    await coaching.load();
    expect(coaching.status, CoachingStatus.failed);
    expect(errors, hasLength(1));
  });

  test("a student's shares change once the server agrees", () async {
    server.connections.add(_connection('alex', .student, shares: ['history']));
    await coaching.load();

    await coaching.setShares(coaching.coaches.single, {.history, .goals});

    expect(coaching.coaches.single.shares, ['history', 'goals']);
  });

  test('a share this build does not know goes back as it came', () async {
    server.connections.add(_connection('alex', .student, shares: ['history', 'photos']));
    await coaching.load();

    await coaching.setShares(coaching.coaches.single, {.goals});

    expect(coaching.coaches.single.shares.toSet(), {'goals', 'photos'});
  });

  test('a refused write throws and changes nothing here', () async {
    server.connections.add(_connection('muffin', .coach));
    await coaching.load();
    server.refuse = {'code': 'forbidden'};

    await expectLater(
      coaching.setShares(coaching.clients.single, {.goals}),
      throwsA(containsPair('code', 'forbidden')),
    );
    expect(coaching.clients.single.shares, isEmpty);
  });

  test('pausing keeps a connection current, and ending takes it out', () async {
    server.connections.add(_connection('alex', .student));
    await coaching.load();

    await coaching.pause(coaching.coaches.single);
    expect(coaching.coaches.single.status, ConnectionStatus.paused);

    await coaching.resume(coaching.coaches.single);
    expect(coaching.coaches.single.status, ConnectionStatus.active);

    await coaching.end(coaching.coaches.single);
    expect(coaching.coaches, isEmpty);
    expect(coaching.all.single.status, ConnectionStatus.severed);
  });

  test('blocking ends a connection, kept as blocked', () async {
    server.connections.add(_connection('alex', .student));
    await coaching.load();

    await coaching.block(coaching.coaches.single);

    expect(coaching.coaches, isEmpty);
    expect(coaching.all.single.status, ConnectionStatus.blocked);
  });

  test('hiding and unhiding a workout', () async {
    server.hidden['already'] = DateTime.utc(2026, 11, 1);
    await coaching.load();
    expect(coaching.isHidden('already'), isTrue);

    await coaching.hide('legs');
    expect(coaching.hiddenWorkouts, {'already', 'legs'});
    expect(server.hidden.keys, contains('legs'));

    await coaching.unhide('already');
    expect(coaching.hiddenWorkouts, {'legs'});
  });

  test('a hide the server refused leaves the workout visible', () async {
    server.refuse = {'code': 'not_found'};
    await expectLater(coaching.hide('gone'), throwsA(anything));
    expect(coaching.isHidden('gone'), isFalse);
  });

  test('signing out forgets everything', () async {
    server.connections.add(_connection('muffin', .coach));
    server.hidden['legs'] = DateTime.utc(2026);
    await coaching.load();

    coaching.onSignOut();

    expect(coaching.all, isEmpty);
    expect(coaching.hiddenWorkouts, isEmpty);
    expect(coaching.status, CoachingStatus.idle);
  });

  group('invitations (#553)', () {
    test('every page of them is read, newest first', () async {
      for (final name in ['Muffin', 'Biscuit', 'Pepper']) {
        await server.createInvitation(name);
      }
      await coaching.loadInvitations();
      expect(coaching.invitations.map((each) => each.name), ['Pepper', 'Biscuit', 'Muffin']);
    });

    test('a new one is at the top, carrying the token to share', () async {
      await coaching.loadInvitations();
      final invitation = await coaching.invite('Muffin');
      expect(invitation.token, isNotNull);
      expect(coaching.invitations.first.name, 'Muffin');
      expect(coaching.pendingInvitations, hasLength(1));
    });

    test('a refused one throws and lists nothing', () async {
      server.refuse = {'code': 'coaching_beta'};
      await expectLater(coaching.invite('Muffin'), throwsA(containsPair('code', 'coaching_beta')));
      expect(coaching.invitations, isEmpty);
    });

    test('resending replaces the link; cancelling leaves it listed, canceled', () async {
      final first = await coaching.invite('Muffin');
      final renewed = await coaching.resend(first);
      expect(renewed.token, isNot(first.token));
      expect(coaching.invitations.single.token, renewed.token);

      await coaching.cancel(coaching.invitations.single);
      expect(InvitationStatus.of(coaching.invitations.single), InvitationStatus.canceled);
      expect(coaching.pendingInvitations, isEmpty);
    });

    test('a status this build does not know reads as no longer good', () {
      final invitation = Invitation(
        id: 'i',
        name: 'Muffin',
        status: 'withdrawn-by-moon',
        role: 'COACH',
        domain: 'fitness',
        expiresAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
      );
      expect(InvitationStatus.of(invitation), InvitationStatus.expired);
    });

    test('accepting a link puts the coach among this account\'s coaches at once', () async {
      expect((await coaching.preview('good'))?.inviterName, 'Alex');
      expect((await coaching.preview('gone'))?.good, isFalse);
      expect(await coaching.preview('never'), isNull);

      await coaching.accept('good', {.history});

      expect(coaching.coaches.single.targetId, 'alex');
      expect(coaching.coaches.single.shares, ['history']);
    });

    test('declining and blocking a link go to the server', () async {
      await coaching.decline('good');
      await coaching.blockInviter('good');
      expect(server.declined, ['good']);
      expect(server.blockedLinks, ['good']);
    });

    test('blocks are listed, and lifting one takes it off', () async {
      server.blocked.add(BlockedPerson.fromJson({'id': 'alex', 'name': 'Alex', 'since': '2026-11-07T21:05:35Z'}));
      await coaching.loadBlocks();
      expect(coaching.blocks.single.name, 'Alex');

      await coaching.lift(coaching.blocks.single);
      expect(coaching.blocks, isEmpty);
      expect(server.blocked, isEmpty);
    });

    test('signing out forgets invitations and blocks too', () async {
      await coaching.invite('Muffin');
      coaching.onSignOut();
      expect(coaching.invitations, isEmpty);
    });
  });

  test('the coach entitlement is read off the account', () {
    User user(List<String> entitlements) => User(id: 'u', entitlements: entitlements);
    expect(user(['coach']).mayCoach, isTrue);
    expect(user([]).mayCoach, isFalse);
  });
}

class _Failing extends _Server {
  @override
  Future<List<Connection>> getConnections() async => throw StateError('offline');
}
