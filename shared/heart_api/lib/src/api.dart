import 'dart:typed_data';

import 'package:heart_models/heart_models.dart';
import 'package:network_utils/network_utils.dart';

final class Api
    with Requests
    implements
        AccountService,
        FeedbackService,
        HeaderAuthenticatedService,
        RemoteExerciseService,
        RemoteWorkoutService {
  @override
  late String gateway;

  static final Api instance = Api._();

  @override
  Map<String, String>? defaultHeaders;

  Api._();

  factory Api({required String gateway}) {
    instance.gateway = gateway;
    return instance;
  }

  @override
  void authenticate(Map<String, String> headers) {
    // print((headers['Authorization'] as String).substring(0, 400));
    // print((headers['Authorization'] as String).substring(400));
    instance.defaultHeaders = headers;
  }

  @override
  Future<String?> deleteAccount({required String accountId}) async {
    final (json, code) = await delete('${_Router.accounts}/$accountId');
    return switch (code) {
      < 400 => null,
      _ => throw json, // error
    };
  }

  @override
  Future<PreSignedUrl?> getAvatarUploadLink(String userId, {String? imageMimeType}) async {
    final (json, code) = await get(
      '${_Router.accounts}/$userId',
      query: {
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
  Future<bool> uploadAvatar(
    PreSignedUrl cred,
    (String field, List<int> value, {String? filename, String? contentType}) file, {
    final void Function(int bytes, int totalBytes)? onProgress,
  }) {
    return uploadToBucket(cred, file, onProgress: onProgress);
  }

  @override
  Future<bool> removeAvatar(String userId) async {
    final (_, code) = await put(
      '${_Router.accounts}/$userId',
      body: {'action': 'removeAvatar'},
    );
    return 200 <= code && code < 300;
  }

  @override
  Future<String?> undoAccountDeletion(String accountId) {
    return put(
      '${_Router.accounts}/$accountId',
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
    final (json, code) = await post(_Router.feedback, body: {'message': feedback});

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
    final (_, code) = await delete('${_Router.workouts}/$workoutId');
    return code == 204;
  }

  @override
  Future<bool> saveWorkout(Workout workout) async {
    final (_, code) = await post(
      _Router.workouts,
      body: workout.toMap(),
    );
    return code == 201;
  }

  @override
  Future<Iterable<Workout>?> getWorkouts(ExerciseLookup lookForExercise, {int? pageSize, String? since}) async {
    final (json, code) = await get(
      _Router.workouts,
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
    final (json, code) = await get(_Router.exercises);
    return switch (json) {
      {'exercises': List l} => l.map((e) => Exercise.fromJson(e)),
      _ => [],
    };
  }
}

abstract final class _Router {
  static const accounts = 'api/accounts';
  static const exercises = 'api/exercises';
  static const feedback = 'api/feedback';
  static const workouts = 'api/workouts';
}
