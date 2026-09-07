import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The store's side, in memory: how many workouts it holds, and whether it has
/// been marked whole.
class _Store implements LocalMirrorService {
  int held;
  final marked = <String>{};
  var summaries = 0;

  new({this.held = 0});

  @override
  Future<AccountSummary> mirrorSummary(String userId) async {
    summaries++;
    return AccountSummary(collections: {ExportableCollection.workouts: CollectionSummary(count: held)});
  }

  @override
  Future<bool> isHistoryBackfilled(String userId) async => marked.contains(userId);

  @override
  Future<void> markHistoryBackfilled(String userId) async => marked.add(userId);
}

/// The account's side, counting every call — the point of the mark is that
/// this stays at zero on an ordinary launch.
class _Account implements RemoteAccountSummaryService {
  final int? workouts;
  var calls = 0;

  new(this.workouts);

  @override
  Future<AccountSummary> getAccountSummary() async {
    calls++;
    return switch (workouts) {
      int count => AccountSummary(collections: {ExportableCollection.workouts: CollectionSummary(count: count)}),
      null => throw Exception('unreachable'),
    };
  }
}

/// Pages of a fixed size, landing in [store] as they are fetched.
class _Pager {
  final _Store store;
  final int pages;
  static const size = 20;
  final int? failsOn;

  /// Attempts, and the ones that came back — a refused page is refetched, so
  /// the walk is as long as it always was.
  var fetched = 0;
  var delivered = 0;

  new(this.store, {this.pages = 0, this.failsOn});

  Future<BackfillPage> next() async {
    fetched++;
    if (fetched == failsOn) throw Exception('unreachable');
    delivered++;
    store.held += size;
    return (stored: size, more: delivered < pages);
  }
}

void main() {
  const user = 'u1';

  Backfill build(_Store store, _Account account, _Pager pager, {RemoteAccess? access}) {
    return Backfill(
      local: store,
      remote: account,
      nextPage: pager.next,
      access: access ?? (RemoteAccess()..account = true),
    );
  }

  group('deciding whether to work', () {
    test('a marked device asks the server nothing and pages nothing', () async {
      final store = _Store(held: 20)..marked.add(user);
      final account = _Account(568);
      final pager = _Pager(store, pages: 27);

      await build(store, account, pager).run(user);

      // the whole point of the mark: an ordinary launch costs one local read
      // of the `syncs` table and not a single request
      expect(account.calls, 0);
      expect(pager.fetched, 0);
    });

    test('an already whole mirror settles on one request, without paging', () async {
      final store = _Store(held: 568);
      final account = _Account(568);
      final pager = _Pager(store, pages: 27);

      final backfill = build(store, account, pager);
      await backfill.run(user);

      expect(account.calls, 1);
      expect(pager.fetched, 0);
      expect(store.marked, contains(user));
      // nothing for the row to say
      expect(backfill.status, BackfillStatus.idle);
    });

    test('an anonymous session never starts one', () async {
      final store = _Store(held: 3);
      final account = _Account(568);
      final pager = _Pager(store, pages: 27);

      // no account behind the session: every remote leg is shut
      await build(store, account, pager, access: RemoteAccess(allowed: false)).run(user);

      expect(account.calls, 0);
      expect(pager.fetched, 0);
      expect(store.marked, isEmpty);
    });

    test('a replay still running owns the wire; the backfill waits for it', () async {
      final store = _Store(held: 3);
      final account = _Account(568);
      final pager = _Pager(store, pages: 27);
      final access = RemoteAccess()
        ..account = true
        ..replaying = true;

      await build(store, account, pager, access: access).run(user);

      expect(account.calls, 0);
      expect(pager.fetched, 0);
    });
  });

  group('paging', () {
    test('pages to the end and marks the mirror whole', () async {
      final store = _Store(held: 20);
      final account = _Account(100);
      final pager = _Pager(store, pages: 4);

      final backfill = build(store, account, pager);
      await backfill.run(user);

      expect(pager.fetched, 4);
      expect(store.held, 100);
      expect(store.marked, contains(user));
      expect(backfill.status, BackfillStatus.idle);
      // still one request: the total came from the same call that said to run
      expect(account.calls, 1);
    });

    test('counts towards the account\'s total while it runs', () async {
      final store = _Store(held: 20);
      final account = _Account(100);
      final pager = _Pager(store, pages: 4);
      final backfill = build(store, account, pager);

      final seen = <(int, int)>[];
      backfill.addListener(() => seen.add((backfill.done, backfill.total)));

      await backfill.run(user);

      expect(seen.first, (20, 100));
      expect(seen, contains((40, 100)));
      expect(seen.last, (100, 100));
    });

    test('a page that cannot be fetched stops the run and leaves the mark off', () async {
      final store = _Store(held: 20);
      final account = _Account(100);
      final pager = _Pager(store, pages: 4, failsOn: 2);

      final backfill = build(store, account, pager);
      await backfill.run(user);

      expect(pager.fetched, 2);
      expect(backfill.status, BackfillStatus.failed);
      // the mark is a claim the mirror is whole, and this run cannot make it
      expect(store.marked, isEmpty);
    });

    test('retry picks up from where it stopped', () async {
      final store = _Store(held: 20);
      final account = _Account(100);
      final pager = _Pager(store, pages: 4, failsOn: 2);

      final backfill = build(store, account, pager);
      await backfill.run(user);
      expect(backfill.status, BackfillStatus.failed);

      await backfill.retry();

      // the failed page is refetched, the run finishes, the mark lands
      expect(store.marked, contains(user));
      expect(backfill.status, BackfillStatus.idle);
    });

    test('a mirror that ends up short of the account is not marked', () async {
      final store = _Store(held: 20);
      // the server says 100, but paging runs out after one page of 20
      final account = _Account(100);
      final pager = _Pager(store, pages: 1);

      await build(store, account, pager).run(user);

      // `hasMore: false` said paging finished; the count says the mirror is
      // not the account, so the next launch tries again
      expect(store.held, 40);
      expect(store.marked, isEmpty);
    });
  });

  group('when the account cannot be counted', () {
    test('the run goes ahead on the server\'s hasMore alone', () async {
      final store = _Store(held: 20);
      final account = _Account(null);
      final pager = _Pager(store, pages: 3);

      final backfill = build(store, account, pager);
      await backfill.run(user);

      expect(pager.fetched, 3);
      // no total to count towards: the row shows an indeterminate bar
      expect(backfill.total, 0);
      // paging is all there is to go on, and it says the mirror is whole
      expect(store.marked, contains(user));
    });
  });

  group('sign-out', () {
    test('abandons a run rather than finishing it under the next account', () async {
      final store = _Store(held: 20);
      final account = _Account(100);
      final pager = _Pager(store, pages: 4);
      final backfill = build(store, account, pager);

      backfill.addListener(() {
        if (backfill.done >= 40) backfill.onSignOut();
      });

      await backfill.run(user);

      expect(backfill.userId, isNull);
      expect(backfill.status, BackfillStatus.idle);
      // whatever it had fetched is stored; what it had not is nobody's problem
      expect(store.marked, isEmpty);
    });
  });
}
