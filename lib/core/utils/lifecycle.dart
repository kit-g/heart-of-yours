import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Tells when the person comes back to the app, for what is read again then:
/// from another app, the lock screen, or after [_away] beside a window of
/// another app's. Not from what the system lays over the app for a moment: a
/// photo picker, a permission, Control Centre. Those make it inactive and
/// resume it too, and nothing has changed meanwhile.
class AppReturns {
  final VoidCallback onReturn;

  /// Every resume, returns among them, before [onReturn].
  final VoidCallback? onResume;

  new(this.onReturn, {this.onResume, VoidCallback? onShow, VoidCallback? onHide}) {
    _listener = AppLifecycleListener(
      onInactive: () => _inactiveAt ??= clock.now(),
      onHide: () {
        _hidden = true;
        onHide?.call();
      },
      onShow: onShow,
      onResume: _resumed,
    );
  }

  late final AppLifecycleListener _listener;

  static const _away = Duration(minutes: 1);

  DateTime? _inactiveAt;
  bool _hidden = false;

  void _resumed() {
    final returned =
        _hidden ||
        switch (_inactiveAt) {
          final DateTime at => clock.now().difference(at) >= _away,
          null => false,
        };
    _hidden = false;
    _inactiveAt = null;
    onResume?.call();
    if (returned) onReturn();
  }

  void dispose() => _listener.dispose();
}
