part of 'workout_detail.dart';

/// The set stopwatch (#171), shaped like the rest countdown: a count you can
/// read from the floor mid-plank, and the three things a hold needs — Cancel,
/// which writes nothing; Pause and Resume; and Done, the only way it logs.
///
/// When the set already held a time, Log 0:45 drops the count and ticks the
/// set with that time instead: ▶ starts the clock at once, and this is the
/// way back to just marking the set done.
///
/// Dismissing it keeps the clock going: the row counts on, and its ■ brings
/// this back.
Future<void> _showSetStopwatch(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String setId,
  required int? target,
  required VoidCallback onDone,
  required VoidCallback onLog,
}) {
  return showAdaptiveDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
        child: _SetStopwatch(
          title: title,
          subtitle: subtitle,
          setId: setId,
          target: target,
          onDone: onDone,
          onLog: onLog,
        ),
      );
    },
  );
}

class _SetStopwatch extends StatelessWidget {
  /// The exercise, on a line of its own.
  final String title;

  /// Which of its sets: "Set 2".
  final String subtitle;
  final String setId;
  final int? target;
  final VoidCallback onDone;

  /// Ticks the set with the time it held before the clock started.
  final VoidCallback onLog;

  const new({
    required this.title,
    required this.subtitle,
    required this.setId,
    required this.target,
    required this.onDone,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    final stopwatch = Workouts.of(context).stopwatch;

    return ListenableBuilder(
      listenable: stopwatch,
      builder: (context, _) {
        if (stopwatch.setId != setId) {
          // gone under the dialog — its set removed, the workout finished
          return const SizedBox.shrink();
        }
        final paused = stopwatch.isPaused;
        return Padding(
          padding: const .fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: .min,
            spacing: 24,
            children: [
              Stack(
                alignment: .center,
                children: [
                  // out toward the corner, away from the title and the count
                  Align(
                    alignment: .centerLeft,
                    child: Transform.translate(
                      offset: const Offset(-8, 0),
                      child: IconButton(
                        tooltip: l.close,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ),
                  // the button's whole 48pt on either side, so its ink never
                  // reaches the name
                  Padding(
                    padding: const .symmetric(horizontal: 48),
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge,
                          textAlign: .center,
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: stopwatch.seconds,
                builder: (_, seconds, _) {
                  return Semantics(
                    liveRegion: true,
                    label: switch (paused) {
                      true => '${seconds.toDuration()}, ${l.stopwatchPaused}',
                      false => seconds.toDuration(),
                    },
                    excludeSemantics: true,
                    child: Column(
                      spacing: 12,
                      children: [
                        Text(
                          seconds.toDuration(),
                          style: textTheme.displayMedium?.copyWith(
                            fontFeatures: const [.tabularFigures()],
                            color: switch (paused) {
                              true => colorScheme.onSurfaceVariant,
                              false => colorScheme.primary,
                            },
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: _StopwatchLine(seconds: seconds, target: target, paused: paused, thickness: 4),
                        ),
                        // held open, so pausing does not shift the clock
                        Text(
                          switch (paused) {
                            true => l.stopwatchPaused,
                            false => '',
                          },
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: _StopwatchButton(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      onPressed: () {
                        Navigator.pop(context);
                        stopwatch.clear();
                      },
                      child: Center(child: Text(l.cancel)),
                    ),
                  ),
                  Expanded(
                    child: _StopwatchButton(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      onPressed: switch (paused) {
                        true => stopwatch.resume,
                        false => stopwatch.pause,
                      },
                      child: Center(
                        child: Text(switch (paused) {
                          true => l.stopwatchResume,
                          false => l.stopwatchPause,
                        }),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _StopwatchButton(
                      backgroundColor: colorScheme.primary,
                      onPressed: () {
                        Navigator.pop(context);
                        onDone();
                      },
                      child: Center(
                        child: Text(
                          l.stopwatchDone,
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // the time the set held, one tap away: started by habit, or
              // not worth timing after all
              if (target case int held when held > 0)
                _StopwatchButton(
                  backgroundColor: Colors.transparent,
                  onPressed: () {
                    Navigator.pop(context);
                    stopwatch.clear();
                    onLog();
                  },
                  child: Center(
                    child: Text(
                      l.stopwatchLogHeld(held.toDuration()),
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A stopwatch button: wide, and tall enough to hit from the floor
/// mid-plank (48pt).
class _StopwatchButton extends StatelessWidget {
  final Color backgroundColor;
  final VoidCallback onPressed;
  final Widget child;

  const new({required this.backgroundColor, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: PrimaryButton.wide(backgroundColor: backgroundColor, onPressed: onPressed, child: child),
    );
  }
}

/// How far a timed set has come: toward its [target] — the time the set
/// already held, copied or typed — then full in another tone once past it;
/// with no target, a sweep that fills once a minute. Dimmed while paused.
class _StopwatchLine extends StatelessWidget {
  final int seconds;
  final int? target;
  final bool paused;
  final double thickness;

  const new({required this.seconds, required this.target, required this.paused, this.thickness = 2});

  @override
  Widget build(BuildContext context) {
    final ColorScheme(:primary, :tertiary, :surfaceContainerHighest) = Theme.of(context).colorScheme;
    final (fraction, color) = switch (target) {
      int target when target > 0 && seconds >= target => (1.0, tertiary),
      int target when target > 0 => (seconds / target, primary),
      _ => ((seconds % 60) / 60, primary),
    };

    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: switch (paused) {
          true => .4,
          false => 1,
        },
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: .all(.circular(thickness)),
          child: SizedBox(
            height: thickness,
            child: Stack(
              fit: .expand,
              children: [
                ColoredBox(color: surfaceContainerHighest),
                FractionallySizedBox(
                  alignment: .centerLeft,
                  widthFactor: fraction.clamp(0, 1),
                  child: ColoredBox(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
