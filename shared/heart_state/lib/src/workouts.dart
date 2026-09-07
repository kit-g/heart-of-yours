import 'dart:collection';
import 'dart:typed_data';

// hide Page: heart_models' pagination Page collides with Flutter's navigator Page.
import 'package:flutter/material.dart' hide Page;
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

typedef WorkoutId = String;

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final _workouts = <WorkoutId, Workout>{};
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final WorkoutService _localService;
  final RemoteWorkoutService _remoteService;
  final RemoteAccess _remote;
  final _progress = SplayTreeSet<WorkoutImage>(_compareImages);

  new({
    required WorkoutService service,
    required this._remoteService,
    this.onError,
    RemoteAccess? remote,
  }) : _localService = service,
       _remote = remote ?? RemoteAccess();

  @override
  void onSignOut() {
    _workouts.clear();
    _activeWorkoutId = null;
    userId = null;
    historyInitialized = false;
    _historyCursor = null;
    _hasMoreHistory = true;
    _loadingMoreHistory = false;
    _historyPageError = false;
    _notifiedOfActiveWorkout = false;
    _latestMarkedSet = null;
    _progress.clear();
    _healChecked.clear();
    // a pass still running is the old user's; it checks for that at every
    // step, and the next sign-in must not wait on it
    _healing = null;
  }

  static Workouts of(BuildContext context) {
    return Provider.of<Workouts>(context, listen: false);
  }

  static Workouts watch(BuildContext context) {
    return Provider.of<Workouts>(context, listen: true);
  }

  String? userId;

  WorkoutId? _activeWorkoutId;

  bool historyInitialized = false;

  /// Workouts requested per history page from the backend.
  static const _historyPageSize = 20;

  /// Keyset cursor for the next history page, straight from the backend. Kept
  /// independent of the local cache — the cache is only a display accelerator
  /// (and is empty on a fresh device), so it must not drive pagination.
  String? _historyCursor;

  /// Flips to false once the backend hands back a short page — nothing older left.
  bool _hasMoreHistory = true;

  bool get hasMoreHistory => _hasMoreHistory;

  bool _loadingMoreHistory = false;

  bool get loadingMoreHistory => _loadingMoreHistory;

  /// True when the last [loadMoreHistory] attempt failed. The tail shows a retry
  /// affordance and auto-paging pauses until the user retries.
  bool _historyPageError = false;

  bool get historyPageError => _historyPageError;

  Workout? get activeWorkout => _workouts[_activeWorkoutId];

  bool _notifiedOfActiveWorkout = false;

  bool get hasActiveWorkout => _activeWorkoutId != null;

  bool get hasUnNotifiedActiveWorkout => hasActiveWorkout && !_notifiedOfActiveWorkout;

  Iterable<Workout> get history => _workouts.values.where((workout) => workout.isCompleted);

  Map<String, List<Workout>> get byMonth {
    final result = SplayTreeMap<String, List<Workout>>((a, b) => b.compareTo(a));
    return history.fold<Map<String, List<Workout>>>(
      result,
      (map, workout) {
        final date = workout.start;
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        return map..putIfAbsent(monthKey, () => []).add(workout);
      },
    )..forEach(
      // by recency, stated directly — ids only break ties for a stable
      // order. Id-order *currently* matches start-order (uuid v7, and since
      // heart-api#56 imports backdate theirs to the workout's start), but
      // that is a server invariant this code cannot see, and the one time it
      // broke, months rendered shuffled. Recency is what this list means, so
      // recency is what it sorts by.
      (key, workouts) => workouts.sort(
        (one, two) => switch (two.start.compareTo(one.start)) {
          0 => two.id.compareTo(one.id),
          final byStart => byStart,
        },
      ),
    );
  }

  List<WorkoutImage> get images => UnmodifiableListView(_progress);

  (WorkoutExercise exercise, ExerciseSet set)? _latestMarkedSet;

  (WorkoutExercise, ExerciseSet)? get nextIncomplete {
    return switch (_latestMarkedSet) {
      (WorkoutExercise exercise, ExerciseSet set) => activeWorkout?.nextIncomplete(exercise, set),
      null => null,
    };
  }

  set _activeWorkout(Workout? value) {
    if (value case Workout workout) {
      _activeWorkoutId = workout.id;
      _workouts[workout.id] = workout;
    } else {
      _activeWorkoutId = null;
    }
    notifyListeners();
  }

  ExerciseId? _pointedAtExercise;

  ExerciseId? get pointedAtExercise => _pointedAtExercise;

  set pointedAtExercise(ExerciseId? value) {
    _pointedAtExercise = value;
    notifyListeners();
  }

  Future<void> pointAt(ExerciseId exerciseId) {
    pointedAtExercise = exerciseId;
    return Future.delayed(const Duration(milliseconds: 300), () => pointedAtExercise = null);
  }

  Future<void> init() async {
    if (userId case String userId) {
      _activeWorkout = await _getActiveWorkout(userId);
    }
  }

  /// Resolves one workout, local mirror first, then the server.
  ///
  /// The mirror only holds what has been paged in — twenty workouts on the
  /// first launch — so "not here" is usually "not downloaded", not "gone".
  /// Without the remote leg a deep link into older history dead-ends, a web
  /// client with no warm mirror can resolve nothing at all, and a connection's
  /// session is unreachable by construction: [initHistory] only ever pulls the
  /// signed-in user's own list.
  ///
  /// [ownerId] is whose workout it is, defaulting to the signed-in user. Passing
  /// someone else's asks the server on their behalf; it answers only for an
  /// active connection, and refuses otherwise.
  ///
  /// Returns whether the workout could be resolved at all, so a caller can tell
  /// a missing workout from one it simply has not fetched yet.
  Future<bool> fetchWorkout(String workoutId, {String? ownerId}) async {
    if (userId case String id) {
      bool adopt(Workout workout) {
        _absorb([workout]);
        notifyListeners();
        return true;
      }

      final local = await _localService.getWorkout(id, workoutId);
      // a stripped copy is worth less than the server's, so it only answers
      // when the server cannot
      if (local != null && !_isStripped(local)) return adopt(local);

      // without the remote leg the mirror is all there is — a stripped copy
      // included, since no server is going to fill it in
      if (!_remote.allowed) {
        return switch (local) {
          Workout stripped => adopt(stripped),
          null => false,
        };
      }

      try {
        final remote = await _remoteService.getTargetWorkout(
          requesterId: id,
          targetUserId: ownerId ?? id,
          workoutId: workoutId,
        );
        // cached only when it is the user's own — the mirror is theirs, and
        // storing a connection's session in it would leak into their history,
        // their aggregation and every goal measured against it
        if ((ownerId ?? id) == id) {
          await _localService.storeWorkoutHistory([remote], id);
        }
        return adopt(remote);
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
        return switch (local) {
          Workout stripped => adopt(stripped),
          null => false,
        };
      }
    }

    return false;
  }

  /// Whether [workout] is a mirror row that lost its detail.
  ///
  /// A finished workout the server confirmed cannot legitimately be empty:
  /// finishing needs a completed set, and the client never sends a set-less
  /// exercise. So one with no sets at all is what heart-of-yours#85 left
  /// behind — the row survived a re-store, its exercises did not — and the
  /// server's copy is the real one. An unsynced workout is never a candidate:
  /// the mirror is its only copy, empty or not.
  static bool _isStripped(Workout workout) {
    return workout.isCompleted && workout.synced && !_carriesDetail(workout);
  }

  /// At least one set somewhere — the same test `heart_db` applies before it
  /// lets a server copy replace the mirror's exercises.
  static bool _carriesDetail(Workout workout) {
    return workout.any((exercise) => exercise.isNotEmpty);
  }

  Future<void> startWorkout({String? name, Workout? template}) {
    assert(name == null || template == null, 'Pass only the name or the full workout');
    final workout = template ?? Workout(name: name);
    workout.end = null;
    _workouts[workout.id] = workout;
    _activeWorkoutId = workout.id;

    notifyListeners();
    return _localService.startWorkout(workout, userId!);
  }

  /// The finish most recently started, or null before one this session.
  ///
  /// Exposed because the workout summary is pushed the moment finishing starts,
  /// not when it lands — and anything reading the workout back out of the
  /// database (goal progress, most of all) has to wait for the write.
  /// The finish most recently started, completing with the workout as it ended
  /// up — or null if there was nothing active to finish.
  Future<Workout?>? get finishing => _finishing;

  Future<Workout?>? _finishing;

  Future<Workout?> finishActiveWorkout() {
    return _finishing = _finishActiveWorkout();
  }

  Future<Workout?> _finishActiveWorkout() async {
    activeWorkout?.finish(DateTime.timestamp());

    final active = activeWorkout;
    if (active == null) return null;

    final saved = await saveWorkout(active);
    _activeWorkout = null;
    return saved;
  }

  /// Returns the workout as it ended up — the server's copy where the push
  /// landed, the local one where it did not.
  ///
  /// The server keeps the id the app minted (heart-api#66), so the two copies
  /// share it; what differs is `synced`, and whatever the server filled in.
  ///
  /// With the remote leg closed the local copy is the result, left unsynced
  /// exactly like a save that met a dead network — [syncPendingWorkouts] picks
  /// it up once there is an account to push it to.
  Future<Workout> saveWorkout(Workout active) async {
    active.removeEmptySets();
    await _localService.finishWorkout(active, userId!);

    _workouts[active.id] = active;
    notifyListeners();

    if (!_remote.allowed) return active;

    try {
      final saved = await _remoteService.saveWorkout(active);
      _absorb([saved]);
      if (userId case String id) {
        await _localService.storeWorkoutHistory([saved], id);
      }
      notifyListeners();
      return saved;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return active;
    }
  }

  /// Re-attempts the server save for any finished workout persisted locally but
  /// never confirmed on the server — e.g. a save that failed on a flaky network.
  /// Successful saves flip to synced via [storeWorkoutHistory]; failures are left
  /// as-is to retry next launch. Nothing is ever deleted here: the server keeps
  /// the id it is sent, so a confirmed copy lands on the row it came from.
  Future<void> syncPendingWorkouts() async {
    if (!_remote.allowed) return;
    if (userId case String id) {
      final local = await _localService.getWorkoutHistory(id);
      if (local != null) {
        _workouts.addAll(Map.fromEntries(local.map(_entry)));
      }

      final pending = _workouts.values.where((workout) => workout.isCompleted && !workout.synced).toList();
      for (final workout in pending) {
        try {
          final saved = await _remoteService.saveWorkout(workout);
          _absorb([saved]);
          await _localService.storeWorkoutHistory([saved], id);
        } catch (error, stacktrace) {
          onError?.call(error, stacktrace: stacktrace);
        }
      }
      if (pending.isNotEmpty) notifyListeners();
    }
  }

  Future<void> editWorkout(Workout workout) async {
    _workouts[workout.id] = workout;
    notifyListeners();

    if (!_remote.allowed) return _storeLocally(workout);

    final edited = await _remoteService.editWorkout(workout);
    if (userId case String id) {
      // The one empty copy that is authoritative: the user took every set
      // out. The mirror keeps a workout's exercises whenever a copy arrives
      // without any — that is what stops a shallow payload stripping it
      // (heart-of-yours#85) — so an edit that emptied it has to say so by
      // dropping the row, children and all, before the empty one is written.
      if (!_carriesDetail(workout)) {
        await _localService.deleteWorkout(workout.id);
      }
      await _localService.storeWorkoutHistory([edited], id);
    }
    _absorb([edited]);
    if (edited.id != workout.id) {
      _workouts.remove(workout.id);
    }
    notifyListeners();
  }

  /// Writes an edit to a finished workout that the server has not seen.
  ///
  /// Through the same write a finish takes rather than [WorkoutService.storeWorkoutHistory],
  /// because that one marks its rows synced — it stores what the server has
  /// confirmed — and this row is the opposite: a local truth still owed to a
  /// server, whenever there is an account to owe it to.
  Future<void> _storeLocally(Workout workout) async {
    if (userId case String id) {
      await _localService.finishWorkout(workout, id);
    }
    notifyListeners();
  }

  /// Updates a finished workout's [start] and/or [end] through the dedicated
  /// times PATCH endpoint, replacing the local copy with the server's
  /// authoritative one. Returns the updated workout, or null if nothing was
  /// requested or the request failed (reported via [onError]).
  ///
  /// With the remote leg closed the mirror's copy is edited in place instead.
  Future<Workout?> editWorkoutTimes(String workoutId, {DateTime? start, DateTime? end}) async {
    if (start == null && end == null) return null;
    if (!_remote.allowed) {
      final workout = _workouts[workoutId];
      if (workout == null) return null;
      if (start != null) workout.start = start;
      if (end != null) workout.end = end;
      await _storeLocally(workout);
      return workout;
    }
    try {
      final patched = await _remoteService.patchWorkout(workoutId, start: start, end: end);
      _absorb([patched]);
      if (userId case String id) {
        await _localService.storeWorkoutHistory([patched], id);
      }
      notifyListeners();
      return patched;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return null;
    }
  }

  Future<void> cancelActiveWorkout() async {
    if (_activeWorkoutId case String id) {
      _workouts.remove(id);
      try {
        await _localService.deleteWorkout(id);
        await _deleteWorkout(id);
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
    _activeWorkoutId = null;
    notifyListeners();
  }

  Future<void> _deleteWorkout(String workoutId) async {
    if (!_remote.allowed) return;
    await _remoteService.deleteWorkout(workoutId);
  }

  Future<void> deleteWorkout(String workoutId) {
    _workouts.remove(workoutId);
    _progress.removeWhere((image) => image.workoutId == workoutId);
    notifyListeners();
    _localService.deleteWorkout(workoutId);
    return _deleteWorkout(workoutId);
  }

  Future<void> startExercise(Exercise exercise) async {
    if (activeWorkout case Workout workout) {
      final starter = workout.add(exercise);
      notifyListeners();
      return _localService.startExercise(workout.id, starter);
    }
  }

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action, {bool notifies = true}) {
    activeWorkout?.where((each) => each == exercise).forEach(action);
    if (notifies) {
      notifyListeners();
    }
  }

  /// adds a new set to this exercise
  /// tries to copy the previous set
  /// or makes an empty one
  Future<void>? addSet(WorkoutExercise exercise) {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    _forExercise(
      exercise,
      (each) => each.add(set),
    );

    return _localService.addSet(exercise, set);
  }

  Future<void>? removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );

    return _localService.removeSet(set);
  }

  Future<void>? removeExercise(WorkoutExercise exercise) {
    activeWorkout?.remove(exercise);
    notifyListeners();

    return _localService.removeExercise(exercise);
  }

  Future<void>? markSetAsComplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = true;
    _latestMarkedSet = (exercise, set);
    notifyListeners();
    return _localService.markSetAsComplete(set);
  }

  Future<void>? markSetAsIncomplete(WorkoutExercise exercise, ExerciseSet set) {
    set.isCompleted = false;
    notifyListeners();
    return _localService.markSetAsIncomplete(set);
  }

  Future<void> storeMeasurements(ExerciseSet set) {
    return _localService.storeMeasurements(set);
  }

  /// Places [toInsert] before [before]. The caller decides what "before" means
  /// for a given drop — see `WorkoutDetail._onDrop`, which resolves drag
  /// direction into this and [append].
  Future<void> swap(WorkoutExercise toInsert, WorkoutExercise before) async {
    if (activeWorkout case Workout workout) {
      workout.swap(toInsert, before);
      notifyListeners();
      await _saveExerciseOrder(workout);
    }
  }

  Future<void> append(WorkoutExercise exercise) async {
    if (activeWorkout case Workout workout) {
      workout.append(exercise);
      notifyListeners();
      await _saveExerciseOrder(workout);
    }
  }

  /// An active workout is only pushed to the server once it's finished, so a
  /// reorder mid-workout survives a restart only if it's written locally.
  Future<void> _saveExerciseOrder(Workout workout) {
    return _localService.saveExerciseOrder(
      workout.map((each) => each.id).toList(),
      workout.id,
    );
  }

  Future<void>? renameWorkout(String name) async {
    activeWorkout?.name = name;
    if (activeWorkout case Workout workout) {
      _localService.updateWorkout(workoutId: workout.id, name: name);
    }
    notifyListeners();
  }

  Future<Workout?> _getActiveWorkout(String userId) async {
    try {
      return await _localService.getActiveWorkout(userId);
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<Iterable<Workout>?> _getRemoteHistory(String userId, {int pageSize = _historyPageSize, String? since}) async {
    if (!_remote.allowed) return null;
    try {
      return await _remoteService.getWorkouts(userId, pageSize: pageSize, since: since);
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<void> initHistory() async {
    if (userId case String id) {
      final local = await _localService.getWorkoutHistory(id);
      _workouts.addAll(Map.fromEntries(local?.map(_entry) ?? []));
      // with no server to page from, the mirror is the whole history
      if (!_remote.allowed) _hasMoreHistory = false;
      notifyListeners();

      final workouts = await _getRemoteHistory(id);
      if (workouts != null) {
        await _localService.storeWorkoutHistory(workouts, id);
        _absorb(workouts);
        await _dropDeletedElsewhere(workouts);
        _advanceHistory(workouts);
      }

      // heal workouts stranded locally by an earlier failed network save
      await syncPendingWorkouts();

      await _localService.getWorkoutGallery(userId: id).then<void>(_progress.addAll);

      historyInitialized = true;
      notifyListeners();

      // after the flag: this can be a request per workout, and the list
      // should not wait for it. One pass at a time — History's own visit
      // runs this too, and would otherwise start a second over the same rows.
      // Without the remote leg there is nobody to ask: the pass waits for an
      // account, like every other remote call.
      if (!_remote.allowed) return;
      await (_healing ??= _healStrippedHistory(id).whenComplete(() => _healing = null));
    }
  }

  Future<void>? _healing;

  /// Workouts the repair pass has already asked the server about this
  /// session. One the server has nothing more for — or no longer has — stays
  /// stripped in memory, and [initHistory] runs on every visit to History,
  /// so without this it would be asked for again on each.
  final _healChecked = <String>{};

  /// Requests in flight at once during the repair pass: enough that a mirror
  /// stripped across a hundred workouts heals in seconds rather than a
  /// serial minute, few enough not to crowd out the rest of start-up.
  static const _healBatch = 5;

  /// Refetches every workout the mirror holds without its detail.
  ///
  /// The repair path for heart-of-yours#85: a mirror stripped before the store
  /// stopped cascading has its rows but not their exercises, and nothing else
  /// would ever put them back — [initHistory] only re-pages the newest twenty,
  /// and only a full copy overwrites. One request per stripped workout, a few
  /// at a time. Not reaching the server ends the pass, since the rest would
  /// fail the same way and the next launch retries; anything it did answer,
  /// and anything the mirror refuses, is skipped and not asked again.
  Future<void> _healStrippedHistory(String id) async {
    final stripped = [
      for (final workout in _workouts.values)
        if (_isStripped(workout) && !_healChecked.contains(workout.id)) workout.id,
    ];

    for (var offset = 0; offset < stripped.length; offset += _healBatch) {
      final chunk = stripped.skip(offset).take(_healBatch).toList();
      _healChecked.addAll(chunk);

      final List<Workout?> answers;
      try {
        answers = await Future.wait(chunk.map((workoutId) => _detailOf(id, workoutId)));
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
        // not answered, so not checked: a later visit to History, once the
        // network is back, should ask again
        _healChecked.removeAll(chunk);
        break;
      }
      // signed out mid-pass: whatever came back is the previous user's
      if (userId != id) return;

      final healed = [
        for (final answer in answers)
          if (answer != null && _carriesDetail(answer)) answer,
      ];
      if (healed.isEmpty) continue;

      try {
        await _localService.storeWorkoutHistory(healed, id);
      } catch (error, stacktrace) {
        // the mirror's problem with these rows, not the server's with the rest
        onError?.call(error, stacktrace: stacktrace);
        continue;
      }
      if (userId != id) return;
      _absorb(healed);
      notifyListeners();
    }
  }

  /// The server's copy of one of the user's own workouts, or null when the
  /// server answered with anything but the workout — a 404 body, whatever its
  /// shape, is still an answer about this one. Not reaching it at all throws.
  Future<Workout?> _detailOf(String id, String workoutId) async {
    try {
      return await _remoteService.getTargetWorkout(
        requesterId: id,
        targetUserId: id,
        workoutId: workoutId,
      );
    } on Map {
      return null;
    }
  }

  /// Removes workouts this device still holds that the server no longer has.
  ///
  /// [WorkoutService.storeWorkoutHistory] only ever upserts, so nothing else
  /// deletes a local row. Without this a workout deleted on another device
  /// lives on in this one's mirror forever — inflating the weekly aggregation,
  /// the dashboard charts, and any goal that counts workouts.
  ///
  /// Bounded to the page's own range. Only rows at or newer than the oldest
  /// workout [page] returned are candidates, so older history this launch never
  /// asked for is left alone. Unsynced rows are never candidates either: those
  /// are local writes the server has not seen yet, which is the opposite of a
  /// deletion.
  ///
  /// An empty page reconciles nothing. It is indistinguishable from a server
  /// that answered wrongly, and the price of being wrong here is every workout
  /// the user has — so the one account this cannot heal is someone who deleted
  /// their last remaining workout elsewhere.
  Future<void> _dropDeletedElsewhere(Iterable<Workout> page) async {
    if (page.isEmpty) return;

    final kept = page.map((each) => each.id).toSet();
    final oldest = page.map((each) => each.start).reduce((a, b) => a.isBefore(b) ? a : b);

    final stale = _workouts.values.where(
      (workout) {
        if (!workout.isCompleted || !workout.synced) return false;
        if (kept.contains(workout.id)) return false;
        return !workout.start.isBefore(oldest);
      },
    ).toList();

    for (final workout in stale) {
      _workouts.remove(workout.id);
      _progress.removeWhere((image) => image.workoutId == workout.id);
      await _localService.deleteWorkout(workout.id);
    }

    if (stale.isNotEmpty) notifyListeners();
  }

  /// Fetches the next, older page of workouts, keyed off [_historyCursor]. The
  /// backend reports `hasMore` authoritatively, so paging stops the moment a page
  /// says there is nothing older.
  Future<void> loadMoreHistory() async {
    if (_loadingMoreHistory || !_hasMoreHistory || !_remote.allowed) return;
    if (userId case String id) {
      _loadingMoreHistory = true;
      _historyPageError = false;
      notifyListeners();

      final workouts = await _getRemoteHistory(id, since: _historyCursor);
      // A null return means the fetch threw (a valid page is a possibly-empty
      // list) — surface it so the tail can offer a retry.
      if (workouts != null) {
        await _localService.storeWorkoutHistory(workouts, id);
        _absorb(workouts);
        _advanceHistory(workouts);
      } else {
        _historyPageError = true;
      }

      _loadingMoreHistory = false;
      notifyListeners();
    }
  }

  /// Updates paging state from a freshly fetched [page]. `hasMore` is
  /// authoritative (the backend fetches `limit + 1`); the next keyset cursor is
  /// the id of the last — oldest — workout in the page. That id is the backend's
  /// own cursor (`cursorOf: (w) => w.id`), read off the server-ordered page and
  /// never off the local cache, so gaps in the cache can't skew it. A plain list
  /// (e.g. a test double) carries no `hasMore`, so paging stops.
  void _advanceHistory(Iterable<Workout> page) {
    final more = switch (page) {
      Page<Workout>(:final hasMore) => hasMore,
      _ => false,
    };
    _hasMoreHistory = more;
    _historyCursor = more && page.isNotEmpty ? page.last.id : null;
  }

  static MapEntry<WorkoutId, Workout> _entry(Workout w) => MapEntry(w.id, w);

  /// Every server copy enters memory through here, and is taken the way the
  /// mirror takes it: one that arrives without its detail — a list page, a
  /// PATCH echo — updates what its row carries and keeps the exercises
  /// already held. Otherwise a shallow copy would blank the list the mirror
  /// just kept intact, and hand the repair pass the same "stripped" workouts
  /// to refetch on every launch.
  ///
  /// The fields copied over are the row's: what a shallow payload can carry.
  /// Images are not among them — the gallery is its own feed — and `synced`
  /// is final, which is fine: a held copy the server has just listed is
  /// re-read from the mirror, where the store already marked it, before
  /// anything decides what to push.
  void _absorb(Iterable<Workout> copies) {
    for (final incoming in copies) {
      final held = _workouts[incoming.id];
      if (held != null && _carriesDetail(held) && _isStripped(incoming)) {
        held
          ..start = incoming.start
          ..end = incoming.end
          ..name = incoming.name
          ..calories = incoming.calories;
        continue;
      }
      _workouts[incoming.id] = incoming;
    }
  }

  void notifyOfActiveWorkout() {
    if (!_notifiedOfActiveWorkout) {
      _notifiedOfActiveWorkout = true;
    }
  }

  Workout? lookup(String id) => _workouts[id];

  /// Photos live in the server's bucket, so there is nowhere to put one without
  /// the remote leg — the callers hide the affordance in that case, and this
  /// answers null should one slip through.
  Future<WorkoutImage?> attachImageToWorkout(
    Workout workout,
    (Uint8List, {String? mimeType, String? name}) image,
  ) async {
    if (!_remote.allowed) return null;
    // destinationUrl is where the image will be available once saved
    final (cred, destinationUrl) = await _remoteService.getWorkoutUploadLink(workout.id);
    if (cred != null) {
      // upload file
      final upload = ('file', image.$1, contentType: image.mimeType, filename: image.name);
      final uploaded = await _remoteService.uploadFile(cred, upload);
      if (uploaded && destinationUrl != null) {
        // we'll continue working with the local image for now, by parsing the URL for the data we need
        final local = WorkoutImage.local(destinationUrl, workout.id, image.$1);
        // save it locally
        workout.images?[local.id] = local;
        await _localService.updateWorkout(workoutId: workout.id, images: workout.images?.values, name: workout.name);
        // and finally update state - the workouts and the progress gallery
        _progress.add(local);

        notifyListeners();
        return local;
      }
    }

    return null;
  }

  Future<WorkoutImage?> attachImageToActiveWorkout((Uint8List, {String? mimeType, String? name}) image) async {
    if (!_remote.allowed) return null;
    if (activeWorkout case Workout workout) {
      final saved = await _remoteService.saveWorkout(workout);
      return attachImageToWorkout(saved, image);
    }
    return null;
  }

  Future<void> detachImageFromWorkout(Workout workout, WorkoutImage image) async {
    if (!_remote.allowed) return;
    final detached = await _remoteService.deleteWorkoutImage(workout.id, image.key);
    if (detached) {
      _workouts[workout.id]?.images?.remove(image.id);
      _progress.removeWhere((each) => each.id == image.id);
      await _localService.updateWorkout(workoutId: workout.id, images: workout.images?.values, name: workout.name);
      notifyListeners();
    }
  }

  Future<void> detachImageFromActiveWorkout(WorkoutImage image) async {
    if (activeWorkout case Workout workout) {
      detachImageFromWorkout(workout, image);
    }
  }
}

/// Compares two [WorkoutImage] instances for sorting.
///
/// Images are sorted first by workout ID in descending order (newer workouts first),
/// then by image ID in ascending order within the same workout.
///
/// Returns:
/// - A negative value if [one] should come before [two]
/// - Zero if they are considered equal
/// - A positive value if [one] should come after [two]
int _compareImages(WorkoutImage one, WorkoutImage two) {
  final byWorkout = two.workoutId.compareTo(one.workoutId);
  if (byWorkout != 0) return byWorkout;
  return one.id.compareTo(two.id);
}
