import 'package:flutter/widgets.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart_state/heart_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Owns the screen wake lock for the whole app, independent of the route or
/// where a workout starts/ends (including the watch and a launch resume).
class KeepAwakePresenter extends StatefulWidget {
  final Widget child;

  /// The platform boundary: the real plugin, or a fake where there is no
  /// platform to reach (unit tests).
  final Future<void> Function({required bool enable}) toggle;

  const new({super.key, required this.child, this.toggle = WakelockPlus.toggle});

  @override
  State<KeepAwakePresenter> createState() => _KeepAwakePresenterState();
}

class _KeepAwakePresenterState extends State<KeepAwakePresenter> with WidgetsBindingObserver {
  Workouts? _workouts;
  Preferences? _preferences;
  bool _foreground = false;

  /// What was last asked of the platform; null until the first call, which
  /// always goes out: a lock left by a previous isolate (a hot restart keeps
  /// the native window) must not be mistaken for "already off".
  bool? _requested;
  Future<void> _pending = Future.value();

  /// Whether the lock is held, for [KeepAwake] to show.
  final _awake = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _foreground = _visible(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = _visible(state);
    // The OS may drop the lock while away; resume must reach the platform
    // even when our last requested state was already on.
    _sync(reassert: state == .resumed);
  }

  /// Inactive is still on screen: an Android split-screen window that lost
  /// focus, or the notification shade / Control Center pulled over the app.
  static bool _visible(AppLifecycleState? state) {
    return switch (state) {
      .resumed || .inactive => true,
      _ => false,
    };
  }

  /// A finished workout stays active until its server save returns; the
  /// screen may sleep as soon as it is finished.
  bool get _training {
    return switch (_workouts) {
      Workouts(hasActiveWorkout: true, :final activeWorkout) => !(activeWorkout?.isCompleted ?? false),
      _ => false,
    };
  }

  void _sync({bool reassert = false}) {
    final enable = _foreground && (_preferences?.isOn(.keepAwake) ?? false) && _training;
    if (enable == _requested && !(enable && reassert)) return;
    _awake.value = enable;
    _toggle(enable);
  }

  void _toggle(bool enable) {
    _requested = enable;
    final toggle = widget.toggle;
    // Serialize platform calls: switching off or backgrounding while an
    // enable is in flight must leave the final native state off.
    _pending = _pending.then((_) => toggle(enable: enable)).catchError((Object error, StackTrace stack) {
      reportToSentry(error, stacktrace: stack);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workouts?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    if (_requested == true) _toggle(false);
    _awake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeepAwake._(notifier: _awake, child: widget.child);
}

/// Whether [KeepAwakePresenter] is holding the screen awake right now: the
/// feature is on, a workout is under way and the app is on screen.
class KeepAwake extends InheritedNotifier<ValueNotifier<bool>> {
  const new _({required super.notifier, required super.child});

  /// False outside a presenter, so a screen pumped on its own shows nothing.
  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<KeepAwake>()?.notifier?.value ?? false;
  }
}
