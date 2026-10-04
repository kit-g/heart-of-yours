part of 'workout_detail.dart';

/// The set stopwatch (#171), shaped like the rest countdown: a count you can
/// read from the floor mid-plank, and the three things a hold needs — Cancel,
/// which writes nothing; Pause and Resume; and Done, the only way it logs.
///
/// Dismissing it keeps the clock going: the row counts on, and its ■ brings
/// this back.
Future<void> _showSetStopwatch(
  BuildContext context, {
  required String title,
  required String setId,
  required int? target,
  required VoidCallback onDone,
}) {
  return showAdaptiveDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(borderRadius: .all(.circular(12))),
        child: _SetStopwatch(title: title, setId: setId, target: target, onDone: onDone),
      );
    },
  );
}

class _SetStopwatch extends StatelessWidget {
  final String title;
  final String setId;
  final int? target;
  final VoidCallback onDone;

  const new({required this.title, required this.setId, required this.target, required this.onDone});

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
                  Align(
                    alignment: .centerLeft,
                    child: IconButton(
                      tooltip: l.close,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                  Padding(
                    padding: const .symmetric(horizontal: 40),
                    child: Text(
                      title,
                      style: textTheme.titleLarge,
                      maxLines: 1,
                      overflow: .ellipsis,
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
