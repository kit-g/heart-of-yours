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

  /// Whether this card is the one open in a two-pane detail view.
  final bool highlighted;

  const new({
    super.key,
    required this.workout,
    this.onTap,
    this.showsMenuButton = true,
    this.onStartNewWorkout,
    this.onSaveAsTemplate,
    this.onEditWorkout,
    this.onDeleteWorkout,
    this.onTapImageIcon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    // The hero slot: total volume when the workout has one, else the best
    // set of its first exercise — labeled by the exercise itself.
    final (String heroValue, String heroLabel) = switch ((workout.total?.toInt(), prefs.weightUnit)) {
      (int total, MeasurementUnit.imperial) when total > 0 => (l.lb(total.asPounds.toInt()), l.totalVolume),
      (int total, MeasurementUnit.metric) when total > 0 => ('$total ${l.kg}', l.totalVolume),
      _ => switch (workout.firstOrNull) {
        null => ('-', l.totalVolume),
        var exercise => (
          _formatSet(
            context,
            exercise.best,
            Exercises.of(context).unitFor(exercise.exercise.name) ?? prefs.weightUnit,
            Exercises.of(context).unitFor(exercise.exercise.name) ?? prefs.distanceUnit,
          ),
          exercise.exercise.name,
        ),
      },
    };
    return Card(
      color: switch (highlighted) {
        true => colorScheme.secondaryContainer,
        false => null,
      },
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        // matches the card theme's corner
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: () => onTap?.call(workout),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      workout.name ?? '?',
                      style: textTheme.titleLarge?.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (workout case Workout(:Map images) when images.isNotEmpty)
                        FeedbackButton(
                          tooltip: l.viewProgressPhotos,
                          onPressed: () {
                            onTapImageIcon?.call(
                              [...images.values],
                              startingIndex: 0,
                              workoutId: workout.id,
                            );
                          },
                          child: const Icon(Icons.image_rounded),
                        ),
                      if (showsMenuButton)
                        PopupMenuButton<_WorkoutOption>(
                          tooltip: l.moreOptions,
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
                L.of(context).fullDate(workout.start),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: workout.duration?.formatted(context) ?? '-',
                      label: l.duration,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      value: heroValue,
                      label: heroLabel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ColoredBox(
                color: colorScheme.outlineVariant,
                child: const SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 8),
              Column(
                spacing: 4,
                children: [
                  for (final exercise in workout)
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Text(
                            '${exercise.exercise.name} ×${exercise.where((set) => set.isCompleted).length}',
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatSet(
                            context,
                            exercise.best,
                            Exercises.of(context).unitFor(exercise.exercise.name) ?? prefs.weightUnit,
                            Exercises.of(context).unitFor(exercise.exercise.name) ?? prefs.distanceUnit,
                          ),
                          // the result column reads in full ink and lines up
                          // digit-for-digit
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        final label = weightUnit == MeasurementUnit.imperial ? l.lbs : l.kg;
        return switch (set?.weight) {
          // if weight is 0 or unset: 15x
          null => '${set?.reps ?? 0}x',
          double weight when weight <= 0 => '${set?.reps ?? 0}x',
          // e.g. 11 kg x 15 reps
          double weight => '${Preferences.of(context).weight(weight, unit: weightUnit)} $label x ${set?.reps ?? 0}',
        };
      case .cardio:
        final label = distanceUnit == MeasurementUnit.imperial ? l.milesPlural : l.km;
        return switch ((set?.distance, set?.duration)) {
          // e.g. 11 km / 10 min
          (double distance, int seconds) =>
            '${Preferences.of(context).distance(distance, unit: distanceUnit)} $label / ${seconds.formatted(context)}',
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
        return _showDeleteWorkoutDialog(context, workout);
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

  Future<void> _showDeleteWorkoutDialog(BuildContext context, Workout workout) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :deleteWorkoutTitle,
      :deleteWorkoutBody,
      :cancel,
      :deleteThis,
      :deleted,
    ) = L.of(
      context,
    );
    return showBrandedDialog(
      context,
      title: Text(
        deleteWorkoutTitle,
        textAlign: TextAlign.center,
      ),
      content: Text(
        deleteWorkoutBody,
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
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Text(cancel),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  deleteThis,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () async {
                final scaffold = ScaffoldMessenger.of(context);
                final workouts = Workouts.of(context);
                Navigator.of(context, rootNavigator: true).pop();
                await workouts.deleteWorkout(workout.id);
                onDeleteWorkout?.call(workout);
                scaffold.showSnackBar(SnackBar(content: Text(deleted)));
              },
            ),
          ],
        ),
      ],
    );
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
              backgroundColor: colorScheme.surfaceContainerHighest,
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
              backgroundColor: colorScheme.surfaceContainerHighest,
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
              child: Center(
                child: Text(
                  startWorkout,
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

/// One number worth reading at a glance, in the preset's display face, with
/// a quiet label under it.
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const new({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          value,
          style: textTheme.headlineMedium?.copyWith(fontSize: 17, color: colorScheme.tertiary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

enum _WorkoutOption {
  // share,
  edit,
  saveAsTemplate,
  repeat,
  delete,
}
