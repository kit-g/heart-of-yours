import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/connected_apps.dart';
import 'package:heart_state/src/remote.dart';

import 'test_utils.dart';

/// The apps an account let in (#448): the list is the server's, and a
/// disconnect drops a row only once the server has.
void main() {
  late _Service service;
  late ConnectedApps apps;
  late List<Object> errors;
  late ListenerProbe probe;

  ConnectedApp app(String id, {List<String> scopes = const ['read']}) {
    return ConnectedApp(
      id: id,
      clientId: 'https://$id.example/metadata.json',
      name: 'App $id',
      scopes: scopes,
      resource: 'https://api.example.com/mcp',
      connectedAt: DateTime.utc(2026, 10, 18),
    );
  }

  setUp(() {
    service = _Service();
    errors = [];
    apps = ConnectedApps(service: service, onError: (error, {stacktrace}) => errors.add(error as Object));
    probe = ListenerProbe()..attach(apps);
  });

  test('starts with nothing, never asked', () {
    expect(apps.all, isEmpty);
    expect(apps.status, ConnectedAppsStatus.idle);
  });

  test('load reads the list with each app\'s scopes, and says so', () async {
    service.held.addAll([
      app('a', scopes: ['read', 'write:templates']),
      app('b'),
    ]);

    await apps.load();

    expect(apps.status, ConnectedAppsStatus.loaded);
    expect(apps.all.map((each) => each.id), ['a', 'b']);
    expect(apps.all.first.scopes, ['read', 'write:templates']);
    expect(probe.notifications, 2);
  });

  test('a load that fails is reported and keeps what was read before', () async {
    service.held.add(app('a'));
    await apps.load();
    service.down = true;

    await apps.load();

    expect(apps.status, ConnectedAppsStatus.failed);
    expect(apps.all.map((each) => each.id), ['a']);
    expect(errors, hasLength(1));
  });

  test('load asks nothing of the server for an anonymous session', () async {
    apps = ConnectedApps(service: service, remote: RemoteAccess(allowed: false));

    await apps.load();

    expect(service.reads, 0);
    expect(apps.status, ConnectedAppsStatus.idle);
  });

  test('disconnect drops the row once the server has revoked it', () async {
    service.held.addAll([
      app('a', scopes: ['read', 'write:templates']),
      app('b'),
    ]);
    await apps.load();

    await apps.disconnect(apps.all.first);

    expect(service.disconnected, ['a']);
    expect(apps.all.map((each) => each.id), ['b']);
  });

  test('a disconnect that fails is thrown and the row stays: the app still has its access', () async {
    service.held.add(app('a'));
    await apps.load();
    service.down = true;

    await expectLater(apps.disconnect(apps.all.single), throwsA(isA<SocketException>()));

    expect(apps.all.map((each) => each.id), ['a']);
  });

  test('one the server no longer holds is gone, and the list is read again', () async {
    service.held.addAll([app('a'), app('b')]);
    await apps.load();
    final gone = apps.all.first;
    service.held
      ..clear()
      ..add(app('c'));
    service.refusal = refusedAs({'code': 'not_found'});

    await apps.disconnect(gone);

    expect(apps.all.map((each) => each.id), ['c']);
  });

  test('a read that lands after a sign-out is the last account\'s, and stays out', () async {
    service.held.add(app('a'));
    final gate = Completer<void>();
    service.gate = gate.future;

    final read = apps.load();
    apps.onSignOut();
    gate.complete();
    await read;

    expect(apps.all, isEmpty);
    expect(apps.status, ConnectedAppsStatus.idle);
  });

  test('signing out forgets the list', () async {
    service.held.add(app('a'));
    await apps.load();

    apps.onSignOut();

    expect(apps.all, isEmpty);
    expect(apps.status, ConnectedAppsStatus.idle);
  });
}

class _Service implements ConnectedAppService {
  final held = <ConnectedApp>[];
  final disconnected = <String>[];
  var down = false;
  ServerRefusal? refusal;
  var reads = 0;
  Future<void>? gate;

  @override
  Future<Iterable<ConnectedApp>> listConnectedApps() async {
    reads++;
    await gate;
    if (down) throw const SocketException('no route to host');
    return held.toList();
  }

  @override
  Future<void> disconnectApp(String grantId) async {
    if (down) throw const SocketException('no route to host');
    if (refusal case final ServerRefusal refused) throw refused;
    disconnected.add(grantId);
    held.removeWhere((each) => each.id == grantId);
  }
}
