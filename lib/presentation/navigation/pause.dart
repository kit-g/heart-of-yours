import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart';

/// Pausing switched off while the workout is paused (#134), whether in
/// Settings or by an answer from another device: the clock starts again, since
/// off leaves nothing on screen to start it with. The pause is kept among the
/// workout's own, like every pause, and goes on syncing.
class PausePresenter extends StatefulWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  State<PausePresenter> createState() => _PausePresenterState();
}

class _PausePresenterState extends State<PausePresenter> {
  Workouts? _workouts;
  Preferences? _preferences;

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

  /// Resumes after the frame: this runs from [didChangeDependencies] too, and
  /// resuming notifies every listener of [Workouts], mid-build otherwise.
  void _sync() {
    if (!_mustResume) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mustResume) _workouts?.resume();
    });
  }

  bool get _mustResume {
    final workouts = _workouts;
    if (workouts == null || !workouts.isPaused) return false;
    return !(_preferences?.isOn(.pauseWorkout) ?? false);
  }

  @override
  void dispose() {
    _workouts?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
