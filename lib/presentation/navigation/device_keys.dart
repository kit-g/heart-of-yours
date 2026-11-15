import 'dart:async';

import 'package:heart/presentation/navigation/pushes.dart';
import 'package:heart/presentation/navigation/router/router.dart' show HeartRouter;
import 'package:heart/presentation/widgets/compare_codes.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Runs this device's encryption keys (#555) by the push client's rule: with
/// an account and a coaching switch on ([coachingRuns]).
///
/// Off, nothing is made and nothing goes over the wire. A switch going off
/// stops it and keeps every key on the device, inert, so turning back on is
/// the same device as before. Back in front, it publishes what didn't reach
/// the server, reads what arrived and restocks single-use keys.
///
/// Another of the account's devices asking to compare a code with this one
/// (#555) opens the comparison over whatever is on screen.
class DeviceKeysPresenter extends StatefulWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  State<DeviceKeysPresenter> createState() => _DeviceKeysPresenterState();
}

class _DeviceKeysPresenterState extends State<DeviceKeysPresenter> {
  Preferences? _preferences;
  Auth? _auth;

  /// A sign-in from an anonymous session keeps the server closed until its
  /// store is replayed: keys start once it opens.
  Upsync? _upsync;
  late final AppLifecycleListener _lifecycle;

  /// The account keys run for, or null while they don't.
  String? _running;

  DeviceApproval? _approval;

  /// A comparison sheet is up: another device asking again changes what it
  /// shows, not how many there are.
  bool _comparing = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final auth = Auth.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_sync);
      _auth = auth..addListener(_sync);
    }
    final upsync = Upsync.of(context);
    if (!identical(upsync, _upsync)) {
      _upsync?.removeListener(_sync);
      _upsync = upsync..addListener(_sync);
    }
    final approval = DeviceKeys.of(context).approval;
    if (!identical(approval, _approval)) {
      _approval?.removeListener(_asked);
      _approval = approval..addListener(_asked);
    }
    _sync();
  }

  @override
  void dispose() {
    _preferences?.removeListener(_sync);
    _auth?.removeListener(_sync);
    _upsync?.removeListener(_sync);
    _approval?.removeListener(_asked);
    _lifecycle.dispose();
    super.dispose();
  }

  void _sync() {
    final (preferences, auth) = (_preferences, _auth);
    if (preferences == null || auth == null || !preferences.isInitialized) return;
    final keys = DeviceKeys.of(context);
    final userId = switch (coachingRuns(preferences, auth)) {
      true => auth.user?.id,
      false => null,
    };
    switch ((userId, _running)) {
      case (null, null):
        return;
      case (null, String()):
        _running = null;
        keys.stop();
      case (final String userId, _) when userId != _running || keys.status != .published:
        // again on every word from Auth or Upsync until the server has the
        // keys: the token, and the end of a replay, may come after the account
        _running = userId;
        unawaited(keys.start(userId));
      case (String(), _):
        return;
    }
  }

  /// Shows a comparison another device asked for. One this device started
  /// is shown by the page that started it.
  void _asked() {
    final approval = _approval;
    if (approval == null || _comparing) return;
    final asked = switch (approval.value) {
      CodeComparison(role: .responder, running: true) => true,
      _ => false,
    };
    final root = HeartRouter.maybeOf(context)?.rootContext;
    if (!asked || root == null || !root.mounted) return;
    _comparing = true;
    unawaited(showCodeComparison(root, approval).whenComplete(() => _comparing = false));
  }

  void _onResume() {
    if (_running != null) unawaited(DeviceKeys.of(context).refresh());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
