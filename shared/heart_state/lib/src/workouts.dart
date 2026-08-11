import 'dart:collection';
import 'dart:typed_data';

// hide Page: heart_models' pagination Page collides with Flutter's navigator Page.
import 'package:flutter/material.dart' hide Page;
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

typedef WorkoutId = String;

class Workouts with ChangeNotifier implements SignOutStateSentry {
  final _workouts = <WorkoutId, Workout>{};
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final WorkoutService _localService;
  final RemoteWorkoutService _remoteService;
  final _progress = SplayTreeSet<WorkoutImage>(_compareImages);

  Workouts({
    required WorkoutService service,
    required RemoteWorkoutService remoteService,
    this.onError,
  }) : _localService = service,
       _remoteService = remoteService;

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
    )..forEach((key, workouts) => workouts.sort((one, two) => two.id.compareTo(one.id)));
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

  Future<void> fetchWorkout(String workoutId) async {
    if (userId case String userId) {
      final workout = await _localService.getWorkout(userId, workoutId);
      if (workout != null) {
        _workouts[workoutId] = workout;
        notifyListeners();
      }
    }
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
  Future<void>? get finishing => _finishing;

  Future<void>? _finishing;

  Future<void> finishActiveWorkout() {
    return _finishing = _finishActiveWorkout();
  }

  Future<void> _finishActiveWorkout() async {
    activeWorkout?.finish(DateTime.timestamp());

    final active = activeWorkout;
    if (active == null) return;

    await saveWorkout(active);
    _activeWorkout = null;
  }

  Future<void> saveWorkout(Workout active) async {
    active.removeEmptySets();
    await _localService.finishWorkout(active, userId!);

    _workouts[active.id] = active;
    notifyListeners();

    try {
      final saved = await _remoteService.saveWorkout(active);
      if (saved.id != active.id) {
        _workouts.remove(active.id);
        await _localService.deleteWorkout(active.id);
      }
      _workouts[saved.id] = saved;
      if (userId case String id) {
        await _localService.storeWorkoutHistory([saved], id);
      }
      notifyListeners();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// Re-attempts the server save for any finished workout persisted locally but
  /// never confirmed on the server — e.g. a save that failed on a flaky network.
  /// Successful saves flip to synced via [storeWorkoutHistory]; failures are left
  /// as-is to retry next launch. An unsynced workout is never deleted; the only
  /// removal is the stale local id after the server assigns its own on success.
  Future<void> syncPendingWorkouts() async {
    if (userId case String id) {
      final local = await _localService.getWorkoutHistory(id);
      if (local != null) {
        _workouts.addAll(Map.fromEntries(local.map(_entry)));
      }

      final pending = _workouts.values.where((workout) => workout.isCompleted && !workout.synced).toList();
      for (final workout in pending) {
        try {
          final saved = await _remoteService.saveWorkout(workout);
          if (saved.id != workout.id) {
            _workouts.remove(workout.id);
            await _localService.deleteWorkout(workout.id);
          }
          _workouts[saved.id] = saved;
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

    final edited = await _remoteService.editWorkout(workout);
    if (userId case String id) {
      await _localService.storeWorkoutHistory([edited], id);
    }
    _workouts[edited.id] = edited;
    if (edited.id != workout.id) {
      _workouts.remove(workout.id);
    }
    notifyListeners();
  }

  /// Updates a finished workout's [start] and/or [end] through the dedicated
  /// times PATCH endpoint, replacing the local copy with the server's
  /// authoritative one. Returns the updated workout, or null if nothing was
  /// requested or the request failed (reported via [onError]).
  Future<Workout?> editWorkoutTimes(String workoutId, {DateTime? start, DateTime? end}) async {
    if (start == null && end == null) return null;
    try {
      final patched = await _remoteService.patchWorkout(workoutId, start: start, end: end);
      _workouts[patched.id] = patched;
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
        await _remoteService.deleteWorkout(id);
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
    _activeWorkoutId = null;
    notifyListeners();
  }

  Future<void> _deleteWorkout(String workoutId) {
    return _remoteService.deleteWorkout(workoutId);
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
      return _localService.getActiveWorkout(userId);
    } catch (error, s) {
      onError?.call(error, stacktrace: s);
      return null;
    }
  }

  Future<Iterable<Workout>?> _getRemoteHistory(String userId, {int pageSize = _historyPageSize, String? since}) async {
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
      notifyListeners();

      final workouts = await _getRemoteHistory(id);
      if (workouts != null) {
        await _localService.storeWorkoutHistory(workouts, id);
        _workouts.addAll(Map.fromEntries(workouts.map(_entry)));
        await _dropDeletedElsewhere(workouts);
        _advanceHistory(workouts);
      }

      // heal workouts stranded locally by an earlier failed network save
      await syncPendingWorkouts();

      await _localService.getWorkoutGallery(userId: id).then<void>(_progress.addAll);

      historyInitialized = true;
      notifyListeners();
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
    if (_loadingMoreHistory || !_hasMoreHistory) return;
    if (userId case String id) {
      _loadingMoreHistory = true;
      _historyPageError = false;
      notifyListeners();

      final workouts = await _getRemoteHistory(id, since: _historyCursor);
      // A null return means the fetch threw (a valid page is a possibly-empty
      // list) — surface it so the tail can offer a retry.
      if (workouts != null) {
        await _localService.storeWorkoutHistory(workouts, id);
        _workouts.addAll(Map.fromEntries(workouts.map(_entry)));
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

  void notifyOfActiveWorkout() {
    if (!_notifiedOfActiveWorkout) {
      _notifiedOfActiveWorkout = true;
    }
  }

  Workout? lookup(String id) => _workouts[id];

  Future<WorkoutImage?> attachImageToWorkout(
    Workout workout,
    (Uint8List, {String? mimeType, String? name}) image,
  ) async {
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
    if (activeWorkout case Workout workout) {
      final saved = await _remoteService.saveWorkout(workout);
      return attachImageToWorkout(saved, image);
    }
    return null;
  }

  Future<void> detachImageFromWorkout(Workout workout, WorkoutImage image) async {
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
