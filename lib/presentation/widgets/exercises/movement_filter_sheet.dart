part of 'exercises.dart';

/// Filters the library by what a movement *is* — its pattern and load
/// attributes — rather than by equipment or body part.
///
/// Toggles apply immediately instead of behind an Apply button: the sheet only
/// covers part of the screen, so the list updates underneath and the effect of
/// a chip is visible while deciding on the next one.
Future<void> showMovementFilterSheet(BuildContext context, Exercises exercises) {
  return showModalBottomSheet<void>(
    context: context,
    // the root navigator, so the sheet and its scrim cover the bottom nav bar.
    // Inside the shell's navigator they stop at the body, leaving the tab bar
    // lit and tappable over a modal, and clipping the last row of chips.
    useRootNavigator: true,
    isScrollControlled: true,
    // the draggable child paints its own surface and rounds its own corners
    backgroundColor: Colors.transparent,
    builder: (context) {
      // a draggable sheet rather than the plain modal: it hands the drag to the
      // scroll view, so a downward swipe moves the sheet with the finger
      // instead of overscrolling and bouncing back
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        minChildSize: .3,
        maxChildSize: .9,
        snap: true,
        snapSizes: const [.55],
        builder: (context, controller) {
          return _MovementFilterSheet(
            exercises: exercises,
            controller: controller,
          );
        },
      );
    },
  );
}

class _MovementFilterSheet extends StatelessWidget with HasHaptic<_MovementFilterSheet> {
  /// Passed in rather than read from the context: the sheet is built by a route
  /// of its own, which does not necessarily sit under the same providers.
  final Exercises exercises;

  /// Owned by [DraggableScrollableSheet] — the scroll view has to use it, or
  /// dragging the content resizes nothing.
  final ScrollController controller;

  const new({required this.exercises, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = L.of(context);
    final L(
      :movement,
      :pattern,
      :patternHelp,
      :skillAtMost,
      :skillAtMostHelp,
      :stability,
      :stabilityHelp,
      :clearFilters,
    ) = l10n;
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return ListenableBuilder(
      listenable: exercises,
      builder: (context, _) {
        final active = exercises.movementFilters.toSet();

        void toggle(MovementFilter filter) {
          buzz();
          switch (active.contains(filter)) {
            case true:
              exercises.removeFilter(filter);
            case false:
              exercises.addFilter(filter);
          }
        }

        Widget section(String title, String help, List<MovementFilter> options) {
          return Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Row(
                spacing: 4,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  // tap rather than the default long press: nothing else here
                  // responds to a long press, so nobody would find it
                  Tooltip(
                    message: help,
                    triggerMode: .tap,
                    showDuration: const Duration(seconds: 8),
                    margin: const .symmetric(horizontal: 24),
                    // above the header, not below it — below covers the very
                    // chips the text is explaining
                    preferBelow: false,
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...options.map(
                    (option) => FilterChip(
                      label: Text(option.label(l10n), style: textTheme.bodyMedium),
                      visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
                      // the sheet sits on the lowest surface, so the chips take
                      // a raised one — the defaults are a step apart that is
                      // invisible in both brightnesses
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      selected: active.contains(option),
                      onSelected: (_) => toggle(option),
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: const .vertical(top: .circular(20)),
          ),
          child: SafeArea(
            top: false,
            // the handle lives inside the scroll view: the sheet resizes from
            // drags on the scrollable, so anything above it would be dead space
            child: SingleChildScrollView(
              controller: controller,
              padding: const .fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 20,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: .4),
                        borderRadius: .circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(movement, style: textTheme.titleMedium),
                      switch (active.isEmpty) {
                        true => const SizedBox.shrink(),
                        false => TextButton(
                          onPressed: () {
                            buzz();
                            for (final filter in active) {
                              exercises.removeFilter(filter);
                            }
                          },
                          child: Padding(
                            padding: const .symmetric(vertical: 4.0, horizontal: 8),
                            child: Text(clearFilters),
                          ),
                        ),
                      },
                    ],
                  ),
                  // the short, closed dimensions come first: they are three and
                  // two chips, and would be lost under a wall of patterns
                  section(stability, stabilityHelp, Stability.values.map(StabilityFilter.new).toList()),
                  // `high` is every exercise there is, so offering it would be a
                  // chip that looks active and filters nothing
                  section(
                    skillAtMost,
                    skillAtMostHelp,
                    SkillLevel.values.where((each) => each != .high).map(SkillCeiling.new).toList(),
                  ),
                  // the vocabulary is whatever the library actually uses, so a
                  // pattern added by content shows up without an app release
                  section(pattern, patternHelp, exercises.patterns.map(PatternFilter.new).toList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
