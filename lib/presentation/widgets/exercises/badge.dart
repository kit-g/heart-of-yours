part of 'exercises.dart';

/// An exercise's thumbnail, or the letter and emoji of its target while there
/// is none to show.
///
/// A null [exercise] — one the catalog no longer resolves — is the bare frame,
/// so a row about it still lines up with the rows around it.
class ExerciseBadge extends StatelessWidget {
  final Exercise? exercise;

  const new({super.key, this.exercise});

  @override
  Widget build(BuildContext context) {
    return switch (exercise) {
      Exercise exercise => SizedBox(
        height: _size,
        width: _size,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          child: switch (exercise.thumbnail?.link) {
            String url when url.startsWith('https://') => AppImage(
              url: url,
              fit: BoxFit.cover,
              semanticLabel: L.of(context).exerciseThumbnailLabel(exercise.name),
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
      ),
      null => const _EmptyBadge(),
    };
  }
}

class _EmptyBadge extends StatelessWidget {
  final Target? target;

  const new({this.target});

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
            child: switch (target) {
              Target target => Center(
                child: Text(
                  target.name.substring(0, 1).toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              null => null,
            },
          ),
          if (target case Target target)
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
