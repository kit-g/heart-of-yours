import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

class Cdn with Requests implements RemoteConfigService, HeaderAuthenticatedService {
  @override
  late String gateway;

  static final Cdn instance = Cdn._();

  @override
  Map<String, String>? defaultHeaders;

  Cdn._();

  factory Cdn({required String gateway}) {
    instance.gateway = gateway;
    return instance;
  }

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  @override
  void reauthenticate(String sessionToken) {
    // not needed
  }

  @override
  Future<Map> getRemoteConfig() async {
    return {};
  }

  @override
  bool get isAuthenticated => false; // not needed

  @override
  Future<Iterable<Template>> getSampleTemplates() async {
    final (json, _) = await get('/static/templates');
    return switch (json) {
      {'templates': List l} => l.map((e) => Template.fromJson(e)),
      _ => [],
    };
  }

  @override
  http.Client? get client => null;
}
