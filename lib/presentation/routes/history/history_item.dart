part of 'history.dart';

class HistoryItem extends StatelessWidget {
  final Workout workout;

  const HistoryItem({
    super.key,
    required this.workout,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    final l = L.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: _shape,
      child: InkWell(
        customBorder: _shape,
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workout.name ?? '?',
                style: textTheme.titleMedium,
              ),
              Text(
                _formatDate(workout.start),
              ),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 18,
                        ),
                        Text(workout.duration?.formatted(context) ?? '-')
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      spacing: 8,
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          size: 18,
                        ),
                        Text(
                          switch (workout.total?.toInt()) {
                            int total when total > 0 => l.lb(total),
                            _ => '-',
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...workout.map(
                (exercise) {
                  return Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          '${exercise.length} x ${exercise.exercise.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatSet(l, exercise.best),
                          style: textTheme.titleSmall,
                        ),
                      )
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return DateFormat('EEEE, d MMM y').format(dt);
  }

  static String _formatSet(L l, ExerciseSet? set) {
    return switch (set) {
      // TODO: Handle this case.
      CardioSet() => throw UnimplementedError(),
      WeightedSet s => '${l.lb(s.weight?.toInt() ?? 0)} x ${s.reps ?? 0}',
      // TODO: Handle this case.
      AssistedSet() => throw UnimplementedError(),
      null => ' ',
    };
  }
}

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);
