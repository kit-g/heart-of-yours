part of '../api.dart';

/// Exercises: the catalog and the account's own, units, notes and preferences,
/// and moving an exercise's history.
mixin _ExerciseRoutes on Requests implements RemoteExerciseService {
  /// A failure is thrown, never answered as no exercises: the caller stores
  /// what comes back, and an empty list says the account has none.
  @override
  Future<Iterable<Exercise>> getExercises() async {
    final (json, _) = await get(Router.exercises);
    return _readable(json['exercises'] as List, Exercise.fromJson);
  }

  /// See [getExercises].
  @override
  Future<Iterable<Exercise>> getOwnExercises() async {
    final (json, _) = await get(Router.exercises, query: {'owned': 'true'});
    return _readable(json['exercises'] as List, Exercise.fromJson);
  }

  @override
  Future<Exercise> makeExercise(Exercise exercise) async {
    return (await replayExercise(exercise)).row;
  }

  /// See [replayWorkout]. A `200` here can also be a name match: the account
  /// already has a custom by this name, and the row that comes back is that
  /// one, under its own id.
  Future<({Exercise row, bool created})> replayExercise(Exercise exercise) async {
    final (json, created) = _created(
      await post(
        Router.exercises,
        body: {
          'id': exercise.id,
          'name': exercise.name,
          'category': exercise.category.value,
          'target': exercise.target.value,
          // the user's own words, shown on the About tab (#621)
          'instructions': ?exercise.instructions,
          // the server keeps it, so a reinstall or a second device sees it
          // too (#616); the device's own copy no longer has to carry it alone
          'pattern': ?exercise.movement.groups.firstOrNull,
        },
      ),
    );
    return (row: Exercise.fromJson(json), created: created);
  }

  /// [saveUnitPreference] that fails loudly: the replay has to know a step
  /// landed before it records it. Always a `200` when it does — the endpoint
  /// is an upsert, and the device's preference is the most recent intent.
  Future<void> replayUnitPreference(String exerciseId, MeasurementUnit unit) => saveUnitPreference(exerciseId, unit);

  @override
  Future<Exercise> editExercise(Exercise exercise) => _editExercise(exercise, rename: false);

  /// [editExercise] that also sends the name (heart-api#429). Its own call
  /// because the server checks a sent name against the account's other own
  /// exercises, case-insensitively, even when it is the name already held:
  /// sent on every edit, an account with two names differing only in case
  /// could archive neither. A name taken is [ExerciseNameTaken].
  Future<Exercise> renameExercise(Exercise exercise) => _editExercise(exercise, rename: true);

  Future<Exercise> _editExercise(Exercise exercise, {required bool rename}) async {
    try {
      final (json, _) = await put(
        Router.exercise(exercise.id),
        body: {
          if (rename) 'name': exercise.name,
          'category': exercise.category.value,
          'target': exercise.target.value,
          'instructions': ?exercise.instructions,
          'archived': exercise.isArchived,
          // always sent: null is "none", and clears one the server holds (#616)
          'pattern': exercise.movement.groups.firstOrNull,
        },
      );
      return Exercise.fromJson(json);
    } on ServerRefusal catch (refusal, stacktrace) {
      if (refusal case ServerRefusal(status: 409, code: 'name_taken')) {
        Error.throwWithStackTrace(const ExerciseNameTaken(), stacktrace);
      }
      rethrow;
    }
  }

  /// Moves everything the account holds under [sourceId] onto [targetId]
  /// (heart-api#140): logged exercises, template entries, the preference row
  /// and goals. With [dryRun] nothing is written, and the report is exactly
  /// what the real call would do, since the server runs the same code and
  /// rolls it back.
  ///
  /// The refusals the endpoint names are thrown as [ExerciseMoveRefused];
  /// anything else as it came: a [ServerRefusal] or a [NetworkException].
  Future<ExerciseMoveReport> moveExerciseHistory(
    String sourceId, {
    required String targetId,
    bool dryRun = false,
  }) async {
    try {
      final (json, _) = await post(
        Router.exerciseMoves(sourceId),
        body: {'targetId': targetId},
        query: {if (dryRun) 'dryRun': 'true'},
      );
      return ExerciseMoveReport.fromJson(json);
    } on ServerRefusal catch (refusal, stacktrace) {
      final reason = switch (refusal) {
        ServerRefusal(status: 400, code: 'same_exercise') => ExerciseMoveRefusal.sameExercise,
        ServerRefusal(status: 404, code: 'unknown_exercise') => ExerciseMoveRefusal.unknownExercise,
        ServerRefusal(status: 400, code: 'incompatible_exercise') => ExerciseMoveRefusal.incompatibleExercise,
        _ => null,
      };
      if (reason == null) rethrow;
      Error.throwWithStackTrace(ExerciseMoveRefused(reason), stacktrace);
    }
  }

  /// Every preference the account holds, on a library exercise as much as on
  /// one of its own: since the catalog moved to the CDN no list the app reads
  /// carries them, so they are asked for on their own (heart-api#73).
  ///
  /// Unpaginated — a preference exists only where the user set one.
  ///
  /// A failure is thrown, never answered as none: the caller replaces the
  /// device's notes with what this holds, and an empty answer would delete
  /// every one of them.
  Future<Iterable<ExercisePreference>> getExercisePreferences() async {
    final (json, _) = await get(Router.exercisePreferences);
    return _readable(json['preferences'] as List, ExercisePreference.fromJson);
  }

  Future<void> setExerciseNote(String exerciseId, String? note) {
    return switch (note) {
      String text => post(Router.exercisePreferences, body: {'exerciseId': exerciseId, 'note': text}),
      null => delete(Router.exercisePreference(exerciseId), query: {'pref': 'note'}),
    };
  }

  /// An upsert, so it always lands when the server is reachable; a failure is
  /// thrown.
  @override
  Future<void> saveUnitPreference(String exerciseId, MeasurementUnit unit) {
    return post(
      Router.exercisePreferences,
      body: {'exerciseId': exerciseId, 'unitSystem': unit.name},
    );
  }

  @override
  Future<void> deleteUnitPreference(String exerciseId) => delete(Router.exercisePreference(exerciseId));
}
