part of '../api.dart';

/// Workouts: saving, replaying, editing and reading them, their images and the
/// gallery, imports from other apps, and a program workout's plan (#566).
mixin _WorkoutRoutes on Requests implements RemoteWorkoutService {
  @override
  Future<bool> deleteWorkout(String workoutId) async {
    final (_, code) = await delete('${Router.workouts}/$workoutId');
    return code == 204;
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

  @override
  Future<bool> deleteWorkoutImage(String workoutId, String imageId) async {
    final (_, code) = await delete(Router.workoutImages(workoutId), query: {'key': imageId});
    return code == 204;
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
    return (row: Workout.fromJson(json), created: created);
  }

  @override
  Future<Workout> editWorkout(Workout updated) async {
    final (json, code) = await put(Router.workout(updated.id), body: updated.toMap());
    return _workoutOr(json, code);
  }

  @override
  Future<Workout> patchWorkout(String workoutId, {DateTime? start, DateTime? end, String? name}) async {
    final (json, code) = await patch(
      Router.workout(workoutId),
      body: {
        'name': ?name,
        'start': ?start?.toIso8601String(),
        'end': ?end?.toIso8601String(),
      },
    );
    return _workoutOr(json, code);
  }

  /// A refusal with a JSON body comes back from `put` and `patch` as a result,
  /// not an exception, and parsed as a workout it dies on a null `start`.
  static Workout _workoutOr(Map<String, dynamic> json, int code) {
    return switch (code) {
      >= 200 && < 300 => Workout.fromJson(json),
      _ => throw NetworkException(statusCode: code, body: json),
    };
  }

  @override
  Future<Workout> getTargetWorkout({
    required String requesterId,
    required String targetUserId,
    required String workoutId,
  }) async {
    final (json, code) = await get(Router.userWorkout(targetUserId, workoutId));
    return switch ((code, json)) {
      (200, Map json) => Workout.fromJson(json),
      // thrown whole: the body carries a stable `code`, which is how the caller
      // tells "no such workout" apart from "not yours to see" — and both apart
      // from an outage, where nothing named comes back at all
      _ => throw json,
    };
  }

  @override
  Future<Iterable<Workout>?> getWorkouts(String userId, {int? pageSize, String? since}) async {
    // The interface still names these pageSize/since; the wire uses limit/cursor.
    final (json, code) = await get(
      '${Router.accounts}/$userId/workouts',
      query: {
        'limit': ?pageSize?.toString(),
        'cursor': ?since,
      },
    );
    return switch (json) {
      {'workouts': List l} => Page<Workout>(
        items: _readable(l, Workout.fromJson),
        hasMore: json['cursor'] != null,
      ),
      _ => null,
    };
  }

  @override
  Future<ProgressGalleryResponse> getWorkoutGallery({String? cursor, String? userId}) async {
    final (json, _) = await get('${Router.workouts}/images', query: {'cursor': ?cursor});
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

  /// The body is raw CSV — except when carrying [createCustom], which rides a
  /// JSON envelope (`{"csv": …, "createCustom": […]}`), the shape the server
  /// keys off the content type.
  ///
  /// Talks to the [client] directly rather than through [Requests.post],
  /// which runs every body through jsonEncode — the CSV must arrive as-is,
  /// not as one quoted JSON string. The trade is the mixin's private
  /// 401-reauthenticate-and-retry wrapper: an expired token fails the call
  /// (the token heals on other traffic, and retrying is free).
  Future<Map> _postImport(
    String export, {
    required ImportSource source,
    MeasurementUnit? unit,
    Duration? tzOffset,
    bool dryRun = false,
    List<String>? createCustom,
  }) async {
    final url = Uri.https(
      gateway,
      Router.workoutImports,
      {
        'source': source.name,
        if (dryRun) 'dryRun': 'true',
        'unit': ?unit?.name,
        'tzOffset': ?_formatOffset(tzOffset),
      },
    );
    final (contentType, body) = switch (createCustom) {
      null => ('text/csv', export),
      List<String> names => ('application/json', jsonEncode({'csv': export, 'createCustom': names})),
    };
    final response = await (client?.post ?? http.post)(
      url,
      headers: {...?defaultHeaders, 'Content-Type': contentType},
      body: body,
    );
    final json = _tryDecode(response.body);
    return switch ((response.statusCode, json)) {
      (200, Map json) => json,
      // kept for a manual import, on a dry run and a commit alike
      (202, Map json) => throw ImportParked(
        reason: switch (json['reason']) {
          String reason => reason,
          _ => null,
        },
      ),
      (400, {'reason': String reason}) => throw ImportRejected(reason: reason),
      _ => throw NetworkException(
        statusCode: response.statusCode,
        body: switch (json) {
          Map m => m,
          _ => null,
        },
      ),
    };
  }

  /// The gateway rejects a bad auth header with a *plain-text* body (see
  /// [reauthenticate]) — classify by status instead of letting jsonDecode's
  /// FormatException escape as the error.
  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
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
  /// keeps the first plan it gets, so sending again is harmless. A refusal is
  /// thrown whole: `400 invalid_plan` for a shape it can't read, `404` for a
  /// workout it doesn't have yet.
  Future<void> saveWorkoutPlan(String workoutId, WorkoutPlan plan) async {
    final (json, code) = await put(Router.workoutPlan(workoutId), body: plan.toMap());
    if (code != 204) throw json;
  }
}
