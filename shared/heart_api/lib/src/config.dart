import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

class ConfigApi with Requests implements RemoteConfigService, HeaderAuthenticatedService {
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
  bool get isAuthenticated => false; // not needed

  @override
  Future<Iterable<Template>> getSampleTemplates(ExerciseLookup lookForExercise) async {
    final (json, _) = await get('/templates');
    return switch (json) {
      {'workouts': Map m} => m.values.map((e) => Template.fromJson(e, lookForExercise)),
      _ => [],
    };
  }

  @override
  http.Client? get client => null;
}
