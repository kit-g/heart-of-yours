import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The server's side, in memory, paging by two.
class _Server implements RosterService {
  final clients = <ClientSummary>[];
  final former = <ClientSummary>[];
  final feed = <CoachFeedItem>[];
  final reviewed = <String, DateTime?>{};

  Object? refuse;
  var reads = 0;

  ({List<T> items, String? cursor}) _page<T>(List<T> all, String? cursor, {int size = 2}) {
    final from = int.parse(cursor ?? '0');
    final to = from + size;
    return (items: all.skip(from).take(size).toList(), cursor: to < all.length ? '$to' : null);
  }

  @override
  Future<({List<ClientSummary> items, String? cursor})> getClients({bool former = false, String? cursor}) async {
    reads++;
    if (refuse case final refusal?) throw refusal;
    return _page(former ? this.former : clients, cursor);
  }

  @override
  Future<void> markReviewed(String connectionId, {DateTime? at}) async {
    if (refuse case final refusal?) throw refusal;
    reviewed[connectionId] = at;
  }

  @override
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) async {
    if (refuse case final refusal?) throw refusal;
    return _page(feed, cursor);
  }
}

ClientSummary _client(String name, {List<String> reasons = const [], List<DateTime> recent = const []}) {
  return ClientSummary(
    connectionId: 'c-$name',
    studentId: name,
    name: name,
    status: 'active',
    reasons: reasons,
    recent: recent,
  );
}

CoachFeedItem _item(String id) {
  return CoachFeedItem(kind: 'workout', id: id, studentId: 'muffin', at: DateTime.utc(2026, 11, 7));
}

void main() {
  late _Server server;
  late Roster roster;

  setUp(() {
    server = _Server();
    roster = Roster(service: server);
  });

  test('reads nothing until asked, and nothing with the remote leg closed', () async {
    expect(roster.status, CoachingStatus.idle);
    roster = Roster(service: server, remote: RemoteAccess(allowed: false));
    await roster.load();
    await roster.loadFeed();
    expect(server.reads, 0);
  });

  test('reads every page, in the order the server sorts', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['note']),
      _client('biscuit', reasons: ['gap']),
      _client('pepper'),
    ]);

    await roster.load();

    expect(roster.status, CoachingStatus.loaded);
    expect(roster.clients.map((each) => each.name), ['muffin', 'biscuit', 'pepper']);
    expect(server.reads, 2);
  });

  test('the reasons on show: known ones in order, an unknown one carried after', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['shrug', 'note']),
      _client('biscuit', reasons: ['ending', 'lighter']),
    ]);
    await roster.load();

    expect(roster.reasons, ['lighter', 'note', 'ending', 'shrug']);
    expect(roster.withReason('shrug').map((each) => each.name), ['muffin']);
  });

  test('a look clears what came before, and leaves what is still true to the server', () async {
    server.clients.addAll([
      _client('muffin', reasons: ['note', 'lighter']),
      _client('biscuit', reasons: ['gap', 'note', 'shrug']),
      _client('pepper'),
    ]);
    await roster.load();

    await roster.markReviewed(roster.clients.first);
    await roster.markReviewed(roster.clients.first);

    expect(server.reviewed.keys, {'c-muffin', 'c-biscuit'});
    expect(server.reviewed.values, everyElement(isNotNull));
    // a record holding a list compares the list by identity, so field by field
    expect(roster.clients.map((each) => each.name), ['biscuit', 'muffin', 'pepper']);
    expect(roster.clients.map((each) => each.reasons), [
      ['gap', 'shrug'],
      isEmpty,
      isEmpty,
    ]);
  });

  test('a refused look changes nothing here', () async {
    server.clients.add(_client('muffin', reasons: ['note']));
    await roster.load();
    server.refuse = {'code': 'not_found'};

    await expectLater(roster.markReviewed(roster.clients.single), throwsA(containsPair('code', 'not_found')));
    expect(roster.clients.single.reasons, ['note']);
  });

  test('a failed read reports the error and says so', () async {
    final errors = [];
    roster = Roster(service: server, onError: (error, {stacktrace}) => errors.add(error));
    server.refuse = {'code': 'server_error'};

    await roster.load();

    expect(roster.status, CoachingStatus.failed);
    expect(errors, hasLength(1));
  });

  test('former clients only when asked for', () async {
    server.former.add(_client('pepper'));
    expect(roster.formerStatus, CoachingStatus.idle);

    await roster.loadFormer();

    expect(roster.formerStatus, CoachingStatus.loaded);
    expect(roster.former.single.name, 'pepper');
  });

  test('the feed reads a page at a time, and a fresh read starts over', () async {
    server.feed.addAll([_item('a'), _item('b'), _item('c')]);

    await roster.loadFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b']);
    expect(roster.feedHasMore, isTrue);

    await roster.moreFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b', 'c']);
    expect(roster.feedHasMore, isFalse);

    await roster.moreFeed();
    await roster.loadFeed();
    expect(roster.feed.map((each) => each.id), ['a', 'b']);
  });

  test('signing out forgets everything', () async {
    server.clients.add(_client('muffin'));
    server.feed.add(_item('a'));
    await roster.load();
    await roster.loadFeed();

    roster.onSignOut();

    expect(roster.clients, isEmpty);
    expect(roster.feed, isEmpty);
    expect(roster.status, CoachingStatus.idle);
  });

  group('the last seven days', () {
    test("are the coach's days, oldest first, today last", () {
      final now = DateTime(2026, 11, 9, 8);
      final client = _client(
        'muffin',
        recent: [
          DateTime(2026, 11, 9, 7).toUtc(),
          DateTime(2026, 11, 7, 23, 30).toUtc(),
          DateTime(2026, 11, 7, 6).toUtc(),
          DateTime(2026, 11, 3, 0, 10).toUtc(),
          DateTime(2026, 11, 2, 23, 50).toUtc(),
        ],
      );

      expect(client.lastSevenDays(now), [true, false, false, false, true, false, true]);
    });

    test('nobody who never trained trained', () {
      expect(_client('muffin').lastSevenDays(DateTime(2026, 11, 9)), List.filled(7, false));
    });
  });
}
