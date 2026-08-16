part of 'workout_detail.dart';

class _EmptyState extends StatelessWidget {
  final double size;

  const new({this.size = 320});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox.square(
          dimension: size,
          child: Vector(Assets.emptyWorkout, semanticsLabel: L.of(context).emptyWorkoutLabel),
        ),
      ),
    );
  }
}
