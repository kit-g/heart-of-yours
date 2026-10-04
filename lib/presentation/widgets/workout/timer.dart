import 'dart:async';

import 'package:heart/core/utils/ongoing_workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The active workout's elapsed time, counted from [start] — the clock start
/// `Workouts.clockStart` gives, which the closed pauses have moved on — and
/// stopped at [pausedAt] while the workout is paused (#134).
class WorkoutTimer extends StatefulWidget {
  final DateTime start;
  final DateTime? pausedAt;
  final TextStyle? style;

  const new({
    super.key,
    required this.start,
    this.pausedAt,
    this.style,
  });

  @override
  State<WorkoutTimer> createState() => _WorkoutTimerState();
}

class _WorkoutTimerState extends State<WorkoutTimer> {
  Timer? _timer;

  /// Repaints the digits once a second; the time itself is read off the props,
  /// so a pause or a resume shows at once rather than on the next tick.
  final _tick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(WorkoutTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.pausedAt == null) != (widget.pausedAt == null)) _follow();
  }

  /// Ticks while the clock runs; a stopped one has nothing to repaint.
  void _follow() {
    _timer?.cancel();
    _timer = switch (widget.pausedAt) {
      null => Timer.periodic(const Duration(seconds: 1), (_) => _tick.value++),
      DateTime _ => null,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tick,
      builder: (_, _, _) {
        final text = Text(
          formatClock((widget.pausedAt ?? DateTime.now()).difference(widget.start)),
          style: widget.style,
        );
        return switch (widget.pausedAt) {
          DateTime _ => Semantics(label: L.of(context).workoutPaused, child: text),
          null => text,
        };
      },
    );
  }
}

class WorkoutTimerFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const new({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<Workouts, ({DateTime? start, DateTime? pausedAt})>(
      selector: (_, workouts) => (start: workouts.clockStart, pausedAt: workouts.pausedAt),
      builder: (_, clock, child) {
        final start = clock.start;
        if (start == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: onPressed,
          label: Row(
            spacing: 6,
            children: [
              Icon(
                size: 18,
                switch (clock.pausedAt) {
                  DateTime _ => Icons.pause_rounded,
                  null => Icons.fitness_center_rounded,
                },
              ),
              WorkoutTimer(start: start, pausedAt: clock.pausedAt),
            ],
          ),
        );
      },
    );
  }
}
