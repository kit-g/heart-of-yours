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
  /// store is replayed: keys start once it opens. Only its opening is
  /// listened to: it also speaks at a sign-out, while the account is still
  /// there to start keys for (#734).
  Upsync? _upsync;
  late final AppLifecycleListener _lifecycle;

  /// The account keys run for, or null while they don't.
  String? _running;

  DeviceApproval? _approval;

  /// The last comparison asked for that a sheet showed: closed while it
  /// finishes, it isn't shown again.
  String? _shown;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _onResume,
      onShow: () => _approval?.inFront = true,
      onHide: () => _approval?.inFront = false,
    );
    // a sheet closing may leave a request waiting that came while it was up
    comparisonSheet.addListener(_asked);
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
      _upsync?.opened.removeListener(_sync);
      _upsync = upsync;
      upsync.opened.addListener(_sync);
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
    _upsync?.opened.removeListener(_sync);
    _approval?.removeListener(_asked);
    comparisonSheet.removeListener(_asked);
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

  /// Shows a comparison another device asked for, once no sheet is up: one
  /// asked for while another sheet shows waits for it to close. One this
  /// device started is shown by the page that started it.
  ///
  /// A turn later, never inside a route closing.
  void _asked() => scheduleMicrotask(_show);

  void _show() {
    final approval = _approval;
    if (!mounted || approval == null || comparisonSheet.value != null) return;
    final asked = switch (approval.value) {
      CodeComparison(role: .responder, running: true, :final id) => id,
      _ => null,
    };
    final root = HeartRouter.maybeOf(context)?.rootContext;
    if (asked == null || asked == _shown || root == null || !root.mounted) return;
    _shown = asked;
    unawaited(showCodeComparison(root, approval, asked));
  }

  void _onResume() {
    if (_running != null) unawaited(DeviceKeys.of(context).refresh());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
