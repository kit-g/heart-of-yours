part of '../api.dart';

/// Exercises: the catalog and the account's own, units, notes and preferences,
/// and moving an exercise's history.
mixin _ExerciseRoutes on Requests implements RemoteExerciseService {
  @override
  Future<Iterable<Exercise>> getExercises() async {
    final (json, _) = await _lenient(get(Router.exercises));
    return switch (json) {
      {'exercises': List l} => _readable(l, Exercise.fromJson),
      _ => [],
    };
  }

  @override
  Future<Iterable<Exercise>> getOwnExercises() async {
    final (json, _) = await _lenient(get(Router.exercises, query: {'owned': 'true'}));
    return switch (json) {
      {'exercises': List l} => _readable(l, Exercise.fromJson),
      _ => [],
    };
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
      endpoint: Router.exercises,
    );
    return (row: Exercise.fromJson(json), created: created);
  }

  /// [saveUnitPreference] that fails loudly: the replay has to know a step
  /// landed before it records it. Always a `200` when it does — the endpoint
  /// is an upsert, and the device's preference is the most recent intent.
  Future<void> replayUnitPreference(String exerciseId, MeasurementUnit unit) async {
    final (json, code) = await post(
      Router.exercisePreferences,
      body: {'exerciseId': exerciseId, 'unitSystem': unit.name},
    );
    if (code >= 300) throw _unreadable(code, 'POST', Router.exercisePreferences);
  }

  @override
  Future<Exercise> editExercise(Exercise exercise) => _editExercise(exercise, rename: false);

  /// [editExercise] that also sends the name (heart-api#429). Its own call
  /// because the server checks a sent name against the account's other own
  /// exercises, case-insensitively, even when it is the name already held:
  /// sent on every edit, an account with two names differing only in case
  /// could archive neither. A name taken is [ExerciseNameTaken].
  Future<Exercise> renameExercise(Exercise exercise) => _editExercise(exercise, rename: true);

  Future<Exercise> _editExercise(Exercise exercise, {required bool rename}) async {
    final (json, code) = await _refused(
      put(
        '${Router.exercises}/${exercise.id}',
        body: {
          if (rename) 'name': exercise.name,
          'category': exercise.category.value,
          'target': exercise.target.value,
          'instructions': ?exercise.instructions,
          'archived': exercise.isArchived,
          // always sent: null is "none", and clears one the server holds (#616)
          'pattern': exercise.movement.groups.firstOrNull,
        },
      ),
      (failure) => switch (failure) {
        NetworkException(statusCode: 409, body: {'code': 'name_taken'}) => throw const ExerciseNameTaken(),
        _ => throw failure,
      },
    );
    return switch ((code, json)) {
      (200, _) => Exercise.fromJson(json),
      _ => throw _unreadable(code, 'PUT', '${Router.exercises}/${exercise.id}'),
    };
  }

  /// Moves everything the account holds under [sourceId] onto [targetId]
  /// (heart-api#140): logged exercises, template entries, the preference row
  /// and goals. With [dryRun] nothing is written, and the report is exactly
  /// what the real call would do, since the server runs the same code and
  /// rolls it back.
  ///
  /// The refusals the endpoint names are thrown as [ExerciseMoveRefused];
  /// anything else as a [NetworkException].
  Future<ExerciseMoveReport> moveExerciseHistory(
    String sourceId, {
    required String targetId,
    bool dryRun = false,
  }) async {
    final (json, code) = await _refused(
      post(
        Router.exerciseMoves(sourceId),
        body: {'targetId': targetId},
        query: {if (dryRun) 'dryRun': 'true'},
      ),
      (failure) => switch (failure) {
        NetworkException(statusCode: 400, body: {'code': 'same_exercise'}) => throw const ExerciseMoveRefused(
          .sameExercise,
        ),
        NetworkException(statusCode: 404, body: {'code': 'unknown_exercise'}) => throw const ExerciseMoveRefused(
          .unknownExercise,
        ),
        NetworkException(statusCode: 400, body: {'code': 'incompatible_exercise'}) => throw const ExerciseMoveRefused(
          .incompatibleExercise,
        ),
        _ => throw failure,
      },
    );
    return switch ((code, json)) {
      (200, Map json) => ExerciseMoveReport.fromJson(json),
      _ => throw _unreadable(code, 'POST', Router.exerciseMoves(sourceId)),
    };
  }

  /// Every preference the account holds, on a library exercise as much as on
  /// one of its own: since the catalog moved to the CDN no list the app reads
  /// carries them, so they are asked for on their own (heart-api#73).
  ///
  /// Unpaginated — a preference exists only where the user set one.
  Future<Iterable<ExercisePreference>> getExercisePreferences() async {
    final (json, _) = await _lenient(get(Router.exercisePreferences));
    return switch (json) {
      {'preferences': List l} => _readable(l, ExercisePreference.fromJson),
      _ => const <ExercisePreference>[],
    };
  }

  Future<void> setExerciseNote(String exerciseId, String? note) async {
    final (_, status) = switch (note) {
      String text => await post(Router.exercisePreferences, body: {'exerciseId': exerciseId, 'note': text}),
      null => await delete('${Router.exercisePreferences}/$exerciseId', query: {'pref': 'note'}),
    };
    if (status >= 300) {
      throw switch (note) {
        String _ => _unreadable(status, 'POST', Router.exercisePreferences),
        null => _unreadable(status, 'DELETE', '${Router.exercisePreferences}/$exerciseId'),
      };
    }
  }

  @override
  Future<void> saveUnitPreference(String exerciseId, MeasurementUnit unit) {
    return _lenient(post(Router.exercisePreferences, body: {'exerciseId': exerciseId, 'unitSystem': unit.name}));
  }

  @override
  Future<void> deleteUnitPreference(String exerciseId) {
    return _lenient(delete('${Router.exercisePreferences}/$exerciseId'));
  }
}
