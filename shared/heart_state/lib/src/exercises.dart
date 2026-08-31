import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'movement_filters.dart';

class Exercises with ChangeNotifier, Iterable<Exercise> implements SignOutStateSentry {
  final _selectedExercises = <Exercise>{};
  final ExerciseService _service;
  final RemoteExerciseService _remoteService;
  final void Function(dynamic error, {dynamic stacktrace})? onError;
  final _filters = <ExerciseFilter>{};
  final _exercises = <ExerciseId, Exercise>{};

  /// Per-exercise unit overrides for the current user, keyed by exercise id.
  /// In-memory source of truth for [unitFor]; backed per-user by
  /// `exercise_details` locally and `exercise_preferences` remotely.
  final _units = <ExerciseId, MeasurementUnit>{};

  bool isInitialized = false;
  String? userId;

  /// The `Accept-Language` tag the catalog was last requested under. Localized
  /// copy is only as fresh as this tag — it is the cache key [onLocaleChanged]
  /// compares against.
  String? _catalogLocale;

  bool _showingMine = false;

  bool get showingMine => _showingMine;

  set showingMine(bool value) {
    _showingMine = value;
    notifyListeners();
  }

  new({
    this.onError,
    required this._remoteService,
    required this._service,
  });

  @override
  void onSignOut() {
    userId = null;
    isInitialized = false;
    _catalogLocale = null;
    _exercises.clear();
    _selectedExercises.clear();
    _units.clear();
  }

  @override
  Iterator<Exercise> get iterator => _exercises.values.where((ex) => !ex.isArchived).iterator;

  Iterable<Exercise> get archived => _exercises.values.where((ex) => ex.isArchived);

  Iterable<ExerciseFilter> get filters => _filters;

  Iterable<ExerciseFilter> get categories => _filters.whereType<Category>();

  Iterable<ExerciseFilter> get targets => _filters.whereType<Target>();

  Iterable<MovementFilter> get movementFilters => _filters.whereType<MovementFilter>();

  /// Every movement pattern the library actually uses, most common first and
  /// alphabetical within a count.
  ///
  /// Derived rather than hardcoded: content owns the vocabulary and can add a
  /// pattern without an app release, so a fixed list would go stale silently.
  /// Ordering by frequency keeps the patterns a lifter is likely to want — the
  /// presses and squats — off the bottom of the sheet.
  Iterable<String> get patterns {
    final counts = <String, int>{};
    for (final exercise in _exercises.values.where((each) => !each.isArchived)) {
      for (final pattern in exercise.movement.groups) {
        counts.update(pattern, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    return counts.keys.toList()..sort(
      (a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return switch (byCount) {
          0 => a.compareTo(b),
          _ => byCount,
        };
      },
    );
  }

  bool get hasOwn {
    return isInitialized && _exercises.values.any((ex) => ex.isMine && !ex.isArchived);
  }

  Exercise operator [](int index) => _exercises.values.toList()[index];

  static Exercises of(BuildContext context) {
    return Provider.of<Exercises>(context, listen: false);
  }

  static Exercises watch(BuildContext context) {
    return Provider.of<Exercises>(context, listen: true);
  }

  /// Loads the exercise catalog, reporting whether it ended up populated.
  ///
  /// The answer matters to the caller: templates and workouts both persist rows
  /// with a foreign key onto `exercises.id`, so they cannot be initialized
  /// against an empty catalog. Swallowing the error here and resolving normally
  /// let them run anyway — a locked database at startup surfaced as a
  /// `FOREIGN KEY constraint failed` half a second later, in the chained init.
  ///
  /// A local cache counts: the remote sync failing is survivable, the catalog
  /// being empty is not.
  Future<bool> init({DateTime? lastSync, String? locale}) async {
    _catalogLocale = locale;
    try {
      final (localSync, local) = await _service.getExercises(userId: userId);

      if (userId case String id) {
        _units.addAll(await _service.getExerciseUnits(id));
      }

      if (local.isNotEmpty) {
        _exercises.addAll(local.byId);
        isInitialized = true;
        notifyListeners();
      }

      await _syncRemote();
      isInitialized = true;
      notifyListeners();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
    return isInitialized;
  }

  /// The device locale changed mid-session. The server resolves localized
  /// catalog copy per request from `Accept-Language`, so the content already
  /// fetched is stale in the new language — re-fetch and overwrite in place.
  ///
  /// The caller refreshes the API client's headers first; this only re-runs
  /// the sync. A change arriving before [init] is just recorded — init fetches
  /// under the new header anyway.
  Future<void> onLocaleChanged(String locale) async {
    if (locale == _catalogLocale) return;
    _catalogLocale = locale;
    if (!isInitialized) return;

    try {
      await _syncRemote();
      notifyListeners();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  Future<void> _syncRemote() async {
    final [ex, own] = await Future.wait<Iterable<Exercise>>([
      _remoteService.getExercises(),
      _remoteService.getOwnExercises(),
    ]);

    final all = [...ex, ...own]..sort();
    _exercises.addAll(all.byId);
    // awaited: everything chained behind this init writes rows referencing
    // `exercises.id`, and letting the catalog write stay in flight leaves
    // them racing a parent row that is not committed yet.
    await _service.storeExercises(_exercises.values, userId: userId);

    // the server is the source of truth for unit prefs (it joins them onto the
    // exercise list per authenticated user); mirror them into the local cache.
    if (userId case String id) {
      for (final each in all) {
        if (each.unitSystem case MeasurementUnit u) {
          _units[each.id] = u;
          await _service.setExerciseUnit(exerciseName: each.id, userId: id, unit: u);
        }
      }
    }
  }

  Iterable<Exercise> search(String query, {bool filters = false, bool isMine = false}) {
    bool fitsSearch(Exercise exercise) {
      if (exercise.isArchived) return false;
      final matchesQuery = exercise.contains(query);
      // `fits` handles category and target and passes anything it does not
      // recognise, so the movement dimensions are applied here rather than
      // silently matching everything.
      final matchesFilters = !filters || (exercise.fits(_filters) && exercise.matchesMovement(_filters));
      final matchesOwnership = !isMine || exercise.isMine;
      return matchesQuery && matchesFilters && matchesOwnership;
    }

    return _exercises.values.where(fitsSearch);
  }

  Exercise? lookup(ExerciseId id) {
    return _exercises[id];
  }

  /// Resolves the env-stable content slug ([Exercise.key]) — what shared
  /// deep links carry, because a uuid only resolves in the database that
  /// minted it. Null for slugs the library doesn't know; user-created
  /// exercises have no slug at all.
  Exercise? lookupByKey(String key) {
    for (final each in _exercises.values) {
      if (each.key == key) return each;
    }
    return null;
  }

  /// Library exercises that train the same movement pattern as [exercise] and
  /// so can stand in for it, nearest first.
  ///
  /// [exercise] is re-resolved from the library by id: workout and template
  /// payloads embed a minimal exercise stub that carries no annotation, so the
  /// caller's copy is not necessarily the annotated one.
  ///
  /// The ranking is by objective distance only — no notion of what the lifter
  /// is avoiding. That is the caller's to apply, by filtering the result on
  /// [Movement] attributes (`m.axialLoad.atMost(AxialLoad.moderate)` and
  /// friends). Exercises with no annotation neither offer nor accept
  /// substitutions, so this is empty for user-created ones.
  Iterable<Exercise> alternativesTo(Exercise exercise) {
    final source = lookup(exercise.id) ?? exercise;
    if (source.movement.isEmpty) return const [];

    bool substitutes(Exercise other) {
      return other.id != source.id && !other.isArchived && source.movement.sharesPatternWith(other.movement);
    }

    return _exercises.values.where(substitutes).toList()..sort(
      (a, b) {
        final distance = source.movement.distanceTo(a.movement).compareTo(source.movement.distanceTo(b.movement));
        // ties broken by name so the order is stable across rebuilds
        return switch (distance) {
          0 => a.compareTo(b),
          _ => distance,
        };
      },
    );
  }

  /// The per-exercise unit preference for the current user, or `null` when the
  /// exercise has no override and the caller should fall back to the global
  /// setting. Keyed by exercise id.
  MeasurementUnit? unitFor(ExerciseId id) {
    return _units[id];
  }

  /// Sets (or clears, when [unit] is null) the unit preference for [exercise],
  /// updating the in-memory map, the per-user local cache, and the server.
  Future<void> setUnit(Exercise exercise, MeasurementUnit? unit) async {
    switch (unit) {
      case MeasurementUnit u:
        _units[exercise.id] = u;
      case null:
        _units.remove(exercise.id);
    }
    notifyListeners();

    if (userId case String id) {
      await _service.setExerciseUnit(exerciseName: exercise.id, userId: id, unit: unit);
    }

    switch (unit) {
      case MeasurementUnit u:
        await _remoteService.saveUnitPreference(exercise.id, u);
      case null:
        await _remoteService.deleteUnitPreference(exercise.id);
    }
  }

  Iterable<Exercise> get selected => _selectedExercises;

  void select(Exercise exercise) {
    _selectedExercises.add(exercise);
    notifyListeners();
  }

  void deselect(Exercise exercise) {
    _selectedExercises.remove(exercise);
    notifyListeners();
  }

  bool hasSelected(Exercise exercise) {
    return _selectedExercises.contains(exercise);
  }

  void unselectAll() {
    _selectedExercises.clear();
    notifyListeners();
  }

  void addFilter(ExerciseFilter filter) {
    _filters.add(filter);
    notifyListeners();
  }

  void removeFilter(ExerciseFilter filter) {
    _filters.remove(filter);
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
    notifyListeners();
  }

  Future<Iterable<ExerciseAct>> getExerciseHistory(Exercise exercise, {int? pageSize, String? anchor}) async {
    if (userId case String id) {
      return _service.getExerciseHistory(id, exercise, pageSize: pageSize, anchor: anchor);
    }
    return [];
  }

  Future<Map?> getExerciseRecords(Exercise exercise) async {
    if (userId case String id) {
      return _service.getRecord(id, exercise);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getRepsHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getRepsHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getDistanceHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getDistanceHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getDurationHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getDurationHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<List<(num, DateTime)>?> getWeightHistory(Exercise exercise) async {
    if (userId case String id) {
      return _service.getWeightHistory(id, exercise, limit: _exerciseHistoryLimit);
    }
    return null;
  }

  Future<void> _storeLocalExercise(Exercise exercise) {
    return _service.storeExercises([exercise.copyWith(isMine: true)], userId: userId);
  }

  Future<void> makeExercise(Exercise exercise) async {
    await _remoteService.makeExercise(exercise);
    _exercises[exercise.id] = exercise;
    await _storeLocalExercise(exercise);
    notifyListeners();
  }

  Future<void> editExercise(Exercise exercise) async {
    await _remoteService.editExercise(exercise);
    _exercises[exercise.id] = exercise;
    await _storeLocalExercise(exercise);
    notifyListeners();
  }

  Future<void> archive(Exercise exercise) async {
    final archived = exercise.copyWith(isArchived: true);
    _exercises[exercise.id] = archived;
    final remote = await _remoteService.editExercise(archived);
    _service.storeExercises([remote], userId: userId);
    _exercises[remote.id] = remote;
    notifyListeners();
  }

  Future<void> unarchive(Exercise exercise) async {
    final unarchived = exercise.copyWith(isArchived: false);
    _exercises[exercise.id] = unarchived;
    final remote = await _remoteService.editExercise(unarchived);
    _service.storeExercises([remote], userId: userId);
    _exercises[remote.id] = remote;
    notifyListeners();
  }

  Future<List<(num, DateTime)>?> getChartExerciseMetics(
    ChartPreferenceType type,
    ExerciseId exerciseId, {
    int limit = 8,
  }) async {
    if (userId case String id) {
      return _service.getExerciseMetics(id, type, exerciseId, limit: limit);
    }

    return null;
  }
}

extension on Iterable<Exercise> {
  /// Keyed by the uuid id — the identity that survives localization; `name`
  /// is display copy.
  Map<ExerciseId, Exercise> get byId {
    return {for (final each in this) each.id: each};
  }
}

extension on Movement {
  /// How far [other] sits from this movement across the load attributes, as a
  /// plain sum — smaller is a closer substitute.
  ///
  /// `axialLoad`, `impact` and `skill` are ordinal, so they contribute the gap
  /// between them; `stability` and `unilateral` are unordered, so they
  /// contribute a flat mismatch. The dimensions are weighted equally, which is
  /// a starting point rather than a claim: nothing downstream depends on the
  /// absolute numbers, only on the order they produce.
  int distanceTo(Movement other) {
    int gap(int a, int b) => (a - b).abs();
    // ignore: avoid_positional_boolean_parameters — a two-line local helper
    int mismatch(bool same) => same ? 0 : 1;

    return gap(axialLoad.index, other.axialLoad.index) +
        gap(impact.index, other.impact.index) +
        gap(skill.index, other.skill.index) +
        mismatch(stability == other.stability) +
        mismatch(unilateral == other.unilateral);
  }
}

const _exerciseHistoryLimit = 30;
