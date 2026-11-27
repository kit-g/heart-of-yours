part of '../api.dart';

/// Workouts: saving, replaying, editing and reading them, their images and the
/// gallery, imports from other apps, and a program workout's plan (#566).
mixin _WorkoutRoutes on Requests, _ExerciseNaming implements RemoteWorkoutService {
  /// True once deleted; a failure is thrown.
  @override
  Future<bool> deleteWorkout(String workoutId) async {
    await delete(Router.workout(workoutId));
    return true;
  }

  @override
  Future<(PreSignedUrl?, String?)> getWorkoutUploadLink(
    String workoutId, {
    String? imageMimeType,
  }) async {
    final (json, _) = await put(
      Router.workoutImages(workoutId),
      body: {'mimeType': ?imageMimeType},
    );
    return switch (json) {
      {'url': String url, 'fields': Map fields} => (
        (
          fields: Map.castFrom<dynamic, dynamic, String, String>(fields),
          url: url,
        ),
        json['destinationUrl']?.toString(),
      ),
      _ => (null, null),
    };
  }

  /// True once detached; a failure is thrown.
  @override
  Future<bool> deleteWorkoutImage(String workoutId, String imageId) async {
    await delete(Router.workoutImages(workoutId), query: {'key': imageId});
    return true;
  }

  @override
  Future<Workout> saveWorkout(Workout workout) async {
    return (await replayWorkout(workout)).row;
  }

  /// [saveWorkout], with the server's answer kept: whether this call created
  /// the row or found it already there under the same client id.
  ///
  /// Every create in this file sends the client-minted id, and the server keys
  /// idempotency on it (heart-api#66): a repeat lands on the same row with a
  /// `200` instead of a duplicate. The upsync replay counts those answers for
  /// its "n uploaded, n already there" line; the everyday paths only want the
  /// row and read it off this.
  Future<({Workout row, bool created})> replayWorkout(Workout workout) async {
    final (json, created) = _created(await post(Router.workouts, body: workout.toMap()));
    return (row: Workout.fromJson(_named(json)), created: created);
  }

  @override
  Future<Workout> editWorkout(Workout updated) async {
    final (json, _) = await put(Router.workout(updated.id), body: updated.toMap());
    return Workout.fromJson(_named(json));
  }

  @override
  Future<Workout> patchWorkout(String workoutId, {DateTime? start, DateTime? end, String? name}) async {
    final (json, _) = await patch(
      Router.workout(workoutId),
      body: {
        'name': ?name,
        'start': ?start?.toIso8601String(),
        'end': ?end?.toIso8601String(),
      },
    );
    return Workout.fromJson(_named(json));
  }

  @override
  Future<Workout> getTargetWorkout({
    required String requesterId,
    required String targetUserId,
    required String workoutId,
  }) async {
    // a refusal is a [ServerRefusal], whose `code` is how the caller tells
    // "no such workout" apart from "not yours to see", and both apart from an
    // outage, where nothing named comes back at all
    final (json, _) = await get(Router.userWorkout(targetUserId, workoutId));
    return Workout.fromJson(_named(json));
  }

  @override
  Future<Iterable<Workout>?> getWorkouts(String userId, {int? pageSize, String? since}) async {
    // The interface still names these pageSize/since; the wire uses limit/cursor.
    final (json, _) = await get(
      Router.clientWorkouts(userId),
      query: {
        'limit': ?pageSize?.toString(),
        'cursor': ?since,
      },
    );
    return switch (json) {
      {'workouts': List l} => Page<Workout>(
        items: _readable(_namedAll(l, counts: true), Workout.fromJson),
        hasMore: json['cursor'] != null,
      ),
      _ => null,
    };
  }

  @override
  Future<ProgressGalleryResponse> getWorkoutGallery({String? cursor, String? userId}) async {
    final (json, _) = await get(Router.workoutGallery, query: {'cursor': ?cursor});
    return ProgressGalleryResponse.fromJson(json);
  }

  /// Uploads a raw workout-history [export] and returns the server's tally.
  ///
  /// The server does all parsing, unit normalization, exercise matching and
  /// dedup, and the import is idempotent — re-sending the same file is a safe
  /// no-op. [unit] is only a fallback for rows that carry no unit columns of
  /// their own; [tzOffset] anchors the export's naive local timestamps and
  /// goes on the wire as `±HH:MM`.
  ///
  /// The dry run: parses and resolves the export server-side, writes nothing,
  /// and reports what a commit would do — most importantly, which exercise
  /// names would become the user's custom exercises ([WorkoutImportPreview]).
  Future<WorkoutImportPreview> previewImportedWorkouts(
    String export, {
    ImportSource source = .strong,
    MeasurementUnit? unit,
    Duration? tzOffset,
  }) async {
    final json = await _postImport(
      export,
      source: source,
      unit: unit,
      tzOffset: tzOffset,
      dryRun: true,
    );
    return WorkoutImportPreview.fromJson(json);
  }

  /// The commit. [createCustom] is the allowlist of unmatched exercise names
  /// the user approved: null means create them all (the one-shot import),
  /// present — even empty — means exactly those and no others; sets on a
  /// declined name are skipped and counted, never silently dropped.
  Future<WorkoutImportReport> importWorkouts(
    String export, {
    ImportSource source = .strong,
    MeasurementUnit? unit,
    Duration? tzOffset,
    List<String>? createCustom,
  }) async {
    final json = await _postImport(
      export,
      source: source,
      unit: unit,
      tzOffset: tzOffset,
      createCustom: createCustom,
    );
    return WorkoutImportReport.fromJson(json);
  }

  /// The export rides a JSON envelope (`{"csv": …, "createCustom": […]}`),
  /// which the server reads by its content type; without `createCustom` it
  /// is the one-shot import that creates every unmatched name. Sent through
  /// [Requests.post] like every other call, so a failure is read in one
  /// place ([Api.failure]): the upgrade gate fires on a 426, a refusal keeps
  /// the response it came from, and an expired token is refreshed and asked
  /// again.
  Future<Map> _postImport(
    String export, {
    required ImportSource source,
    MeasurementUnit? unit,
    Duration? tzOffset,
    bool dryRun = false,
    List<String>? createCustom,
  }) async {
    try {
      final (json, code) = await post(
        Router.workoutImports,
        headers: const {'Content-Type': 'application/json'},
        body: {'csv': export, 'createCustom': ?createCustom},
        query: {
          'source': source.name,
          if (dryRun) 'dryRun': 'true',
          'unit': ?unit?.name,
          'tzOffset': ?_formatOffset(tzOffset),
        },
      );
      return switch (code) {
        // kept for a manual import, on a dry run and a commit alike
        202 => throw ImportParked(
          reason: switch (json['reason']) {
            String reason => reason,
            _ => null,
          },
        ),
        _ => json,
      };
    } on ServerRefusal catch (refusal, stacktrace) {
      if (refusal case ServerRefusal(status: 400, details: {'reason': final String reason})) {
        Error.throwWithStackTrace(ImportRejected(reason: reason), stacktrace);
      }
      rethrow;
    }
  }

  /// `±HH:MM`, e.g. `-04:00` — the query-parameter shape the import endpoint
  /// expects for [DateTime.timeZoneOffset].
  static String? _formatOffset(Duration? offset) {
    if (offset == null) return null;
    final sign = switch (offset.isNegative) {
      true => '-',
      false => '+',
    };
    final minutes = offset.abs().inMinutes;
    final hh = '${minutes ~/ 60}'.padLeft(2, '0');
    final mm = '${minutes % 60}'.padLeft(2, '0');
    return '$sign$hh:$mm';
  }

  /// What a program workout was asked to be (#558, #566). `204`; the server
  /// keeps the first plan it gets, so sending again is harmless. Refusals are
  /// [ServerRefusal]s: `400 invalid_plan` for a shape it can't read, `404` for
  /// a workout it doesn't have yet.
  Future<void> saveWorkoutPlan(String workoutId, WorkoutPlan plan) {
    return put(Router.workoutPlan(workoutId), body: plan.toMap());
  }
}
