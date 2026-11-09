part of '../api.dart';

/// Exercises: the catalog and the account's own, units, notes and preferences,
/// and moving an exercise's history.
mixin _ExerciseRoutes on Requests implements RemoteExerciseService {
  @override
  Future<Iterable<Exercise>> getExercises() async {
    final (json, code) = await get(Router.exercises);
    return switch (json) {
      {'exercises': List l} => _readable(l, Exercise.fromJson),
      _ => [],
    };
  }

  @override
  Future<Iterable<Exercise>> getOwnExercises() async {
    final (json, code) = await get(Router.exercises, query: {'owned': 'true'});
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
        },
      ),
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
    if (code >= 300) throw json;
  }

  @override
  Future<Exercise> editExercise(Exercise exercise) async {
    final (json, code) = await put(
      '${Router.exercises}/${exercise.id}',
      body: {
        'category': exercise.category.value,
        'target': exercise.target.value,
        'instructions': ?exercise.instructions,
        'archived': exercise.isArchived,
      },
    );
    return switch (code) {
      200 => Exercise.fromJson(json),
      _ => throw ArgumentError(json),
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
    final (json, code) = await post(
      Router.exerciseMoves(sourceId),
      body: {'targetId': targetId},
      query: {if (dryRun) 'dryRun': 'true'},
    );
    return switch ((code, json)) {
      (200, Map json) => ExerciseMoveReport.fromJson(json),
      (400, {'code': 'same_exercise'}) => throw const ExerciseMoveRefused(.sameExercise),
      (404, {'code': 'unknown_exercise'}) => throw const ExerciseMoveRefused(.unknownExercise),
      (400, {'code': 'incompatible_exercise'}) => throw const ExerciseMoveRefused(.incompatibleExercise),
      _ => throw NetworkException(statusCode: code, body: json),
    };
  }

  /// Every preference the account holds, on a library exercise as much as on
  /// one of its own: since the catalog moved to the CDN no list the app reads
  /// carries them, so they are asked for on their own (heart-api#73).
  ///
  /// Unpaginated — a preference exists only where the user set one.
  Future<Iterable<ExercisePreference>> getExercisePreferences() async {
    final (json, _) = await get(Router.exercisePreferences);
    return switch (json) {
      {'preferences': List l} => _readable(l, ExercisePreference.fromJson),
      _ => const <ExercisePreference>[],
    };
  }

  Future<void> setExerciseNote(String exerciseId, String? note) async {
    final (body, status) = switch (note) {
      String text => await post(Router.exercisePreferences, body: {'exerciseId': exerciseId, 'note': text}),
      null => await delete('${Router.exercisePreferences}/$exerciseId', query: {'pref': 'note'}),
    };
    if (status < 200 || status >= 300) throw {'code': body['code'], 'status': status};
  }

  @override
  Future<void> saveUnitPreference(String exerciseId, MeasurementUnit unit) {
    return post(
      Router.exercisePreferences,
      body: {'exerciseId': exerciseId, 'unitSystem': unit.name},
    );
  }

  @override
  Future<void> deleteUnitPreference(String exerciseId) {
    return delete('${Router.exercisePreferences}/$exerciseId');
  }
}
