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
