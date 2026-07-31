part of 'exercises.dart';

class _About extends StatelessWidget {
  final Exercise exercise;
  final void Function(ExerciseFilter)? onFilter;
  final void Function(Exercise)? onTapAlternative;

  const _About({
    required this.exercise,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  Widget build(BuildContext context) {
    final Exercise(:asset, :muscles, :instructions, :category, :target) = exercise;
    final ThemeData(:colorScheme) = Theme.of(context);

    return SingleChildScrollView(
      padding: const .symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .only(left: 16, right: 16, bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(filter: category, onFilter: onFilter),
                _FilterChip(filter: target, onFilter: onFilter),
              ],
            ),
          ),
          _Alternatives(
            exercise: exercise,
            onTapAlternative: onTapAlternative,
          ),
          if (asset case Asset asset)
            Padding(
              padding: const .only(left: 16, right: 16, bottom: 16.0),
              child: ClipRRect(
                borderRadius: const .all(.circular(6)),
                // Reserve the slot up front so the layout doesn't jump when the
                // (often animated) asset finishes loading. Use the asset's own
                // dimensions when known, otherwise a sensible 3:2 default.
                child: AspectRatio(
                  aspectRatio: switch ((asset.width, asset.height)) {
                    (int w, int h) when w > 0 && h > 0 => w / h,
                    _ => 3 / 2,
                  },
                  child: AppImage(
                    url: asset.link,
                    fit: .cover,
                    fadeInDuration: const Duration(milliseconds: 80),
                    progressIndicatorBuilder: (context, _, progress) {
                      return ColoredBox(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: .1),
                        // Draw the determinate ring only while bytes are actually
                        // arriving. cached_network_image also emits null-progress
                        // frames — one before the first chunk and every frame of the
                        // fade-in blend — where showing a ring would spin over the
                        // appearing gif. On those, render just the tint.
                        child: switch (progress.progress) {
                          double value => Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 1, value: value),
                            ),
                          ),
                          null => const SizedBox.expand(),
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          if (!muscles.isEmpty)
            Builder(
              builder: (context) {
                final primaryMuscles = _colorMapping(muscles.primary, colorScheme.onTertiaryContainer);
                final secondaryMuscles = _colorMapping(muscles.secondary, colorScheme.tertiaryContainer);
                final colors = {...primaryMuscles, ...secondaryMuscles};

                Widget panel(AtlasAsset view) {
                  return Container(
                    height: 350,
                    padding: const .symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      border: .all(color: colorScheme.inverseSurface, width: .3),
                      borderRadius: .circular(6),
                    ),
                    child: InteractiveViewer(
                      child: BodyAtlasView(
                        view: view,
                        resolver: const MuscleResolver(),
                        colorMapping: colors,
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const .symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: panel(.musclesFront),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: panel(.musclesBack),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (instructions case String instructions when instructions.isNotEmpty)
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: MarkdownBlock(
                data: instructions,
                config: switch (Theme.of(context).brightness) {
                  .dark => .defaultConfig,
                  .light => .defaultConfig,
                },
              ),
            ),
        ],
      ),
    );
  }

  /// whether a [muscle] should be coloured
  bool _shouldPaint(MuscleInfo muscle, MuscleTag? tags) {
    if (tags == null) return false;
    final inGroup = tags.groups?.contains(muscle.group.name) ?? false;
    final isMatch = tags.ids?.contains(muscle.id) ?? false;
    return inGroup || isMatch;
  }

  /// muscle-to-[color] mapping
  Map<MuscleInfo, Color> _colorMapping(MuscleTag? tags, Color color) {
    return Map.fromEntries(
      MuscleCatalog
          .all //
          .where((muscle) => _shouldPaint(muscle, tags))
          .map((muscle) => MapEntry(muscle, color)),
    );
  }
}

/// The exercise's category or target. Tapping opens the library filtered to it;
/// without [onFilter] it is a plain label.
class _FilterChip extends StatelessWidget {
  final ExerciseFilter filter;
  final void Function(ExerciseFilter)? onFilter;

  const _FilterChip({required this.filter, this.onFilter});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    final label = Text(
      switch (filter) {
        Target(:final icon, :final value) => '$icon  $value',
        _ => filter.value,
      },
      style: textTheme.bodyMedium,
    );
    const density = VisualDensity(vertical: -2, horizontal: -2);

    return switch (onFilter) {
      null => Chip(label: label, visualDensity: density),
      final onFilter => ActionChip(
        label: label,
        visualDensity: density,
        onPressed: () => onFilter(filter),
      ),
    };
  }
}

/// Exercises that train the same movement pattern, closest first.
///
/// Hidden entirely when the library has nothing to swap in — an unannotated or
/// user-created exercise, or one of the genuine singletons like the leg
/// extension machine.
class _Alternatives extends StatelessWidget {
  final Exercise exercise;
  final void Function(Exercise)? onTapAlternative;

  const _Alternatives({required this.exercise, this.onTapAlternative});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    // watched, so the section appears once the library finishes loading
    final alternatives = Exercises.watch(context).alternativesTo(exercise).toList();

    if (alternatives.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const .only(bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: Text(
              L.of(context).alsoTry,
              style: textTheme.titleSmall,
            ),
          ),
          // the gutter lives inside the viewport, so the chips scroll past the
          // screen edge instead of stopping short of it
          SingleChildScrollView(
            scrollDirection: .horizontal,
            padding: const .symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                ...alternatives.map(
                  (each) => ActionChip(
                    label: Text(each.name, style: textTheme.bodyMedium),
                    visualDensity: const VisualDensity(vertical: -2, horizontal: -2),
                    onPressed: () => onTapAlternative?.call(each),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
