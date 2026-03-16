part of 'exercises.dart';

class _About extends StatelessWidget {
  final Exercise exercise;

  const _About({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final Exercise(:asset, :muscles, :instructions) = exercise;
    final ThemeData(:colorScheme) = Theme.of(context);

    return SingleChildScrollView(
      padding: const .symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (asset case Asset asset)
            Padding(
              padding: const .only(bottom: 16.0),
              child: Container(
                color: Colors.orange,
                child: ClipRRect(
                  borderRadius: const .all(.circular(6)),
                  child: AppImage(
                    url: asset.link,
                    fit: .cover,
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

                return Row(
                  children: [
                    Expanded(
                      child: panel(.musclesFront),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: panel(.musclesBack),
                    ),
                  ],
                );
              },
            ),
          if (instructions case String instructions when instructions.isNotEmpty)
            MarkdownBlock(
              data: instructions,
              config: switch (Theme.of(context).brightness) {
                .dark => .defaultConfig,
                .light => .defaultConfig,
              },
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
