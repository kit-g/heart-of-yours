part of 'workout_detail.dart';

/// A superset's members held together on the sheet (#159): a rail down the
/// gutter the rows already leave, so a group costs no width, and a caption
/// over its first member — "Superset" for two, "Circuit" for more. An
/// exercise on its own is [child] as it was.
class _GroupRail extends StatelessWidget {
  final List<WorkoutExercise> group;
  final WorkoutExercise exercise;
  final Widget child;

  const new({required this.group, required this.exercise, required this.child});

  @override
  Widget build(BuildContext context) {
    if (group.length < 2) return child;
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    final caption = switch (group.length) {
      2 => l.supersetLabel,
      _ => l.circuitLabel,
    };
    final first = group.first == exercise;
    final last = group.last == exercise;
    const radius = Radius.circular(2);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            if (first)
              Padding(
                padding: const .only(left: 12, top: 8),
                child: Text(
                  caption,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.tertiary),
                ),
              ),
            child,
          ],
        ),
        // the rail carries the group to a screen reader on every member, the
        // caption only on the first
        Positioned(
          key: WorkoutDetailKeys.groupRailFor(exercise.exercise.id),
          left: 2,
          width: 3,
          top: switch (first) {
            true => 10,
            false => 0,
          },
          bottom: switch (last) {
            true => 10,
            false => 0,
          },
          child: Semantics(
            label: caption,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                borderRadius: .vertical(
                  top: switch (first) {
                    true => radius,
                    false => .zero,
                  },
                  bottom: switch (last) {
                    true => radius,
                    false => .zero,
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scrolls [child] into view when it becomes the exercise pointed at: the
/// next of a superset's round after a tick (#159), or the one a rest
/// notification was for.
class _BroughtIntoView extends StatefulWidget {
  final bool pointed;
  final Widget child;

  const new({required this.pointed, required this.child});

  @override
  State<_BroughtIntoView> createState() => _BroughtIntoViewState();
}

class _BroughtIntoViewState extends State<_BroughtIntoView> {
  @override
  void didUpdateWidget(covariant _BroughtIntoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.pointed || oldWidget.pointed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: .05,
        duration: switch (MediaQuery.disableAnimationsOf(context)) {
          true => Duration.zero,
          false => const Duration(milliseconds: 300),
        },
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
