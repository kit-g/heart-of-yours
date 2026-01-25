part of 'history.dart';

class WorkoutItem extends StatelessWidget {
  final Workout workout;
  final void Function(Workout)? onTap;
  final bool showsMenuButton;
  final VoidCallback? onStartNewWorkout;
  final void Function(Workout)? onSaveAsTemplate;
  final void Function(Workout)? onEditWorkout;
  final void Function(Workout)? onDeleteWorkout;
  final Future<void> Function(Iterable<Media>, {required int startingIndex, String? workoutId})? onTapImageIcon;

  const WorkoutItem({
    super.key,
    required this.workout,
    this.onTap,
    this.showsMenuButton = true,
    this.onStartNewWorkout,
    this.onSaveAsTemplate,
    this.onEditWorkout,
    this.onDeleteWorkout,
    this.onTapImageIcon,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final prefs = Preferences.watch(context);
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
                  Row(
                    children: [
                      if (workout case Workout(
                        :var images,
                        :var localImage,
                      ) when images?.isNotEmpty ?? false || localImage != null)
                        FeedbackButton(
                          onPressed: () {
                            onTapImageIcon?.call(
                              [...?images?.values],
                              startingIndex: 0,
                              workoutId: workout.id,
                            );
                          },
                          child: const Icon(Icons.image_rounded),
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
                        ),
                    ],
                  ),
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
                        Text(workout.duration?.formatted(context) ?? '-'),
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
                          switch ((workout.total?.toInt(), prefs.weightUnit)) {
                            (int total, MeasurementUnit.imperial) when total > 0 => l.lb(total.asPounds.toInt()),
                            (int total, MeasurementUnit.metric) when total > 0 => '$total ${l.kg}',
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
                          '${exercise.where((set) => set.isCompleted).length} x ${exercise.exercise.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatSet(
                            context,
                            exercise.best,
                            prefs.weightUnit,
                            prefs.distanceUnit,
                          ),
                          style: textTheme.titleSmall,
                        ),
                      ),
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

  static String _formatSet(
    BuildContext context,
    ExerciseSet? set,
    MeasurementUnit weightUnit,
    MeasurementUnit distanceUnit,
  ) {
    final l = L.of(context);
    switch (set?.category) {
      case .weightedBodyWeight:
      case .assistedBodyWeight:
      case .machine:
      case .dumbbell:
      case .barbell:
        return switch ((set?.weight, weightUnit)) {
          // if weight is 0: 15x
          (double weight, _) when weight <= 0 => '${set?.reps ?? 0}x',
          (null, _) => '${set?.reps ?? 0}x',
          // e.g. 11 lbs x 15 reps
          (double weight, .imperial) when weight > 0 => '${l.lb(weight.asPounds.toInt())} x ${set?.reps ?? 0}',
          // e.g. 11 kg x 15 reps
          (double weight, .metric) when weight > 0 => '${rounded(weight)} ${l.kg} x ${set?.reps ?? 0}',
          (_, _) => '',
        };
      case .cardio:
        return switch ((set?.distance, set?.duration)) {
          (double distance, int seconds) => switch (distanceUnit) {
            // e.g. 11 miles / 10 min
            .imperial => '${rounded(distance.asMiles)} ${l.milesPlural} / ${seconds.formatted(context)}',
            // e.g. 11 km / 10 min
            .metric => '${rounded(distance)} ${l.km} / ${seconds.formatted(context)}',
          },
          _ => '',
        };
      case .repsOnly:
        return switch (set?.reps) {
          int reps => '${reps}x',
          _ => '',
        };
      case .duration:
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
        return Workouts.of(context).deleteWorkout(workout.id).then((_) => onDeleteWorkout?.call(workout));
      case _WorkoutOption.repeat:
        final workouts = Workouts.of(context);

        if (workouts.activeWorkout == null) {
          return _showStartNewWorkoutDialog(context, workout);
        } else {
          return _showCancelActiveWorkoutDialog(context, workout);
        }
      case _WorkoutOption.saveAsTemplate:
        return onSaveAsTemplate?.call(workout);
      case _WorkoutOption.edit:
        return onEditWorkout?.call(workout);
    }
  }

  _WorkoutOptionBundle _item(BuildContext context, _WorkoutOption option) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return switch (option) {
      .edit => (
        copy: L.of(context).edit,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.edit_rounded, size: 16),
      ),
      .saveAsTemplate => (
        copy: L.of(context).saveAsTemplate,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.add_rounded, size: 16),
      ),
      .repeat => (
        copy: L.of(context).repeat,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.fitness_center_rounded, size: 16),
      ),
      .delete => (
        copy: L.of(context).delete,
        style: textTheme.titleSmall?.copyWith(color: colorScheme.error),
        icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
      ),
      // _WorkoutOption.share => (
      //     copy: L.of(context).share,
      //     style: textTheme.titleSmall,
      //     icon: const Icon(Icons.share, size: 16),
      //   ),
    };
  }

  Future<void> _showCancelActiveWorkoutDialog(BuildContext context, Workout workout) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :cancelCurrentWorkoutTitle,
      :cancelCurrentWorkoutBody,
      :keepCurrentAccount,
      :cancelAndStartNewWorkout,
    ) = L.of(
      context,
    );
    return showBrandedDialog(
      context,
      title: Text(
        cancelCurrentWorkoutTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        cancelCurrentWorkoutBody,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(
                  keepCurrentAccount,
                  textAlign: TextAlign.center,
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  cancelAndStartNewWorkout,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ),
              onPressed: () {
                final workouts = Workouts.of(context);

                workouts.cancelActiveWorkout().then(
                  (_) {
                    onStartNewWorkout?.call();
                    return workouts.startWorkout(template: workout.copy());
                  },
                );
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showStartNewWorkoutDialog(BuildContext context, Workout workout) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :startNewWorkoutFromTemplate,
      :cancelCurrentWorkoutBody,
      :cancel,
      :startWorkout,
    ) = L.of(
      context,
    );
    return showBrandedDialog(
      context,
      title: Text(
        startNewWorkoutFromTemplate,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.check_circle_outline_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(
                  cancel,
                  textAlign: TextAlign.center,
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.primaryContainer,
              child: Center(
                child: Text(
                  startWorkout,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer),
                  textAlign: TextAlign.center,
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                onStartNewWorkout?.call();
                Workouts.of(context).startWorkout(template: workout.copy());
              },
            ),
          ],
        ),
      ],
    );
  }
}

typedef _WorkoutOptionBundle = ({String copy, TextStyle? style, Widget icon});

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

enum _WorkoutOption {
  // share,
  edit,
  saveAsTemplate,
  repeat,
  delete,
}

String rounded(num? v) {
  if (v == null) return '';
  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}
