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
  Future<void> deleteAccount({required String accountId,required String password}) {
    return delete('${_Router.accounts}/$accountId', query: {'password': password});
  }

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }
}

abstract final class _Router {
  static const accounts = 'api/accounts';
}
