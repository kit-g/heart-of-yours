/// What the route tests share: a mocked HTTP client, and answers stubbed on it
/// for one request each.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

export '../mocks.mocks.dart';

/// Has [client] answer [method] [path] (with [query]) with [statusCode] and
/// [body], as the API at [gateway] would.
void respond({
  required http.Client client,
  required String method,
  required String path,
  required int statusCode,
  required Map<String, dynamic> body,
  Map<String, String>? headers,
  String gateway = 'api.example.com',
  Map<String, dynamic>? query,
}) {
  final uri = Uri.https(gateway, path, query?.map((k, v) => MapEntry(k, v.toString())));
  final request = http.Request(method, uri);
  final response = StubResponse(jsonEncode(body), statusCode, request: request, headers: headers ?? const {});

  return switch (method.toUpperCase()) {
    'GET' => when(client.get(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    'POST' => when(
      client.post(uri, headers: anyNamed('headers'), body: anyNamed('body')),
    ).thenAnswer((_) async => response),
    'PUT' => when(
      client.put(uri, headers: anyNamed('headers'), body: anyNamed('body')),
    ).thenAnswer((_) async => response),
    'PATCH' => when(
      client.patch(uri, headers: anyNamed('headers'), body: anyNamed('body')),
    ).thenAnswer((_) async => response),
    'DELETE' => when(client.delete(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    'HEAD' => when(client.head(uri, headers: anyNamed('headers'))).thenAnswer((_) async => response),
    _ => throw UnsupportedError('Unsupported HTTP method: $method'),
  };
}

/// A response with the request it answers, as the client hands it back.
class StubResponse(
  super.body,
  super.statusCode, {
  required super.request,
  super.headers,
}) extends http.Response;
