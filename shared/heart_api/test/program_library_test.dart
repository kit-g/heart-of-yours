import 'dart:convert';

import 'package:heart_api/heart_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Heart's ready-made programs (#352): one static file, read conditionally on
/// the ETag of the copy the app keeps.
void main() {
  late List<http.Request> requests;

  Cdn serving(int status, {String body = '', String? etag}) {
    requests = [];
    return Cdn(gateway: 'cdn.test')
      ..client = MockClient((request) async {
        requests.add(request);
        return switch (status) {
          304 when request.headers['If-None-Match'] == etag => http.Response('', 304, request: request),
          304 || 200 => http.Response.bytes(
            utf8.encode(body),
            200,
            headers: {'content-type': 'application/json', 'etag': ?etag},
            request: request,
          ),
          _ => http.Response('', status, request: request),
        };
      });
  }

  tearDown(() => Cdn.instance.client = null);

  test('a first read brings the file and its ETag, in UTF-8', () async {
    final cdn = serving(200, body: '{"programs": [{"name": "Первые шаги"}]}', etag: '"v1"');
    final read = await cdn.getProgramLibrary();
    expect(read, (body: '{"programs": [{"name": "Первые шаги"}]}', etag: '"v1"'));
    expect(requests.single.url.path, '/static/programs');
    expect(requests.single.headers, isNot(contains('If-None-Match')));
  });

  test('the copy held is still current: nothing comes back', () async {
    final cdn = serving(304, body: '{}', etag: '"v1"');
    expect(await cdn.getProgramLibrary(etag: '"v1"'), isNull);
    expect(requests.single.headers['If-None-Match'], '"v1"');
  });

  test('a file not uploaded yet is a failed read', () async {
    final cdn = serving(403);
    await expectLater(cdn.getProgramLibrary(), throwsA(isA<NetworkException>()));
  });

  test('the go-easy map is read the same way, from its own path (#396)', () async {
    final cdn = serving(200, body: '{"version": 1}', etag: '"g1"');
    expect(await cdn.getGoEasy(), (body: '{"version": 1}', etag: '"g1"'));
    expect(requests.single.url.path, '/static/go-easy');
    // the same request for everyone: nothing of the user's goes with it
    expect(requests.single.url.query, isEmpty);
    expect(requests.single.body, isEmpty);
  });
}
