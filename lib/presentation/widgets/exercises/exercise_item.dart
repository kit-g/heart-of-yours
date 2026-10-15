part of 'exercises.dart';

class ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final Preferences preferences;
  final void Function(Exercise, TapDownDetails?)? onExerciseSelected;
  final bool selected;

  /// Whether this row is the one currently open in a two-pane detail view.
  ///
  /// Deliberately separate from [selected]: that one is the multi-select tick
  /// used while building a workout. "I added this" and "I am looking at this"
  /// are different states and a row can be in both at once.
  final bool highlighted;

  /// Why this row cannot be picked here, when it cannot. Such a row stays in
  /// the list, greyed, and a tap shows this instead of picking it.
  final String? refusal;

  bool get enabled => refusal == null;

  const new({
    super.key,
    required this.exercise,
    required this.preferences,
    required this.selected,
    this.highlighted = false,
    this.refusal,
    this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.bodySmall;
    final marks = goEasyMarks(context, exercise);
    TapDownDetails? details;

    final row = TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      tween: ColorTween(
        end: switch (highlighted) {
          true => colorScheme.secondaryContainer,
          false => Colors.transparent,
        },
      ),
      builder: (_, color, child) => Material(color: color, child: child),
      child: InkWell(
        // a refused row leaves the tap to its tooltip
        onTapDown: switch (enabled) {
          true => (d) => details = d,
          false => null,
        },
        onTap: switch ((onExerciseSelected, enabled)) {
          (void Function(Exercise, TapDownDetails?) f, true) => () => f(exercise, details),
          _ => null,
        },
        child: Opacity(
          opacity: enabled ? 1 : .38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                ExerciseBadge(exercise: exercise),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name),
                        Row(
                          children: [
                            Text(
                              exercise.target.label(L.of(context)),
                              style: style,
                            ),
                            Text(
                              ' - ',
                              style: style,
                            ),
                            Text(
                              exercise.category.label(L.of(context)),
                              style: style,
                            ),
                            // harder on something the user goes easy on
                            // (#396): said, never refused
                            if (marks.isNotEmpty)
                              Semantics(
                                label: L.of(context).goEasyHarderOn(_names(marks)),
                                excludeSemantics: true,
                                child: Row(
                                  spacing: 4,
                                  children: [
                                    Text('  ·  ', style: style),
                                    Icon(Icons.spa_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                    Text(
                                      _names(marks),
                                      style: style?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (selected) {
                    true => const Align(
                      alignment: .centerRight,
                      child: Icon(Icons.check_circle_rounded),
                    ),
                    false => Selector<PreviousExercises, Map<String, dynamic>?>(
                      selector: (_, provider) => provider.last(exercise.id),
                      builder: (_, metric, _) {
                        return switch (metric) {
                          Map<String, dynamic> m => Align(
                            alignment: .centerRight,
                            child: PreviousSet(
                              previousValue: m,
                              prefs: preferences,
                              exercise: exercise,
                            ),
                          ),
                          null => const SizedBox.shrink(),
                        };
                      },
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return switch (refusal) {
      final String message => Tooltip(message: message, triggerMode: .tap, child: row),
      null => row,
    };
  }
}
