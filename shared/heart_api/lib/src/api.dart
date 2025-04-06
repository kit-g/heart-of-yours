import 'package:heart_models/heart_models.dart';
import 'package:network_utils/network_utils.dart';

final class Api with Requests implements AccountService, HeaderAuthenticatedService {
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
}

abstract final class _Router {
  static const accounts = 'api/accounts';
}
