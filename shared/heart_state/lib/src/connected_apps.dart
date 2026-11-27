import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

/// What the server does with the apps an account approved through OAuth, an
/// assistant such as Claude or ChatGPT (#448): list them, disconnect one.
///
/// Defined here for the reason `ApiTokenService` is: the app's view of two
/// routes, which it adapts `Api` onto.
abstract interface class ConnectedAppService {
  /// Every app the account holds a grant for, with the scopes it was given.
  Future<Iterable<ConnectedApp>> listConnectedApps();

  /// Revokes every token [grantId]'s app holds, whatever their scopes.
  Future<void> disconnectApp(String grantId);
}

/// Where the list stands with the server.
enum ConnectedAppsStatus {
  /// Never asked.
  idle,

  loading,

  /// The last read landed; the list is the server's.
  loaded,

  /// The last read did not land, and nothing newer has been read since.
  failed,
}

/// The apps the account let in, as the server lists them.
///
/// Server-only, like `ApiTokens` and for its reason: a grant lives on the
/// server, most are made in a browser this device never saw, and a copy here
/// would only be one more place the list could be stale.
class ConnectedApps with ChangeNotifier implements SignOutStateSentry {
  final ConnectedAppService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  final _apps = <ConnectedApp>[];

  ConnectedAppsStatus _status = .idle;

  /// Counts the sessions this has seen end: an answer that left under one
  /// and landed under the next is the last account's, and stays out (#671).
  int _session = 0;

  new({
    required this._service,
    RemoteAccess? remote,
    this.onError,
  }) : _remote = remote ?? RemoteAccess();

  static ConnectedApps of(BuildContext context) => Provider.of<ConnectedApps>(context, listen: false);

  static ConnectedApps watch(BuildContext context) => Provider.of<ConnectedApps>(context, listen: true);

  ConnectedAppsStatus get status => _status;

  /// As the server orders them.
  List<ConnectedApp> get all => UnmodifiableListView(_apps);

  @override
  void onSignOut() {
    _session++;
    _apps.clear();
    _status = .idle;
    notifyListeners();
  }

  /// Reads the list. Nothing happens while the remote leg is closed: an
  /// anonymous session has no account for an app to be connected to.
  Future<void> load() async {
    if (!_remote.allowed) return;
    final session = _session;
    _status = .loading;
    notifyListeners();
    try {
      final apps = (await _service.listConnectedApps()).toList();
      if (session != _session) return;
      _apps
        ..clear()
        ..addAll(apps);
      _status = .loaded;
    } catch (error, stacktrace) {
      if (session != _session) return;
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// Disconnects [app] and drops its row once the server has. One the server
  /// no longer holds is gone either way, and the list is read again so
  /// whatever else changed lands too. Any other failure is thrown: the row
  /// stays, because the app still has its access.
  Future<void> disconnect(ConnectedApp app) async {
    final session = _session;
    try {
      await _service.disconnectApp(app.id);
    } catch (error) {
      if (!_remote.isGone(error)) rethrow;
      await load();
      return;
    }
    if (session != _session) return;
    _apps.remove(app);
    notifyListeners();
  }
}
