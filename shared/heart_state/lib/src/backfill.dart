import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

/// The account's own totals, collection by collection.
///
/// Defined here rather than added to `AccountService`: that interface is the
/// contract heart-api implements, and the app has no server-side counting to
/// implement (the API takes the same view — see its `ApiProfileService`). The
/// app adapts `Api` onto this, the way `RemoteExercisePreferenceService` is
/// adapted.
abstract interface class RemoteAccountSummaryService {
  Future<AccountSummary> getAccountSummary();
}

/// The same shape, from the store, plus the mark that says the store is whole.
///
/// Only the collections a mirror can honestly count appear in [mirrorSummary]
/// — the database decides which.
abstract interface class LocalMirrorService {
  Future<AccountSummary> mirrorSummary(String userId);

  /// Whether [userId]'s history has been paged down in full on this device.
  Future<bool> isHistoryBackfilled(String userId);

  /// Records that it has. Cleared by an erase, and never written on a run that
  /// could not confirm the count.
  Future<void> markHistoryBackfilled(String userId);

  /// Takes the mark back — see [Backfill.resync].
  Future<void> clearHistoryBackfilled(String userId);
}

/// One page of older history, stored and absorbed: how many rows it carried,
/// and whether the server has more behind it.
typedef BackfillPage = ({int stored, bool more});

enum BackfillStatus {
  /// Nothing to show: never run, already whole, or finished.
  idle,

  running,

  /// A page could not be fetched. The run stopped where it stood and the mark
  /// was not written, so the next launch — or [retry] — picks it up.
  failed,
}

/// Fills in the history the mirror does not hold, once per account per device.
///
/// The pull counterpart of [Upsync]. The account's workouts are paged, and
/// `initHistory` only ever asks for the newest page, so a device that has not
/// been scrolled through History holds a *prefix* — and every number the app
/// computes locally is computed off that prefix: the per-week chart
/// (`Stats.getWorkoutSummary`), a workouts goal (`getMonthlyWorkoutCount`),
/// the exercise charts, the records, the export. None of them are wrong about
/// the rows they see; they are seeing the wrong rows.
///
/// So the fix is not to warn the user, it is to stop being a prefix.
///
/// **The mark, not the endpoint, decides whether to work.** `GET
/// /accounts/summary` is not polled: a launch under a marked uid makes no
/// request at all, and an unmarked one makes exactly one — which answers both
/// questions at once, "is this device short?" and "short of what?", the second
/// being the total the row counts towards. A device that is already whole
/// settles on that one call without paging.
class Backfill with ChangeNotifier implements SignOutStateSentry {
  final LocalMirrorService _local;
  final RemoteAccountSummaryService _remote;
  final RemoteAccess _access;

  /// Fetches, stores and absorbs the next older page — `Workouts`' own paging,
  /// minus the flag that puts a spinner on History's tail. This is background
  /// work and must not look like the user asked for a page.
  final Future<BackfillPage> Function() _nextPage;

  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required this._local,
    required this._remote,
    required this._nextPage,
    RemoteAccess? access,
    this.onError,
  }) : _access = access ?? RemoteAccess();

  static Backfill of(BuildContext context) => Provider.of<Backfill>(context, listen: false);

  static Backfill watch(BuildContext context) => Provider.of<Backfill>(context, listen: true);

  BackfillStatus _status = .idle;

  BackfillStatus get status => _status;

  /// The uid the current or last run was for.
  String? userId;

  int _done = 0;

  int _total = 0;

  /// Workouts the mirror holds, and the account's own count. [total] is `0`
  /// when the summary could not be read — the run goes ahead on the server's
  /// `hasMore` alone, and the row shows an indeterminate bar.
  int get done => _done;

  int get total => _total;

  Future<void>? _running;

  @override
  void onSignOut() {
    // a run still going is the old account's; it checks at every page
    userId = null;
    _running = null;
    _status = .idle;
    _done = 0;
    _total = 0;
  }

  /// Runs the backfill from wherever the mirror stands. Shares one run between
  /// concurrent callers.
  Future<void> run(String uid) {
    return _running ??= _run(uid).whenComplete(() => _running = null);
  }

  /// The account gained rows this device did not put there: a Strong import,
  /// which is written server-side and lands whole (heart-api#44). The mark was
  /// earned against the account as it stood *before* that, so it is now a claim
  /// this device cannot make — it goes, and the run starts over.
  ///
  /// Without this the newest page is all an import ever brings down. A brand
  /// new account is marked the moment it signs in, seconds before the import
  /// fills it, and 21 imported workouts arrive as the 20 the first page holds.
  Future<void> resync(String uid) async {
    await _local.clearHistoryBackfilled(uid);
    return run(uid);
  }

  /// Retries a run that stopped on an unreachable server.
  Future<void> retry() {
    return switch (userId) {
      String uid => run(uid),
      null => Future.value(),
    };
  }

  Future<void> _run(String uid) async {
    userId = uid;
    // no account, or an upsync still replaying into one: the replay owns the
    // wire until it is done, and re-pulls afterwards
    if (!_access.allowed) return;
    if (await _local.isHistoryBackfilled(uid)) return;

    final held = await _heldWorkouts(uid);
    final target = await _accountWorkouts();

    // Already whole — the common case for an install upgrading into this,
    // and the whole point of asking before paging. One request, no row.
    if (target case int count when held >= count) {
      await _local.markHistoryBackfilled(uid);
      return;
    }

    _done = held;
    _total = target ?? 0;
    _status = .running;
    notifyListeners();

    while (true) {
      // signed out mid-run: the pages that follow would be someone else's
      if (userId != uid) return;

      final BackfillPage(:stored, :more) = switch (await _page()) {
        BackfillPage page => page,
        null => (stored: 0, more: false),
      };

      if (_status == .failed) {
        notifyListeners();
        return;
      }

      _done += stored;
      notifyListeners();
      if (!more) break;
    }

    if (userId != uid) return;

    // `hasMore: false` says paging finished, not that every row landed — a
    // page that failed to store, a row deleted between pages. The mark is a
    // claim that the mirror is whole, so it waits on a count that says so.
    final settled = await _heldWorkouts(uid);
    if (_total == 0 || settled >= _total) {
      await _local.markHistoryBackfilled(uid);
    }

    _done = settled;
    _status = .idle;
    notifyListeners();
  }

  /// A page, or `null` when the server could not be reached — which stops the
  /// run rather than ending it, leaving the mark unwritten.
  Future<BackfillPage?> _page() async {
    try {
      return await _nextPage();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
      return null;
    }
  }

  Future<int> _heldWorkouts(String uid) async {
    final summary = await _local.mirrorSummary(uid);
    return summary[.workouts].count;
  }

  /// The account's workout count, or `null` when it could not be read. A
  /// failed summary is not a reason to skip the backfill — it only costs the
  /// row its numbers.
  Future<int?> _accountWorkouts() async {
    try {
      final summary = await _remote.getAccountSummary();
      return summary[.workouts].count;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return null;
    }
  }
}
