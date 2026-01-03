part of 'exercises.dart';

class _Badge extends StatelessWidget {
  final Exercise exercise;

  const _Badge({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      width: _size,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: switch (exercise.thumbnail?.link) {
          String url when url.startsWith('https://') => AppImage(
              url: url,
              fit: BoxFit.cover,
              errorWidget: (_, _) {
                return _EmptyBadge(target: exercise.target);
              },
              progressIndicatorBuilder: (_, _, _) {
                return _EmptyBadge(target: exercise.target);
              },
            ),
          _ => _EmptyBadge(target: exercise.target),
        },
      ),
    );
  }
}

class _EmptyBadge extends StatelessWidget {
  final Target target;

  const _EmptyBadge({required this.target});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      width: _size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(width: .5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Center(
              child: Text(
                target.name.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Text(target.icon),
          ),
        ],
      ),
    );
  }
}

const _size = 40.0;
