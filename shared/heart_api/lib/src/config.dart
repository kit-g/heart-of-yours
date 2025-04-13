import 'package:heart_models/heart_models.dart';
import 'package:network_utils/network_utils.dart';

final class ConfigApi with Requests implements RemoteConfigService, HeaderAuthenticatedService {
  @override
  late String gateway;

  static final ConfigApi instance = ConfigApi._();

  @override
  Map<String, String>? defaultHeaders;

  ConfigApi._();

  factory ConfigApi({required String gateway}) {
    instance.gateway = gateway;
    return instance;
  }

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  @override
  Future<Map> getRemoteConfig() async {
    final (json, _) = await get('/config');
    return json;
  }

  @override
  bool get isAuthenticated => false;
}
