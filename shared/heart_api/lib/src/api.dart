import 'dart:convert';
import 'dart:typed_data';

import 'package:heart_models/heart_models.dart' hide PreSignedUrl;
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

import 'imports.dart';

class Api
    with Requests
    implements
        AccountService,
        ApiTemplateFolderService,
        FeedbackService,
        GoalService,
        HeaderAuthenticatedService,
        RemoteExerciseService,
        RemoteTemplateService,
        RemoteWorkoutService {
  @override
  late String gateway;

  static final Api instance = Api._();

  @override
  Map<String, String>? defaultHeaders;

  new _();

  factory({
    required String gateway,
    http.Client? client,
    Response Function(Json)? onUnauthorized,
    Response Function(Json)? onUpgradeRequired,
  }) {
    instance
      ..gateway = gateway
      ..client = client
      ..onUnauthorized = onUnauthorized
      ..onUpgradeRequired = onUpgradeRequired;
    return instance;
  }

  @override
  http.Client? client;

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  // Every verb runs through [_tripwire]: the one answer that must never come
  // back is caught before any caller can act on it.

  @override
  Future<Response> get(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.get(endpoint, headers: headers, query: query).then(_tripwire);
  }

  @override
  Future<Response> post(String endpoint, {Map<String, String>? headers, Json? body, Map<String, dynamic>? query}) {
    return super.post(endpoint, headers: headers, body: body, query: query).then(_tripwire);
  }

  @override
  Future<Response> put(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.put(endpoint, headers: headers, body: body).then(_tripwire);
  }

  @override
  Future<Response> patch(String endpoint, {Map<String, String>? headers, Json? body}) {
    return super.patch(endpoint, headers: headers, body: body).then(_tripwire);
  }

  @override
  Future<Response> delete(String endpoint, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return super.delete(endpoint, headers: headers, query: query).then(_tripwire);
  }

  /// The server refused the token because it belongs to an anonymous
  /// session (heart-of-yours#91). That token never has business on the wire —
  /// `RemoteAccess` closes every leg while the session is anonymous — so this
  /// is not a failure to retry but a gate that failed, and it is thrown as its
  /// own type so it reaches Sentry under a name rather than as a body map.
  static Response _tripwire(Response response) {
    return switch (response) {
      ({'code': 'anonymous_account'}, 403) => throw const AnonymousSessionRejected(),
      _ => response,
    };
  }

  @override
  void reauthenticate(String sessionToken) {
    // Re-apply the scheme. Callers hand over a raw provider token (see
    // `onReauthenticate` in `main.dart`, which passes Firebase's id token
    // straight through), while the header this replaces was built as
    // `Bearer <token>` by `headers()`.
    //
    // Dropping the prefix does not read as unauthenticated — the gateway
    // rejects the header outright, with a *plain-text* body. That body then
    // fails to parse, so the caller saw a FormatException from deep inside
    // jsonDecode rather than a 401, on whichever request happened to be in
    // flight when the token expired. [isAuthenticated] asserts the same shape.
    instance.defaultHeaders?['Authorization'] = switch (sessionToken.startsWith('Bearer ')) {
      true => sessionToken,
      false => 'Bearer $sessionToken',
    };
  }

  /// Re-states what language the user speaks, mid-session.
  ///
  /// `Accept-Language` is set on every request via [defaultHeaders], built
  /// once at startup — but the device locale can change under a running app
  /// (in-app settings on iOS 13+, a returning foregrounded app on Android).
  /// Same single-key mutation shape as [reauthenticate].
  void localize(String languageTag) {
    instance.defaultHeaders?['Accept-Language'] = languageTag;
  }

  @override
  bool get isAuthenticated {
    return switch (defaultHeaders) {
      {'Authorization': String token} => switch (token.split(' ')) {
        ['Bearer', String token] when token.isNotEmpty => true,
        _ => false,
      },
      _ => false,
    };
  }

  @override
  Future<User> registerAccount(User user) async {
    final (json, code) = await put(Router.accounts, body: user.toMap());
    return switch ((code, json)) {
      (200, Map json) => User.fromJson(json),
      (400, {'code': 'ACCOUNT_DELETED'}) => throw AccountDeleted(),
      (426, _) => throw UpgradeRequired(),
      _ => throw json, // error
    };
  }

  @override
  Future<String?> deleteAccount({required String accountId}) async {
    final (json, code) = await delete(Router.accounts);
    return switch (code) {
      < 400 => null,
      426 => throw UpgradeRequired(),
      _ => throw json, // error
    };
  }

  @override
  Future<PreSignedUrl?> getAvatarUploadLink(String userId, {String? imageMimeType}) async {
    final (json, code) = await put(
      '${Router.accounts}/$userId',
      body: {
        'action': 'uploadAvatar',
        'mimeType': ?imageMimeType,
      },
    );
    return switch (json) {
      {'url': String url, 'fields': Map fields} => (
        fields: Map.castFrom<dynamic, dynamic, String, String>(fields),
        url: url,
      ),
      _ => null,
    };
  }

  @override
  Future<bool> uploadFile(
    PreSignedUrl cred,
    (String field, List<int> value, {String? filename, String? contentType}) file, {
    void Function(int bytes, int totalBytes)? onProgress,
  }) {
    return uploadToBucket(cred, file, onProgress: onProgress);
  }

  @override
  Future<bool> removeAvatar(String userId) async {
    final (_, code) = await put(
      '${Router.accounts}/$userId',
      body: {'action': 'removeAvatar'},
    );
    return 200 <= code && code < 300;
  }

  @override
  Future<String?> undoAccountDeletion() {
    return put(
      Router.accounts,
      body: {'action': 'undoAccountDeletion'},
    ).then(
      (response) {
        final (json, code) = response;
        return switch (code) {
          < 400 => null,
          _ => throw json, // error
        };
      },
    );
  }

  @override
  Future<bool> submitFeedback({required String mimeType, String? feedback, Uint8List? screenshot}) async {
    final (json, code) = await post(Router.feedback, body: {'message': feedback});

    final link = switch (json) {
      {'url': String url, 'fields': Map fields} => (
        fields: Map.castFrom<dynamic, dynamic, String, String>(fields),
        url: url,
      ),
      _ => null,
    };

    if (link != null && screenshot != null) {
      uploadToBucket(link, ('file', screenshot, filename: null, contentType: null));
      return true;
    }
    return false;
  }

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

  /// `201` made the row, `200` found it — by id, or by name for the two
  /// resources with one. Anything else is thrown whole, code and all, so the
  /// caller can tell a refusal (`id_taken`, `goal_limit`) from an outage.
  static (Map, bool) _created((Map, int) response) {
    return switch (response) {
      (Map json, 201) => (json, true),
      (Map json, 200) => (json, false),
      (final json, _) => throw json,
    };
  }

  /// [body] with its `id` only when it is one the server will take.
  ///
  /// Templates minted before heart-of-yours#96 carry a timestamp for an id;
  /// the server validates the shape and answers a `400` to anything that is
  /// not a v7 uuid, so such an id is left off and the server mints one. The
  /// caller reconciles the local row with whatever comes back, as it always
  /// has for templates.
  static Map<String, dynamic> _withClientId(Map<String, dynamic> body) {
    return switch (body['id']) {
      String id when isUuidV7(id) => body,
      _ => body..remove('id'),
    };
  }

  @override
  Future<Workout> editWorkout(Workout updated) async {
    final (json, code) = await put(Router.workout(updated.id), body: updated.toMap());
    return Workout.fromJson(json);
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
    return Workout.fromJson(json);
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
        items: l.map((e) => Workout.fromJson(e)).toList(),
        hasMore: json['cursor'] != null,
      ),
      _ => null,
    };
  }

  @override
  Future<Iterable<Exercise>> getExercises() async {
    final (json, code) = await get(Router.exercises);
    return switch (json) {
      {'exercises': List l} => l.map((e) => Exercise.fromJson(e)),
      _ => [],
    };
  }

  @override
  Future<Iterable<Exercise>> getOwnExercises() async {
    final (json, code) = await get(Router.exercises, query: {'owned': 'true'});
    return switch (json) {
      {'exercises': List l} => l.map((e) => Exercise.fromJson(e)),
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
      '${Router.exercises}/${exercise.name}',
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

  /// Every preference the account holds, on a library exercise as much as on
  /// one of its own: since the catalog moved to the CDN no list the app reads
  /// carries them, so they are asked for on their own (heart-api#73).
  ///
  /// Unpaginated — a preference exists only where the user set one.
  Future<Iterable<ExercisePreference>> getExercisePreferences() async {
    final (json, _) = await get(Router.exercisePreferences);
    return switch (json) {
      {'preferences': List l} => l.map((each) => ExercisePreference.fromJson(each as Map)).toList(),
      _ => const <ExercisePreference>[],
    };
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

  @override
  Future<Iterable<Goal>> getTargetUserGoals({
    required String requesterId,
    required String targetUserId,
    bool archived = false,
  }) async {
    // Reading goals is scoped by whose they are — the same shape workouts use,
    // where asking for your own id is the first allowed case. `archived` picks
    // a slice rather than widening one: true returns only the achieved goals.
    final (json, _) = await get(
      Router.userGoals(targetUserId),
      // as a query parameter, not glued onto the path — `Uri.https` encodes the
      // path, so a `?` in it arrives as `%3F` and the server sees one long path
      // segment that matches no route
      query: switch (archived) {
        true => const {'archived': 'true'},
        false => null,
      },
    );
    return switch (json) {
      {'goals': List l} => l.map((each) => Goal.fromJson(each as Map)),
      _ => const <Goal>[],
    };
  }

  @override
  Future<Goal> createGoal(Goal goal, String userId) async {
    return (await replayGoal(goal)).row;
  }

  /// See [replayWorkout]. The body carries a stable `code` on a refusal;
  /// thrown whole so the caller can tell one from an outage instead of
  /// retrying both forever.
  Future<({Goal row, bool created})> replayGoal(Goal goal) async {
    final (json, created) = _created(
      await post(
        Router.goals,
        // the client's id rides on a create only — an update addresses its
        // goal by path, and the server preserves the id it was first given
        body: {'id': ?goal.id, ...goal.toBody()},
      ),
    );
    return (row: Goal.fromJson(json), created: created);
  }

  @override
  Future<Goal> updateGoal(String goalId, Goal goal, String userId) async {
    final (json, code) = await put(Router.goal(goalId), body: goal.toBody());
    return switch ((code, json)) {
      (200, Map json) => Goal.fromJson(json),
      _ => throw json,
    };
  }

  @override
  Future<void> deleteGoal(String goalId, String userId) {
    return delete(Router.goal(goalId));
  }

  @override
  Future<Goal> markStageAchieved(
    String goalId,
    String stageId,
    String userId,
    DateTime achievedAt, {
    String? achievedBy,
  }) async {
    final (json, code) = await put(
      Router.goalStage(goalId, stageId),
      body: {
        'achievedAt': achievedAt.toUtc().toIso8601String(),
        // the workout credited with the rung; the server rejects one the
        // caller does not own, so it is sent only when we have it
        'achievedBy': ?achievedBy,
      },
    );
    return switch ((code, json)) {
      (200, Map json) => Goal.fromJson(json),
      _ => throw json,
    };
  }

  @override
  Future<bool> deleteTemplate(String templateId) async {
    final (_, code) = await delete('${Router.templates}/$templateId');
    return code == 204;
  }

  @override
  Future<Iterable<Template>?> getTemplates() async {
    final (json, _) = await get(Router.templates);
    return switch (json) {
      {'templates': List l} => l.map((e) => Template.fromJson(e)),
      _ => null,
    };
  }

  @override
  Future<Template> saveTemplate(Template template) async {
    return (await replayTemplate(template)).row;
  }

  /// See [replayWorkout]. Two templates may share a name — no name match here.
  Future<({Template row, bool created})> replayTemplate(Template template) async {
    final (json, created) = _created(await post(Router.templates, body: _withClientId(template.toMap())));
    return (row: Template.fromJson(json), created: created);
  }

  @override
  Future<Template> editTemplate(Template template) async {
    final (json, code) = await put(Router.template(template.id), body: template.toMap());
    return Template.fromJson(json);
  }

  /// Files [template] into [folderId], or unfiles it when null.
  ///
  /// A dedicated call rather than [editTemplate] because `template.toMap()`
  /// carries no `folderId` key — the server reads its absence as "leave the
  /// filing alone" — and because the PUT is a full replace, the body must be
  /// the whole template, not the one changed field.
  Future<Template> moveTemplate(Template template, {required String? folderId}) async {
    final (json, code) = await put(
      Router.template(template.id),
      body: {
        ...template.toMap(),
        'folderId': folderId,
      },
    );
    return switch ((code, json)) {
      (200, Map json) => Template.fromJson(json),
      _ => throw json,
    };
  }

  /// The interface is owner-scoped for the server's sake; over HTTP the caller
  /// is whoever the auth header says, so [userId] plays no part in the request.
  @override
  Future<Iterable<TemplateFolder>> getFolders({required String userId}) async {
    final (json, code) = await get(Router.templateFolders);
    return switch ((code, json)) {
      (200, {'folders': List l}) => l.map((e) => TemplateFolder.fromJson(e as Map)),
      _ => throw json,
    };
  }

  @override
  Future<TemplateFolder> createFolder({required String userId, required TemplateFolder folder}) async {
    return (await replayFolder(folder)).row;
  }

  /// See [replayWorkout]. A `200` here can also be a name match, like
  /// [replayExercise]: the account's folder by that name comes back, under
  /// its own id. A folder made in the app carries no id until the server
  /// mints one, so the key is sent only when there is one to send.
  Future<({TemplateFolder row, bool created})> replayFolder(TemplateFolder folder) async {
    final (json, created) = _created(
      await post(
        Router.templateFolders,
        body: {'id': ?folder.id, 'name': folder.name, 'order': folder.order},
      ),
    );
    return (row: TemplateFolder.fromJson(json), created: created);
  }

  @override
  Future<TemplateFolder> updateFolder({
    required String userId,
    required String folderId,
    required TemplateFolder folder,
  }) async {
    final (json, code) = await put(
      Router.templateFolder(folderId),
      body: {'name': folder.name, 'order': folder.order},
    );
    return switch ((code, json)) {
      (200, Map json) => TemplateFolder.fromJson(json),
      _ => throw json,
    };
  }

  @override
  Future<void> deleteFolder({required String userId, required String folderId}) async {
    final (json, code) = await delete(Router.templateFolder(folderId));
    if (code >= 400) throw json;
  }

  @override
  Future<Iterable<TemplateShare>> shareFolder({
    required String coachId,
    required String targetUserId,
    required String folderId,
  }) async {
    final (json, code) = await post(Router.folderShare(targetUserId, folderId));
    return switch ((code, json)) {
      (200, {'shares': List l}) => l.map((e) => _shareFromJson(e as Map)),
      _ => throw json,
    };
  }

  /// [TemplateShare] only knows how to read itself off a database row; this is
  /// its wire shape, which nests the student as `assignedTo`.
  static TemplateShare _shareFromJson(Map json) {
    return TemplateShare(
      id: json['id'].toString(),
      masterTemplateId: json['masterTemplateId'].toString(),
      studentTemplateId: json['studentTemplateId'].toString(),
      templateName: json['templateName'] as String? ?? '',
      assignedTo: switch (json['assignedTo']) {
        final Map m => Profile.fromJson(m),
        _ => throw ArgumentError.value(json, 'assignedTo', 'a share needs its student'),
      },
      assignedAt: switch (json['assignedAt']) {
        final String s => DateTime.parse(s),
        _ => DateTime.timestamp(),
      },
    );
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
}

/// An anonymous session's token reached the server, which answered `403
/// anonymous_account`. The remote leg is meant to be closed for the whole of
/// an anonymous session, so this is a tripwire: reported, never retried.
class AnonymousSessionRejected implements Exception {
  const new();

  @override
  String toString() => 'AnonymousSessionRejected: an anonymous token reached heart-api';
}

abstract final class Router {
  static const accounts = 'v1/accounts';
  static const exercises = 'v1/exercises';
  static const exercisePreferences = 'v1/exercise-preferences';
  static const feedback = 'v1/feedback';
  static const goals = 'v1/goals';
  static const templates = 'v1/templates';
  static const templateFolders = 'v1/template-folders';
  static const workouts = 'v1/workouts';
  static const workoutImports = '$workouts/imports';

  static String goal(String goalId) {
    return '$goals/$goalId';
  }

  static String userGoals(String targetUserId) {
    return '$accounts/$targetUserId/goals';
  }

  static String userWorkout(String targetUserId, String workoutId) {
    return '$accounts/$targetUserId/workouts/$workoutId';
  }

  static String goalStage(String goalId, String stageId) {
    return '$goals/$goalId/stages/$stageId';
  }

  static String workoutImages(String workoutId) {
    return '$workouts/$workoutId/images';
  }

  static String template(String templateId) {
    return '$templates/$templateId';
  }

  static String templateFolder(String folderId) {
    return '$templateFolders/$folderId';
  }

  static String folderShare(String targetUserId, String folderId) {
    return '$accounts/$targetUserId/folders/$folderId';
  }

  static String workout(String workoutId) {
    return '$workouts/$workoutId';
  }
}

extension on Goal {
  /// The definition, the ladder, and which side of the card it lives on.
  ///
  /// `id` and `createdAt` stay the server's to mint. `archived` does not: the
  /// app decides when a finished goal is put away, and the server counts only
  /// non-archived goals against the cap — so leaving it out meant archiving
  /// never persisted, and the next pull handed the goal straight back to the
  /// live list.
  ///
  /// Stage ids *are* sent when we have them — the server preserves the ones it
  /// is given, which is what keeps an offline-minted ladder addressable.
  Map<String, dynamic> toBody() {
    return {
      'metric': metric.value,
      'exerciseId': ?exerciseId,
      'cadence': ?cadence?.value,
      'archived': archived,
      'stages': stages.map((stage) => stage.toMap()).toList(),
    };
  }
}
