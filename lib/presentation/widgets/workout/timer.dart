import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class WorkoutTimer extends StatefulWidget {
  final DateTime start;
  final Duration? initValue;
  final TextStyle? style;

  const WorkoutTimer({
    super.key,
    required this.start,
    this.initValue,
    this.style,
  });

  @override
  State<WorkoutTimer> createState() => _WorkoutTimerState();
}

class _WorkoutTimerState extends State<WorkoutTimer> {
  late final Timer _timer;
  final _elapsedTime = ValueNotifier<Duration>(Duration.zero);

  @override
  void initState() {
    super.initState();

    if (widget.initValue case Duration startValue) {
      _elapsedTime.value = startValue;
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _elapsedTime.value = DateTime.now().difference(widget.start);
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: _elapsedTime,
      builder: (_, elapsed, __) {
        return Text(
          _format(elapsed),
          style: widget.style,
        );
      },
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String _format(Duration duration) {
    final minutes = _pad(duration.inMinutes.remainder(60));
    final seconds = _pad(duration.inSeconds.remainder(60));
    return switch (duration.inHours) {
      > 0 => '${_pad(duration.inHours)}:$minutes:$seconds',
      _ => '$minutes:$seconds',
    };
  }
}

class WorkoutTimerFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const WorkoutTimerFloatingButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<Workouts, Workout?>(
      selector: (_, workouts) => workouts.activeWorkout,
      builder: (_, active, child) {
        if (active == null) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: onPressed,
          label: Row(
            spacing: 6,
            children: [
              const Icon(
                size: 18,
                Icons.fitness_center_rounded,
              ),
              WorkoutTimer(
                start: active.start,
                initValue: active.elapsed(),
              ),
            ],
          ),
        );
      },
    );
  }
}
