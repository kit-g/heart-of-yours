part of 'exercises.dart';

class _About extends StatelessWidget {
  final Exercise exercise;

  const _About({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (exercise.asset case Asset asset)
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            child: AppImage(url: asset.link),
          ),
      ],
    );
  }
}
