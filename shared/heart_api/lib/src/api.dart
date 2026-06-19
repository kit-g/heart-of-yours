import 'dart:typed_data';

import 'package:heart_models/heart_models.dart' hide PreSignedUrl;
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

class Api
    with Requests
    implements
        AccountService,
        FeedbackService,
        HeaderAuthenticatedService,
        RemoteExerciseService,
        RemoteTemplateService,
        RemoteWorkoutService {
  @override
  late String gateway;

  static final Api instance = Api._();

  @override
  Map<String, String>? defaultHeaders;

  Api._();

  factory Api({
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

  @override
  void reauthenticate(String sessionToken) {
    instance.defaultHeaders?['Authorization'] = sessionToken;
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
    final void Function(int bytes, int totalBytes)? onProgress,
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
    final (json, code) = await post(Router.workouts, body: workout.toMap());
    return Workout.fromJson(json);
  }

  @override
  Future<Workout> editWorkout(Workout updated) async {
    final (json, code) = await put(Router.workout(updated.id), body: updated.toMap());
    return Workout.fromJson(json);
  }

  @override
  Future<Iterable<Workout>?> getWorkouts(String userId, {int? pageSize, String? since}) async {
    final (json, code) = await get(
      '${Router.accounts}/$userId/workouts',
      query: {
        'pageSize': ?pageSize?.toString(),
        'since': ?since,
      },
    );
    return switch (json) {
      {'workouts': List l} => l.map((e) => Workout.fromJson(e)),
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
    final (json, code) = await post(
      Router.exercises,
      body: {
        'name': exercise.name,
        'category': exercise.category.value,
        'target': exercise.target.value,
      },
    );
    return switch (code) {
      200 => Exercise.fromJson(json),
      _ => throw ArgumentError(json),
    };
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

  @override
  Future<void> saveUnitPreference(String exerciseId, MeasurementUnit unit) {
    return post(
      Router.exercisePreferences,
      body: {'exerciseId': exerciseId, 'unitSystem': unit.name},
    );
  }

  @override
  Future<void> deleteUnitPreference(String exerciseId)  {
    return delete('${Router.exercisePreferences}/$exerciseId');
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
    final (json, code) = await post(Router.templates, body: template.toMap());
    return Template.fromJson(json);
  }

  @override
  Future<Template> editTemplate(Template template) async {
    final (json, code) = await put(Router.template(template.id), body: template.toMap());
    return Template.fromJson(json);
  }

  @override
  Future<ProgressGalleryResponse> getWorkoutGallery({String? cursor, String? userId}) async {
    final (json, _) = await get('${Router.workouts}/images', query: {'cursor': ?cursor});
    return ProgressGalleryResponse.fromJson(json);
  }
}

abstract final class Router {
  static const accounts = 'v1/accounts';
  static const exercises = 'v1/exercises';
  static const exercisePreferences = 'v1/exercise-preferences';
  static const feedback = 'v1/feedback';
  static const templates = 'v1/templates';
  static const workouts = 'v1/workouts';

  static String workoutImages(String workoutId) {
    return '$workouts/$workoutId/images';
  }

  static String template(String templateId) {
    return '$templates/$templateId';
  }

  static String workout(String workoutId) {
    return '$workouts/$workoutId';
  }
}
