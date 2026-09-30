import 'dart:async';

import 'package:heart/core/env/watch.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/presentation/navigation/ongoing_workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the watch app showing the active workout (#182).
///
/// Opt-in, and the ask is the watch itself (`docs/opt-in.md`): opening Heart on
/// the watch for the first time is the yes. Until then [Feature.watchApp] is
/// unasked and nothing is sent — a watch app that Automatic App Install
/// put there on its own hears nothing from the phone. Switched off, the watch
/// is told once, so it can say so instead of showing a stale workout.
///
/// Like the lock screen it speaks only when what the watch shows *changes*;
/// the rest countdown ticks on the watch.
class WatchPresenter extends StatefulWidget {
  final Widget child;

  /// Null turns this into a pass-through (Android, web, tests).
  final WatchLink? link;

  const new({super.key, required this.child, required this.link});

  @override
  State<WatchPresenter> createState() => _WatchPresenterState();
}

class _WatchPresenterState extends State<WatchPresenter> {
  Workouts? _workouts;
  Alarms? _alarms;
  StreamSubscription<WatchEvent>? _events;

  /// What the watch was last sent, as far as this process knows.
  WatchState? _sent;

  @override
  void initState() {
    super.initState();
    if (widget.link case WatchLink link) {
      _events = link.events.listen(_onEvent);
      // opened while the phone app wasn't running: the yes still counts
      link.takeOpened().then((opened) {
        if (opened) _onEvent(WatchEvent.opened);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_sync);
      _workouts = workouts..addListener(_sync);
    }
    final alarms = Alarms.of(context);
    if (!identical(alarms, _alarms)) {
      _alarms?.removeListener(_sync);
      _alarms = alarms..addListener(_sync);
    }
    // registered here so a language, theme or unit change re-sends the copy
    L.of(context);
    AppTheme.watch(context);
    Preferences.watch(context);
    _sync();
  }

  @override
  void dispose() {
    _events?.cancel();
    _workouts?.removeListener(_sync);
    _alarms?.removeListener(_sync);
    super.dispose();
  }

  void _onEvent(WatchEvent event) {
    if (!mounted) return;
    switch (event) {
      case WatchEvent.opened:
        // the yes, if nothing was answered before; a no from Settings stands
        final preferences = Preferences.of(context);
        if (preferences.featureAnswer(.watchApp) == .unasked) {
          preferences.setFeature(.watchApp, on: true);
          Analytics.of(context).watchAppSwitched(on: true, fromWatch: true);
        }
        // heard live, so the note the native side keeps for a later launch is spent
        widget.link?.takeOpened();
        // a watch app launched fresh — reinstalled, or its data cleared — has
        // nothing, however current this process thinks it is
        _sent = null;
        _sync();
      case WatchEvent.changed:
        break;
    }
  }

  void _sync() {
    final link = widget.link;
    if (link == null || !mounted) return;

    final state = _state();
    if (state == null || state == _sent) return;
    _sent = state;
    link.send(state);
  }

  WatchState? _state() {
    final l = L.of(context);
    return switch (Preferences.of(context).featureAnswer(.watchApp)) {
      // never opened on the watch: nothing is said to it at all
      .unasked || .pending => null,
      .off => WatchMessage.off(l.watchAppOff),
      .on => switch ((ongoingWorkoutOf(context), _workouts?.hasResolvedActiveWorkout ?? false)) {
        (var workout?, _) => WatchWorkout(workout),
        // "no workout" only once that is known, not while it is still loading
        (null, true) => WatchMessage.idle(l.watchAppIdle),
        (null, false) => null,
      },
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
