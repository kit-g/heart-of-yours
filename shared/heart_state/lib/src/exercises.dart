import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'analytics.dart';
import 'remote.dart';

/// How the CDN identifies the catalog copy the local cache holds: the
/// publishing run's `version` from the manifest, the locale file the device
/// tag resolved to (`es_ES` — not the tag itself, since two regional tags
/// that resolve to one file share one copy), and that file's ETag, for the
/// conditional re-fetch when only the version moved.
typedef CatalogStamp = ({String version, String locale, String? etag});

/// The cached library's stamp names a locale its rows are not written in, so
/// the cache was downloaded afresh (#612). Carries the stamped locale file and
/// the device's language tag, and nothing about the user or the rows.
class const CatalogLanguageMismatch(final String stamped, final String? device) implements Exception {
  @override
  String toString() => 'CatalogLanguageMismatch: library stamped $stamped holds no $stamped names (device $device)';
}

/// One locale file of the library: its exercises, and the words lifters search
/// them by — abbreviations and muscle names — in that locale (#135).
typedef CatalogLibrary = ({Iterable<Exercise> exercises, SearchGlossary glossary});

/// The exercise library as the CDN publishes it: static, unauthenticated,
/// one file per locale behind a manifest. Both modes read it — an anonymous
/// session never talks to heart-api, and a signed-in one no longer reads the
/// library through it; the API keeps only the user's own exercises.
///
/// Defined here rather than in `heart_models` because the manifest and the
/// stamp are a client-side freshness concern the server has no model for; the
/// app adapts `Cdn` onto it, the way `RemoteTemplateFilingService` is adapted.
abstract interface class ExerciseLibraryService {
  /// The library, or `null` when the copy [cached] describes is still
  /// current — and either way the stamp the cache should carry from now on.
  Future<(CatalogLibrary?, CatalogStamp)> getLibrary({CatalogStamp? cached});
}

/// The per-exercise preferences the account holds — a unit override, a rest
/// timer — on the library's exercises as much as on its own.
///
/// Read on its own because since the catalog moved to the CDN, nothing else
/// the app fetches carries a preference set on a *library* exercise. Defined
/// here rather than added to `RemoteExerciseService`: that interface is the
/// contract heart-api implements, and widening it breaks the server (the API
/// takes the same view — see its `ApiExercisePreferenceService`). The app
/// adapts `Api` onto this, the way `RemoteTemplateFilingService` is adapted.
abstract interface class RemoteExercisePreferenceService {
  Future<Iterable<ExercisePreference>> getExercisePreferences();
}

/// The stamp beside the cached catalog rows. Written in the same transaction
/// as the rows it describes, so neither can outlive the other — a stamp with
/// no rows behind it would have the manifest answer "unchanged" to an empty
/// catalog. `ExerciseService` cannot carry it: that interface is the server's.
abstract interface class LocalCatalogService {
  /// Null until a library has been stored.
  Future<CatalogStamp?> getCatalogStamp();

  /// Upserts the library rows and records [stamp]. An empty [exercises] only
  /// moves the stamp — a publish that left this locale's file byte-identical.
  /// [glossary] is stored beside the stamp; without one, the stored one stays.
  Future<void> storeCatalog(Iterable<Exercise> exercises, {required CatalogStamp stamp, SearchGlossary? glossary});

  /// The glossary stored with the catalog; null before one has been.
  Future<SearchGlossary?> getSearchGlossary();
}

/// Local pinned defaults and the account write. The pending flag invalidates an old
/// replay confirmation when an anonymous user changes a previously saved pin.
abstract interface class ExerciseNoteService {
  Future<Map<String, String>> read(String userId);

  Future<void> store(String exerciseId, String userId, String? note, {bool pending = false});

  Future<void> sync(String exerciseId, String? note);
}

/// Moving an exercise's history onto another (#338): the account's move, and
/// the mirror's copy of it. One interface for both halves, like
/// [ExerciseNoteService], because the second only ever follows the first.
/// Renaming an own exercise on the account (#616). Apart from the edit
/// because the server checks a name against the account's other exercises
/// whenever one is sent: an edit that only archives, or changes the target,
/// must not carry it, or an account holding names that differ only in case
/// could no longer archive either. `RemoteExerciseService` is the server's
/// contract and cannot take the distinction; the app adapts `Api` onto this.
abstract interface class RemoteExerciseRenameService {
  /// The edit, with [Exercise.name] as the new name. Throws when another of
  /// the account's own exercises already has it.
  Future<Exercise> renameExercise(Exercise exercise);
}

abstract interface class ExerciseMoveService {
  /// The account's move, or with [dryRun] what it would do, written nowhere.
  Future<ExerciseMoveReport> move(String sourceId, String targetId, {bool dryRun = false});

  /// Re-keys the device's rows the way [report] says the server did.
  Future<void> mirror(ExerciseMoveReport report, {required String userId});
}

/// Renaming an own exercise (#616). The id is the exercise's identity, so a
/// new name is display copy only, and every screen that resolves the id picks
/// it up.
extension RenamedExercise on Exercise {
  /// This exercise under [name]. Through the model's own map rather than
  /// `copyWith`, which has no name: the name was the identity when it was
  /// written. The round trip is the one every stored row already makes.
  Exercise renamed(String name) => Exercise.fromJson({...toMap(), 'name': name});

  /// This exercise with [text] as its instructions (#621), or none for null.
  /// The same round trip as [renamed]: `copyWith` reads a null as "keep", so
  /// it can set instructions but never clear them.
  Exercise withInstructions(String? text) => Exercise.fromJson({...toMap(), 'instructions': text});
}

class Exercises with ChangeNotifier, Iterable<Exercise> implements SignOutStateSentry {
  final _selectedExercises = <Exercise>{};
  final ExerciseService _service;
  final RemoteExerciseService _remoteService;
  final ExerciseLibraryService _libraryService;
  final LocalCatalogService _catalogService;
  final RemoteExercisePreferenceService _preferenceService;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// Hands a mirrored rest timer to `Timers`, which owns them — the read that
  /// brings the unit overrides back carries the timers in the same row, and a
  /// copy of them here would be a second answer to the same question.
  final Future<void> Function(ExerciseId exercise, int seconds)? onRestTimer;
  final _filters = <ExerciseFilter>{};
  final _exercises = <ExerciseId, Exercise>{};

  /// The served locale's search vocabulary, which [search] matches through.
  SearchGlossary _glossary = .empty();

  /// Per-exercise unit overrides for the current user, keyed by exercise id.
  /// In-memory source of truth for [unitFor]; backed per-user by
  /// `exercise_details` locally and `exercise_preferences` remotely.
  final _units = <ExerciseId, MeasurementUnit>{};

  final ExerciseNoteService? _noteService;
  final ExerciseMoveService? _moveService;
  final RemoteExerciseRenameService? _renameService;
  final _notes = <String, String>{};

  bool isInitialized = false;
  String? userId;

  /// The `Accept-Language` tag the catalog was last requested under. Localized
  /// copy is only as fresh as this tag — it is the cache key [onLocaleChanged]
  /// compares against.
  String? _catalogLocale;

  bool _showingMine = false;

  /// Whether the filters in force are ones the user asked to be shown — the
  /// library opened "showing only" something, from a chip or a count
  /// elsewhere ([showOnly]) — rather than ones set in the picker. A grouped
  /// picker hides and sets aside its own filters (#711), but never these.
  bool get filtersAskedFor => _filtersAskedFor;
  bool _filtersAskedFor = false;

  bool get showingMine => _showingMine;

  set showingMine(bool value) {
    _showingMine = value;
    notifyListeners();
  }

  new({
    this.onError,
    this.onRestTimer,
    this._noteService,
    this._moveService,
    this._renameService,
    required this._remoteService,
    required this._service,
    required this._libraryService,
    required this._catalogService,
    required this._preferenceService,
    this.analytics,
    RemoteAccess? remote,
  }) : _remote = remote ?? RemoteAccess();

  /// Whether people outgrow the catalog. Absent in tests.
  final Analytics? analytics;

  @override
  void onSignOut() {
    userId = null;
    isInitialized = false;
    _catalogLocale = null;
    _exercises.clear();
    _glossary = .empty();
    _selectedExercises.clear();
    _units.clear();
    _notes.clear();
    notifyListeners();
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
  ///
  /// The library comes from the CDN in both modes — the one network call an
  /// anonymous session makes. Only the user's own exercises need the account,
  /// and they follow once the library is in.
  ///
  /// Each step fails on its own and the next still runs: a local read that
  /// fails must not keep the CDN from replacing what it could not read, and a
  /// library that fails to download must not keep the user's own exercises
  /// from syncing. Populated means the library is in, or its sync went
  /// through — the user's own exercises alone are not a catalog the chained
  /// init can write against.
  Future<bool> init({String? locale}) async {
    _catalogLocale = locale;
    // A session that ends mid-init (#671) has had its state cleared for the
    // next one: what this run read is the last one's, and it must neither go
    // back in nor mark the next one's catalog as initialized, which would skip
    // that one's startup. False then, which also stops the chained init.
    final owner = userId;
    bool left() => _disposed || userId != owner;
    await _step(() async {
      final (_, local) = await _service.getExercises(userId: owner);
      if (local.isNotEmpty && !left()) {
        _exercises.addAll(local.byId);
        final glossary = await _catalogService.getSearchGlossary() ?? .empty();
        if (left()) return;
        _glossary = glossary;
        notifyListeners();
      }
    });
    if (owner case String id when !left()) {
      await _step(() async {
        final units = await _service.getExerciseUnits(id);
        final notes = await _noteService?.read(id) ?? {};
        if (left()) return;
        _units.addAll(units);
        _notes.addAll(notes);
      });
    }
    if (left()) return false;
    final synced = await _step(_syncLibrary);
    if (left()) return false;
    if (_remote.allowed) {
      await _step(_syncOwn);
      // its own read, run whether or not the list above landed: a failed
      // list must not cost the preferences of every library exercise
      if (owner case String id when !left()) await _syncPreferences(id);
    }

    // the app may be gone by the time the catalog is read — a tree torn down
    // mid-init has no one to tell
    if (left()) return false;
    isInitialized = synced || _exercises.values.any((each) => !each.isMine);
    notifyListeners();
    return isInitialized;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Runs one step of [init], reporting what it throws instead of letting it
  /// cost the steps after it. Answers whether it went through.
  Future<bool> _step(Future<void> Function() body) async {
    try {
      await body();
      return true;
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return false;
    }
  }

  /// The device locale changed mid-session. The library is published per
  /// locale, so the copy already loaded is stale in the new language — the CDN
  /// client resolves the new tag to its file, and the rows are overwritten in
  /// place under the same ids.
  ///
  /// A change arriving before [init] is just recorded — init resolves under
  /// the new tag anyway.
  ///
  /// The new tag is only kept once the library has been fetched under it. A
  /// failed fetch — offline, or the app backgrounded mid-request — puts the
  /// old one back, so the next call with this tag (the app calls on every
  /// resume) tries again instead of answering "already done" to a library
  /// still in the old language. Before this, the chrome switched and the
  /// exercise names stayed behind until the process died, which on Android
  /// can be days.
  Future<void> onLocaleChanged(String locale) async {
    if (locale == _catalogLocale) return;
    final previous = _catalogLocale;
    _catalogLocale = locale;
    if (!isInitialized) return;

    try {
      await _syncLibrary();
      notifyListeners();
    } catch (e, s) {
      _catalogLocale = previous;
      onError?.call(e, stacktrace: s);
    }
  }

  /// Locales whose names give their language away by alphabet alone. Only a
  /// file written in a script other than English's can be checked this way;
  /// Spanish and French share it, and go unchecked.
  static final _scripts = {'ru': RegExp(r'[Ѐ-ӿ]')};

  /// Whether the cached library rows are written in the language [stamp]
  /// vouches for. Answers true wherever that cannot be told (see [_scripts])
  /// or there are no library rows to judge.
  ///
  /// One translated name is enough: the check is for a cache whose rows and
  /// stamp disagree outright (#612), not for an exercise the file itself left
  /// untranslated.
  bool _rowsMatch(CatalogStamp stamp) {
    final script = _scripts[stamp.locale.split('_').first];
    final library = _exercises.values.where((each) => !each.isMine);
    return script == null || library.isEmpty || library.any((each) => script.hasMatch(each.name));
  }

  /// [stamp] if the rows behind it are what it says, else null — reported,
  /// so the library is downloaded afresh rather than called current.
  CatalogStamp? _vouched(CatalogStamp? stamp) {
    if (stamp == null || _rowsMatch(stamp)) return stamp;
    onError?.call(CatalogLanguageMismatch(stamp.locale, _catalogLocale), stacktrace: StackTrace.current);
    return null;
  }

  /// Brings the library up to what the CDN publishes, downloading only when
  /// the cached copy is not it.
  ///
  /// The stamp is trusted only when library rows sit behind it. A stamp over
  /// an empty catalog — a wiped table, a first launch that stored the stamp
  /// but not the rows — would have the manifest answer "unchanged" forever.
  ///
  /// Nor is it trusted over rows written in another language than it names:
  /// such a cache passes every stamp comparison and would never be replaced
  /// (#612). It is downloaded afresh, and reported — the report carries the
  /// two language codes and nothing else, and is how the cause gets found.
  Future<void> _syncLibrary() async {
    final warm = _exercises.values.any((each) => !each.isMine);
    final stored = switch (warm) {
      true => await _catalogService.getCatalogStamp(),
      false => null,
    };
    final cached = _vouched(stored);

    final (library, stamp) = await _libraryService.getLibrary(cached: cached);
    switch (library) {
      case (:final exercises, :final glossary):
        final sorted = exercises.toList()..sort();
        _exercises.addAll(sorted.byId);
        _glossary = glossary;
        // awaited: everything chained behind this init writes rows referencing
        // `exercises.id`, and letting the catalog write stay in flight leaves
        // them racing a parent row that is not committed yet.
        await _catalogService.storeCatalog(sorted, stamp: stamp, glossary: glossary);
      case null when stamp != cached:
        // nothing to download, but the CDN moved on (a publish that left this
        // locale's file byte-identical, say) — record it so the next launch
        // does not repeat the conditional round trip
        await _catalogService.storeCatalog(const [], stamp: stamp);
      case null:
        break;
    }
  }

  /// The user's own exercises, which the CDN cannot know: the authenticated
  /// list, with the unit preferences the server joins onto them.
  Future<void> _syncOwn() async {
    final own = (await _remoteService.getOwnExercises()).map(_withLocalTags).toList()..sort();
    _exercises.addAll(own.byId);
    await _service.storeExercises(own, userId: userId);

    // the server is the source of truth for unit prefs on these rows; mirror
    // them into the local cache. [_syncPreferences] covers these same rows,
    // off a call of its own — so what the list already carries is banked here
    // rather than made to depend on that second call landing.
    if (userId case String id) {
      for (final each in own) {
        if (each.unitSystem case MeasurementUnit u) {
          _units[each.id] = u;
          await _service.setExerciseUnit(exerciseName: each.id, userId: id, unit: u);
        }
      }
    }
  }

  /// The account's preferences on any exercise at all, the library's included
  /// — which no list the app reads carries since the catalog moved to the CDN.
  ///
  /// The server wins: for a signed-in device the account is the source of
  /// truth, and what an anonymous session set offline is the upsync's problem,
  /// not this read's. Units land here and in the per-user local cache; rest
  /// timers go to `Timers` through [onRestTimer], which owns them.
  ///
  /// Reported rather than thrown, unlike the two legs above it: a cold cache
  /// leaves [init] answering `false` on anything that escapes, and the whole
  /// chained start-up — workouts, templates — stops on that answer. It stops
  /// for an empty catalog, which those rows key onto; it should not stop for a
  /// rest timer.
  Future<void> _syncPreferences(String id) async {
    try {
      // Only for exercises this device holds: both stores key their rows by a
      // foreign key onto `exercises.id`, so a preference on an exercise the
      // CDN no longer publishes would fail its write — and there would be
      // nothing on screen to apply it to anyway.
      final held = (await _preferenceService.getExercisePreferences()).where(
        (each) => _exercises.containsKey(each.exerciseId),
      );

      if (userId != id) return;
      final notes = {
        // A catalog gap is not a server-side deletion of the stored pin.
        for (final entry in _notes.entries)
          if (!_exercises.containsKey(entry.key)) entry.key: entry.value,
        for (final each in held)
          if (each.note case String note) each.exerciseId: note,
      };
      for (final exerciseId in {..._notes.keys, ...notes.keys}.where(_exercises.containsKey)) {
        await _noteService?.store(exerciseId, id, notes[exerciseId]);
      }
      if (userId != id) return;
      _notes
        ..clear()
        ..addAll(notes);
      for (final each in held) {
        if (each.unitSystem case MeasurementUnit unit) {
          _units[each.exerciseId] = unit;
          await _service.setExerciseUnit(exerciseName: each.exerciseId, userId: id, unit: unit);
        }
        if (each.restTimer case int seconds) {
          await onRestTimer?.call(each.exerciseId, seconds);
        }
      }
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// The exercises [query] finds, best first (#135).
  ///
  /// Ranked by how the query matched — the name's start, every word, only
  /// through an alias or the glossary (`ohp`, `db`, `lats`), only with a typo —
  /// and within each of those by [lastDone], the exercise done most recently
  /// first. Recency never lifts a weaker match over a stronger one: a lifter
  /// typing a new exercise's exact name gets it first. Ties keep the library's
  /// own order. An empty query matches everything at the top tier, so it ranks
  /// by recency alone.
  List<Exercise> search(
    String query, {
    bool filters = false,
    bool isMine = false,
    DateTime? Function(ExerciseId)? lastDone,
  }) {
    bool fits(Exercise exercise) {
      if (exercise.isArchived) return false;
      // `fits` handles category and target and passes anything it does not
      // recognise, so the movement dimensions are applied here rather than
      // silently matching everything.
      final matchesFilters = !filters || exercise.fits(_filters);
      final matchesOwnership = !isMine || exercise.isMine;
      return matchesFilters && matchesOwnership;
    }

    final found = [
      for (final (order, exercise) in _exercises.values.indexed)
        if (fits(exercise))
          if (exercise.match(query, glossary: _glossary) case final SearchMatch match)
            (exercise: exercise, match: match, done: lastDone?.call(exercise.id), order: order),
    ];

    found.sort(
      (a, b) => [
        a.match.compareTo(b.match),
        _newestFirst(a.done, b.done),
        a.order.compareTo(b.order),
      ].firstWhere((each) => each != 0, orElse: () => 0),
    );
    return [for (final each in found) each.exercise];
  }

  /// Done more recently sorts first, and never done sorts last.
  static int _newestFirst(DateTime? a, DateTime? b) {
    return switch ((a, b)) {
      (DateTime a, DateTime b) => b.compareTo(a),
      (DateTime _, null) => -1,
      (null, DateTime _) => 1,
      (null, null) => 0,
    };
  }

  /// The exercises done most recently, newest first: what a lifter most
  /// often comes to the picker for, shown before they type (#135). Under the
  /// same filters as [search], and at most [limit] of them.
  List<Exercise> recent(
    DateTime? Function(ExerciseId) lastDone, {
    bool filters = false,
    bool isMine = false,
    int limit = 5,
  }) {
    return search(
      '',
      filters: filters,
      isMine: isMine,
      lastDone: lastDone,
    ).takeWhile((each) => lastDone(each.id) != null).take(limit).toList();
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

    if (!_remote.allowed) return;

    // the device's choice stands either way: a failure to tell the server is
    // reported, not thrown at the screen that made it
    try {
      switch (unit) {
        case MeasurementUnit u:
          await _remoteService.saveUnitPreference(exercise.id, u);
        case null:
          await _remoteService.deleteUnitPreference(exercise.id);
      }
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  String? noteFor(String exerciseId) => _notes[exerciseId];

  bool get canPinNote => _noteService != null && userId != null && !_remote.replaying;

  Future<void> setNote(String exerciseId, String? value) async {
    final note = switch (value?.trim()) {
      null || '' => null,
      final text => text,
    };
    if (note != null && note.length > ExercisePreference.maxNoteLength) throw ArgumentError('Note too long');
    final id = userId;
    if (!canPinNote || id == null) return;
    // Publish only after success; a rejected pin must not look saved.
    if (_remote.allowed) await _noteService!.sync(exerciseId, note);
    await _noteService!.store(exerciseId, id, note, pending: !_remote.allowed);
    if (userId != id) return;
    switch (note) {
      case String text:
        _notes[exerciseId] = text;
      case null:
        _notes.remove(exerciseId);
    }
    notifyListeners();
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

  /// The library showing only [filter], replacing whatever was filtered
  /// before: what the user asked for by name ([filtersAskedFor]).
  void showOnly(ExerciseFilter filter) {
    _filters
      ..clear()
      ..add(filter);
    _filtersAskedFor = true;
    notifyListeners();
  }

  /// A filter set in the picker: what is in force from then on is the
  /// picker's own, not what was asked for.
  void addFilter(ExerciseFilter filter) {
    _filters.add(filter);
    _filtersAskedFor = false;
    notifyListeners();
  }

  void removeFilter(ExerciseFilter filter) {
    _filters.remove(filter);
    _filtersAskedFor = _filtersAskedFor && _filters.isNotEmpty;
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
    _filtersAskedFor = false;
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

  /// [exercise] as the server has it, with the movement pattern (#343) and
  /// the muscles (#176) the user gave it on this device. The server keeps no
  /// muscles on a custom exercise, and a pattern only from builds that send
  /// it (#616) — every one set before them is on its device alone — so an
  /// empty one from there is silence, never a clearing: the mirror's copy
  /// stands until the server has one of its own. The cost: a pattern cleared
  /// on one device survives on another, and that one's next edit sends it
  /// back.
  Exercise _withLocalTags(Exercise exercise) {
    final local = _exercises[exercise.id];
    final movement = switch ((exercise.movement.isEmpty, local?.movement)) {
      (true, Movement kept) when !kept.isEmpty => kept,
      _ => exercise.movement,
    };
    final muscles = switch ((exercise.muscles.isEmpty, local?.muscles)) {
      (true, MuscleTagging kept) when !kept.isEmpty => kept,
      _ => exercise.muscles,
    };
    return exercise.copyWith(movement: movement, tags: muscles);
  }

  Future<void> _storeLocalExercise(Exercise exercise) {
    return _service.storeExercises([exercise.copyWith(isMine: true)], userId: userId);
  }

  /// A custom exercise is the user's own row, so with the remote leg closed it
  /// simply lives in the local catalog under its client-minted id.
  Future<void> makeExercise(Exercise exercise) async {
    analytics?.exerciseCreated();
    if (_remote.allowed) await _remoteService.makeExercise(exercise);
    _exercises[exercise.id] = exercise;
    await _storeLocalExercise(exercise);
    notifyListeners();
  }

  /// Saves an edit of an own exercise. A new name goes through the rename,
  /// and nothing else does — see [RemoteExerciseRenameService].
  Future<void> editExercise(Exercise exercise) async {
    final renamed = _exercises[exercise.id]?.name != exercise.name;
    if (_remote.allowed) {
      await switch ((renamed, _renameService)) {
        (true, RemoteExerciseRenameService service) => service.renameExercise(exercise),
        _ => _remoteService.editExercise(exercise),
      };
    }
    _exercises[exercise.id] = exercise;
    await _storeLocalExercise(exercise);
    notifyListeners();
  }

  Future<void> archive(Exercise exercise) {
    return _setArchived(exercise, true);
  }

  Future<void> unarchive(Exercise exercise) {
    return _setArchived(exercise, false);
  }

  /// The server's copy wins where there is one; otherwise the edit is the copy.
  ///
  /// The current copy, not [exercise]: a page holding the one it was opened
  /// with would otherwise archive a name or a pattern edited since.
  Future<void> _setArchived(Exercise exercise, bool archived) async {
    final edited = (_exercises[exercise.id] ?? exercise).copyWith(isArchived: archived);
    final saved = switch (_remote.allowed) {
      true => _withLocalTags(await _remoteService.editExercise(edited)),
      false => edited,
    };
    _service.storeExercises([saved], userId: userId);
    _exercises[saved.id] = saved;
    notifyListeners();
  }

  /// Whether an exercise's history can be moved: it is the account's to move,
  /// so never without one.
  bool get canMoveHistory => _moveService != null && _remote.allowed;

  /// What moving [source]'s history onto [target] would do; nothing is written.
  Future<ExerciseMoveReport> previewMove(Exercise source, Exercise target) {
    return _moveService!.move(source.id, target.id, dryRun: true);
  }

  /// Moves everything the account holds under [source] onto [target], on the
  /// server and then in the mirror, which reads afterwards as if [target] had
  /// been used all along.
  ///
  /// Only this notifier's own state is brought up to date here. The other
  /// readers of the mirror (templates, goals, timers, history) each read it
  /// again; the app's exercise page (`_onMoveHistory`) asks each of them.
  Future<ExerciseMoveReport> moveHistory(Exercise source, Exercise target) async {
    final service = _moveService!;
    final report = await service.move(source.id, target.id);
    analytics?.exerciseHistoryMoved(
      fromCustom: source.isMine,
      toCustom: target.isMine,
      workoutExercises: report.workoutExercises,
    );
    if (userId case String id) {
      // The account has moved by now, so a mirror that fails to follow is
      // reported, not thrown: the caller would read a throw as "nothing
      // changed". What it left behind is what the next full read replaces.
      try {
        await service.mirror(report, userId: id);
      } catch (e, s) {
        onError?.call(e, stacktrace: s);
      }
      if (report.sourceDeleted) _exercises.remove(source.id);
      // the preference row moved or was dropped whole, so the units and
      // notes are read again rather than reasoned about
      final units = await _service.getExerciseUnits(id);
      final notes = await _noteService?.read(id) ?? {};
      if (userId == id) {
        _units
          ..clear()
          ..addAll(units);
        _notes
          ..clear()
          ..addAll(notes);
      }
    }
    notifyListeners();
    return report;
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

const _exerciseHistoryLimit = 30;
