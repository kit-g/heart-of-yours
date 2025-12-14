import 'dart:typed_data';

import 'package:heart_models/heart_models.dart';
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
    final (json, code) = await post(Router.accounts, body: user.toMap());
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
        if (imageMimeType != null) 'mimeType': imageMimeType,
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
  Future<String?> undoAccountDeletion(String accountId) {
    return put(
      '${Router.accounts}/$accountId',
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
  Future<bool> submitFeedback({String? feedback, Uint8List? screenshot}) async {
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
  Future<bool> deleteWorkoutImage(String workoutId) async {
    final (_, code) = await delete(Router.workoutImages(workoutId));
    return code == 204;
  }

  @override
  Future<bool> saveWorkout(Workout workout) async {
    final (_, code) = await post(Router.workouts, body: workout.toMap());
    return code == 201;
  }

  @override
  Future<Iterable<Workout>?> getWorkouts(ExerciseLookup lookForExercise, {int? pageSize, String? since}) async {
    final (json, code) = await get(
      Router.workouts,
      query: {
        if (pageSize != null) 'pageSize': pageSize.toString(),
        if (since != null) 'since': since,
      },
    );
    return switch (json) {
      {'workouts': List l} => l.map((e) => Workout.fromJson(e, lookForExercise)),
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
  Future<bool> deleteTemplate(String templateId) async {
    final (_, code) = await delete('${Router.templates}/$templateId');
    return code == 204;
  }

  @override
  Future<Iterable<Template>?> getTemplates(ExerciseLookup lookForExercise) async {
    final (json, _) = await get(Router.templates);
    return switch (json) {
      {'templates': List l} => l.map((e) => Template.fromJson(e, lookForExercise)),
      _ => null,
    };
  }

  @override
  Future<bool> saveTemplate(Template template) async {
    final (_, code) = await post(Router.templates, body: template.toMap());
    return code == 201;
  }

  @override
  Future<ProgressGalleryResponse> getWorkoutGallery({String? cursor}) async {
    final (json, _) = await get('${Router.workouts}/images', query: {'cursor': ?cursor});
    return ProgressGalleryResponse.fromJson(json);
  }
}

abstract final class Router {
  static const accounts = 'v1/accounts';
  static const exercises = 'v1/exercises';
  static const feedback = 'v1/feedback';
  static const templates = 'v1/templates';
  static const workouts = 'v1/workouts';

  static String workoutImages(String workoutId) {
    return '$workouts/$workoutId/images';
  }
}
