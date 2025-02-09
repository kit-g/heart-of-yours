part of 'history.dart';

class HistoryItem extends StatelessWidget {
  final Workout workout;
  final void Function(Workout)? onTap;
  final bool showsMenuButton;

  const HistoryItem({
    super.key,
    required this.workout,
    this.onTap,
    this.showsMenuButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: _shape,
      child: InkWell(
        customBorder: _shape,
        onTap: () => onTap?.call(workout),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    workout.name ?? '?',
                    style: textTheme.titleMedium,
                  ),
                  if (showsMenuButton)
                    PopupMenuButton<_WorkoutOption>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity(vertical: -3, horizontal: -3),
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (option) => _onTapOption(context, option, workout),
                      itemBuilder: (context) {
                        return _WorkoutOption.values.map(
                          (option) {
                            final (:copy, :style, :icon) = _item(context, option);
                            return PopupMenuItem<_WorkoutOption>(
                              height: 40,
                              value: option,
                              child: Row(
                                spacing: 4,
                                children: [
                                  icon,
                                  Text(
                                    copy,
                                    style: style,
                                  ),
                                ],
                              ),
                            );
                          },
                        ).toList();
                      },
                    )
                  else
                    const SizedBox.shrink()
                ],
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
                          _formatSet(context, exercise.best),
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

  static String _formatSet(BuildContext context, ExerciseSet? set) {
    final l = L.of(context);
    switch (set?.category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.machine:
      case Category.dumbbell:
      case Category.barbell:
        return '${l.lb(set?.weight?.toInt() ?? 0)} x ${set?.reps ?? 0}';
      case Category.cardio:
        return switch ((set?.distance, set?.duration)) {
          (double distance, int seconds) when distance % 1 == 0 =>
            '${l.miles(distance.toInt())} / ${seconds.formatted(context)}',
          (double distance, int seconds) =>
            '${distance.toStringAsFixed(1)} ${l.milesPlural} / ${seconds.formatted(context)}',
          _ => '',
        };
      case Category.repsOnly:
        return switch (set?.reps) {
          int reps => '${reps}x',
          _ => '',
        };
      case Category.duration:
        return switch (set?.duration) {
          int seconds => Duration(seconds: seconds).formatted(context),
          _ => '',
        };
      case null:
        return '';
    }
  }

  Future<void> _onTapOption(BuildContext context, _WorkoutOption option, Workout workout) async {
    switch (option) {
      case _WorkoutOption.delete:
        return Workouts.of(context).deleteWorkout(workout.id);
    }
  }

  _WorkoutOptionBundle _item(BuildContext context, _WorkoutOption option) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return switch (option) {
      // _WorkoutOption.edit => (
      //     copy: L.of(context).edit,
      //     style: textTheme.titleSmall,
      //     icon: const Icon(Icons.edit_rounded, size: 16),
      //   ),
      // _WorkoutOption.share => (
      //     copy: L.of(context).share,
      //     style: textTheme.titleSmall,
      //     icon: const Icon(Icons.share, size: 16),
      //   ),
      // _WorkoutOption.saveAsTemplate => (
      //     copy: L.of(context).saveAsTemplate,
      //     style: textTheme.titleSmall,
      //     icon: const Icon(Icons.add_rounded, size: 16),
      //   ),
      _WorkoutOption.delete => (
          copy: L.of(context).delete,
          style: textTheme.titleSmall?.copyWith(color: colorScheme.error),
          icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
        ),
    };
  }
}

typedef _WorkoutOptionBundle = ({String copy, TextStyle? style, Widget icon});

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

enum _WorkoutOption {
  // edit,
  // share,
  // saveAsTemplate,
  delete;
}
