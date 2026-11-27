import 'dart:async';
import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'analytics.dart';
import 'coaching.dart' show CoachingStatus;
import 'remote.dart';
import 'workout_review.dart';
import 'workouts.dart' show LoggedAfter;

/// What the server does with a coach's view of everyone they coach
/// (heart-of-yours#559). Like [CoachingService], the app's view of a few
/// routes, which the app adapts `Api` onto.
abstract interface class RosterService {
  /// One row per coaching connection, those with reasons first; [former]
  /// lists the ended ones instead.
  Future<({List<ClientSummary> items, String? cursor})> getClients({bool former = false, String? cursor});

  /// From [at], only what comes after counts towards a client's reasons.
  Future<void> markReviewed(String connectionId, {DateTime? at});

  /// Workouts, skips and endings of every client, newest first.
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor});

  /// A client's workouts, newest first, as their coach may read them.
  Future<({List<Workout> items, String? cursor})> getClientWorkouts(String studentId, {String? cursor});

  /// When a client skipped a session, never why.
  Future<List<TrainingSkip>> getClientSkips(String studentId);

  /// One of a client's workouts.
  Future<Workout> getClientWorkout(String studentId, String workoutId);

  /// What a client's workout was asked to be; null when it had no plan.
  Future<WorkoutPlan?> getClientWorkoutPlan(String studentId, String workoutId);

  /// Logs a workout as the client's (#560), by its own id: a retry answers
  /// the stored one.
  Future<Workout> logClientWorkout(String studentId, Workout workout);

  /// What a workout the coach logged was asked to be. The server keeps the
  /// first one.
  Future<void> saveClientWorkoutPlan(String studentId, String workoutId, WorkoutPlan plan);
}

/// What a coach has read of one client: their workouts, a page at a time, and
/// their skips.
class _Record {
  final workouts = <Workout>[];
  final skips = <TrainingSkip>[];
  CoachingStatus status = .idle;
  String? cursor;
}

/// Why a client may need a word from their coach, by the name the server
/// gives it. The server's vocabulary is open: a word this build doesn't know
/// still counts, and reads as none of these.
enum ClientReason {
  /// Trained lighter than the session planned.
  lighter,

  /// Left a note on a workout.
  note,

  /// Hasn't trained for a while.
  gap,

  /// The program is near its end.
  ending,

  /// Changed a program the coach sent them (heart-api#476). Never the
  /// coach's own change.
  changed;

  static ClientReason? of(String name) {
    return values.where((each) => each.name == name).firstOrNull;
  }

  /// Reasons a look clears, since they count only what came after it. The
  /// others clear when they stop being true, which only the server knows.
  bool get clearsOnReview {
    return switch (this) {
      lighter || note || changed => true,
      gap || ending => false,
    };
  }
}

/// What a client of the coach did, by the `kind` the server gives it, open
/// like [ClientReason].
enum FeedKind {
  workout,
  skip,
  ending;

  static FeedKind? of(CoachFeedItem item) {
    return values.where((each) => each.name == item.kind).firstOrNull;
  }
}

extension TrainingDays on ClientSummary {
  /// The seven days up to and including [now]'s, oldest first, each true
  /// when the client trained on it. Days are [now]'s own, the coach's: the
  /// server knows no time zones, so it sends times and the device makes days.
  List<bool> lastSevenDays(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final trained = {for (final at in recent.map((at) => at.toLocal())) DateTime(at.year, at.month, at.day)};
    return List.generate(7, (index) => trained.contains(DateTime(today.year, today.month, today.day - 6 + index)));
  }
}

/// A coach's clients, sorted by who may need a word, and the feed of what
/// they did.
///
/// Server-only, as [Coaching] is, and read only when the Clients tab opens,
/// which exists only with Coach people on.
class Roster with ChangeNotifier implements SignOutStateSentry {
  final RosterService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final Analytics? analytics;

  final _clients = <ClientSummary>[];
  final _former = <ClientSummary>[];
  final _feed = <CoachFeedItem>[];
  final _records = <String, _Record>{};
  final _reviews = <String, WorkoutReview>{};

  /// Workouts read one at a time, by student, beside the pages of a record:
  /// one a message is about may be older than the first page.
  final _single = <String, Map<String, Workout>>{};

  CoachingStatus _status = .idle;
  CoachingStatus _feedStatus = .idle;
  String? _feedCursor;
  CoachingStatus _formerStatus = .idle;

  new({
    required this._service,
    RemoteAccess? remote,
    this.onError,
    this.analytics,
  }) : _remote = remote ?? RemoteAccess();

  static Roster of(BuildContext context) => Provider.of<Roster>(context, listen: false);

  static Roster watch(BuildContext context) => Provider.of<Roster>(context, listen: true);

  CoachingStatus get status => _status;

  /// The people the coach coaches, live or paused, those who may need a word
  /// first. One row per connection: someone coached in two domains is here
  /// twice.
  List<ClientSummary> get clients => UnmodifiableListView(_clients);

  /// Ended connections: only after [loadFormer].
  List<ClientSummary> get former => UnmodifiableListView(_former);

  CoachingStatus get formerStatus => _formerStatus;

  /// Every reason any client has right now, known or not, in the order
  /// [ClientReason] names them and unknown ones after.
  Set<String> get reasons {
    final all = {for (final client in _clients) ...client.reasons};
    final known = [
      for (final reason in ClientReason.values)
        if (all.contains(reason.name)) reason.name,
    ];
    return {...known, ...all};
  }

  /// The clients with [reason], in the roster's order.
  Iterable<ClientSummary> withReason(String reason) {
    return _clients.where((client) => client.reasons.contains(reason));
  }

  List<CoachFeedItem> get feed => UnmodifiableListView(_feed);

  CoachingStatus get feedStatus => _feedStatus;

  /// Whether the feed has an older page to read.
  bool get feedHasMore => _feedCursor != null;

  @override
  void onSignOut() {
    _clients.clear();
    _former.clear();
    _feed.clear();
    _status = .idle;
    _feedStatus = .idle;
    _feedCursor = null;
    _formerStatus = .idle;
    _records.clear();
    _reviews.clear();
    _single.clear();
    _owedPlans.clear();
    _names.clear();
    notifyListeners();
  }

  /// The client behind [connectionId], live, paused or former; null when
  /// neither list has read it.
  ClientSummary? client(String connectionId) {
    return [..._clients, ..._former].where((each) => each.connectionId == connectionId).firstOrNull;
  }

  CoachingStatus recordStatus(String studentId) => _records[studentId]?.status ?? .idle;

  /// [studentId]'s workouts read so far, newest first.
  List<Workout> workoutsOf(String studentId) => UnmodifiableListView(_records[studentId]?.workouts ?? const []);

  /// Every workout of [studentId]'s this device holds: the record's pages,
  /// then any read one at a time, by [loadWorkout] or a review.
  Iterable<Workout> heldOf(String studentId) {
    final paged = workoutsOf(studentId);
    final ids = {for (final each in paged) each.id};
    return [...paged, ...?_single[studentId]?.values.where((each) => ids.add(each.id))];
  }

  /// Reads [studentId]'s workout [workoutId] by itself, once, for what a
  /// message about it says. Reported, not thrown: the message reads as about
  /// "a workout" meanwhile.
  Future<void> loadWorkout(String studentId, String workoutId) async {
    if (!_remote.allowed || heldOf(studentId).any((each) => each.id == workoutId)) return;
    try {
      final workout = await _service.getClientWorkout(studentId, workoutId);
      (_single[studentId] ??= {})[workoutId] = workout;
      notifyListeners();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// [studentId]'s skips, newest first.
  List<TrainingSkip> skipsOf(String studentId) => UnmodifiableListView(_records[studentId]?.skips ?? const []);

  /// Whether [studentId] has older workouts to read.
  bool hasMoreOf(String studentId) => _records[studentId]?.cursor != null;

  /// Reads [studentId]'s newest workouts and their skips, replacing what was
  /// read before.
  Future<void> loadRecord(String studentId) async {
    if (!_remote.allowed) return;
    unawaited(sendOwedPlans());
    final record = _records.putIfAbsent(studentId, _Record.new);
    record.status = .loading;
    notifyListeners();
    try {
      final (page, skips) = await (
        _service.getClientWorkouts(studentId),
        _service.getClientSkips(studentId),
      ).wait;
      record.workouts
        ..clear()
        ..addAll(page.items);
      record.cursor = page.cursor;
      record.skips
        ..clear()
        ..addAll(skips.toList()..sort((a, b) => b.at.compareTo(a.at)));
      record.status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      record.status = .failed;
    }
    notifyListeners();
  }

  /// Logs [workout] as [studentId]'s (#560): a session the coach was there
  /// for, theirs from now on, in their history and marked as the coach's
  /// doing. Only what was done goes, as with a workout the user logs for
  /// themselves. Throws what the service threw, so the caller can say so and
  /// try again under the same id.
  ///
  /// [plan], for a program's session, is what it was asked to be (#558), sent
  /// once the workout is in: so a coach compares their own in-person session
  /// with its targets as with any other. A plan not kept is a comparison lost,
  /// never a workout: one that doesn't land waits for [sendOwedPlans], and the
  /// log still counts as logged.
  ///
  /// Their record keeps the server's order, newest id first, and a workout
  /// logged now has the newest id there is: it goes first, whenever it was.
  Future<Workout> logFor(String studentId, Workout workout, {WorkoutPlan? plan}) async {
    workout.keepDone();
    final logged = await _service.logClientWorkout(studentId, workout);
    if (plan != null) _owedPlans[logged.id] = (studentId: studentId, plan: plan);
    // what was sent, after keepDone dropped what wasn't done: the server's
    // answer is the same workout, and the client's history is what it holds
    analytics?.workoutLoggedFor(
      exerciseCount: workout.length,
      setCount: workout.expand((exercise) => exercise).length,
    );
    if (_records[studentId] case final _Record record) {
      record.workouts
        ..removeWhere((each) => each.id == logged.id)
        ..insert(0, logged);
      notifyListeners();
    }
    await sendOwedPlans();
    return logged;
  }

  /// Plans of workouts logged for a client that the server hasn't taken yet,
  /// by workout id.
  final _owedPlans = <String, ({String studentId, WorkoutPlan plan})>{};

  /// Sends the plans [logFor] couldn't, as `Workouts.sendWorkoutPlans` does
  /// the user's own: the server keeps the first plan, so a retry is harmless.
  /// One refused as malformed, or for a workout that is no longer the
  /// coach's to plan, is let go, since sending it again can't help; anything
  /// else waits for the next log or the next read of a client's record.
  Future<void> sendOwedPlans() async {
    if (!_remote.allowed) return;
    for (final MapEntry(key: workoutId, value: (:studentId, :plan)) in _owedPlans.entries.toList()) {
      try {
        await _service.saveClientWorkoutPlan(studentId, workoutId, plan);
        _owedPlans.remove(workoutId);
      } catch (error, stacktrace) {
        switch (error) {
          // malformed, or no longer the coach's to plan: let go, as answered
          case ServerRefusal(code: 'invalid_plan' || 'forbidden' || 'not_found'):
            _owedPlans.remove(workoutId);
          // anything else waits for the next try
          default:
            onError?.call(error, stacktrace: stacktrace);
        }
      }
    }
  }

  /// The next older page of [studentId]'s workouts, if there is one.
  Future<void> moreRecord(String studentId) async {
    final record = _records[studentId];
    if (!_remote.allowed || record == null || record.cursor == null || record.status == .loading) return;
    record.status = .loading;
    notifyListeners();
    try {
      final page = await _service.getClientWorkouts(studentId, cursor: record.cursor);
      record.workouts.addAll(page.items);
      record.cursor = page.cursor;
      record.status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      record.status = .failed;
    }
    notifyListeners();
  }

  /// [studentId]'s workout [workoutId] beside what it was asked to be. Read
  /// once: a workout's plan never changes, and the server keeps the first.
  /// Throws what the service threw.
  Future<WorkoutReview> review(String studentId, String workoutId) async {
    if (_reviews[workoutId] case final WorkoutReview review) return review;
    final known = _records[studentId]?.workouts.where((each) => each.id == workoutId).firstOrNull;
    final (workout, plan) = await (
      switch (known) {
        final Workout workout => Future.value(workout),
        null => _service.getClientWorkout(studentId, workoutId),
      },
      _service.getClientWorkoutPlan(studentId, workoutId),
    ).wait;
    // held for what messages about it say, as one read by itself is
    if (known == null) (_single[studentId] ??= {})[workoutId] = workout;
    return _reviews[workoutId] = WorkoutReview.of(workout, plan);
  }

  /// Reads the roster, every page of it: a coach has a few dozen people at
  /// most, and the filters work on the whole of it.
  Future<void> load() async {
    if (!_remote.allowed) return;
    _status = .loading;
    final began = ++_clock;
    notifyListeners();
    try {
      final all = await _every(_service.getClients);
      _clients
        ..clear()
        ..addAll(all);
      _renameSince(began);
      _status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// Reads the ended connections.
  Future<void> loadFormer() async {
    if (!_remote.allowed) return;
    _formerStatus = .loading;
    final began = ++_clock;
    notifyListeners();
    try {
      final all = await _every(({cursor}) => _service.getClients(former: true, cursor: cursor));
      _former
        ..clear()
        ..addAll(all);
      _renameSince(began);
      _formerStatus = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _formerStatus = .failed;
    }
    notifyListeners();
  }

  /// The coach has looked at [client]: what they did before now stops
  /// counting. Throws what the service threw, and changes nothing here until
  /// the server has agreed.
  ///
  /// A note, a lighter session or a changed program clears at once; a gap or
  /// an ending holds until it stops being true, and a reason this build
  /// doesn't know is left to the server too. The client moves down among those without reasons.
  Future<void> markReviewed(ClientSummary client) async {
    await _service.markReviewed(client.connectionId, at: DateTime.timestamp());
    analytics?.clientReviewed();
    final index = _clients.indexWhere((each) => each.connectionId == client.connectionId);
    if (index == -1) return;
    final reasons = [
      for (final reason in _clients[index].reasons)
        if (!(ClientReason.of(reason)?.clearsOnReview ?? false)) reason,
    ];
    _clients[index] = _copy(_clients[index], reasons: reasons);
    // the server's order, but those with reasons first, as it sorts them
    final sorted = [
      ..._clients.where((each) => each.reasons.isNotEmpty),
      ..._clients.where((each) => each.reasons.isEmpty),
    ];
    _clients
      ..clear()
      ..addAll(sorted);
    notifyListeners();
  }

  /// The newest page of the feed, replacing what was read before.
  Future<void> loadFeed() async {
    if (!_remote.allowed) return;
    await _readFeed(fresh: true);
  }

  /// The next older page of the feed, if there is one.
  Future<void> moreFeed() async {
    if (!_remote.allowed || _feedCursor == null || _feedStatus == .loading) return;
    await _readFeed(fresh: false);
  }

  Future<void> _readFeed({required bool fresh}) async {
    _feedStatus = .loading;
    notifyListeners();
    try {
      final page = await _service.getCoachFeed(cursor: fresh ? null : _feedCursor);
      if (fresh) _feed.clear();
      _feed.addAll(page.items);
      _feedCursor = page.cursor;
      _feedStatus = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _feedStatus = .failed;
    }
    notifyListeners();
  }

  static Future<List<ClientSummary>> _every(
    Future<({List<ClientSummary> items, String? cursor})> Function({String? cursor}) read,
  ) async {
    final all = <ClientSummary>[];
    String? cursor;
    do {
      final page = await read(cursor: cursor);
      all.addAll(page.items);
      cursor = page.cursor;
    } while (cursor != null);
    return all;
  }

  /// Names the coach gave, by student, each with when on [_clock]: a read
  /// that began before one would bring back the name it replaced.
  final _names = <String, ({int at, String? name, bool namedByYou})>{};

  /// Counts renames and reads, to tell which came first.
  var _clock = 0;

  /// [named], the connection as the server names it now, on every row of the
  /// client it is with, live, paused or former, in any domain: a name is the
  /// coach's for that person (#753).
  void renamed(Connection named) {
    final name = (at: ++_clock, name: named.name, namedByYou: named.namedByYou);
    _names[named.targetId] = name;
    if (_rename(named.targetId, name)) notifyListeners();
  }

  bool _rename(String studentId, ({int at, String? name, bool namedByYou}) name) {
    var changed = false;
    for (final list in [_clients, _former]) {
      for (final (index, row) in list.indexed.toList()) {
        if (row.studentId != studentId) continue;
        list[index] = _copy(row, name: name.name, namedByYou: name.namedByYou);
        changed = true;
      }
    }
    return changed;
  }

  /// Gives back the names given since a read that began at [began], which
  /// the server may have answered before it took them.
  void _renameSince(int began) {
    for (final MapEntry(key: studentId, value: name) in _names.entries) {
      if (name.at > began) _rename(studentId, name);
    }
  }

  /// [client] with what is given changed, and everything else as it was.
  static ClientSummary _copy(ClientSummary client, {List<String>? reasons, String? name, bool? namedByYou}) {
    return ClientSummary(
      connectionId: client.connectionId,
      studentId: client.studentId,
      name: switch (namedByYou) {
        null => client.name,
        bool() => name,
      },
      avatar: client.avatar,
      namedByYou: namedByYou ?? client.namedByYou,
      status: client.status,
      acceptedAt: client.acceptedAt,
      programId: client.programId,
      programName: client.programName,
      programWeek: client.programWeek,
      programWeeks: client.programWeeks,
      recent: client.recent,
      lastTrainedAt: client.lastTrainedAt,
      reasons: reasons ?? client.reasons,
      assistant: client.assistant,
    );
  }
}
