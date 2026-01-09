part of 'exercises.dart';

class _About extends StatelessWidget {
  final Exercise exercise;

  const _About({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (exercise.asset case Asset asset)
            Padding(
              padding: const .only(bottom: 16.0),
              child: ClipRRect(
                borderRadius: const .all(.circular(6)),
                child: AppImage(url: asset.link),
              ),
            ),
          if (exercise.instructions case String instructions when instructions.isNotEmpty)
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
}
