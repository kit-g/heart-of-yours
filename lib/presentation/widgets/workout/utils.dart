part of 'workout_detail.dart';

const _fixedColumnWidth = 32.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

final _floatingPointFormatters = <TextInputFormatter>[
  const NDigitFloatingPointFormatter(),
  FilteringTextInputFormatter.singleLineFormatter,
];

final _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

extension on TextEditingController {
  void selectAllText() {
    selection = TextSelection(
      baseOffset: 0,
      extentOffset: value.text.length,
    );
  }
}

enum _ExerciseOption { inspectExercise, autoRestTimer, remove }

/// Index in [items] where [dragged] would land if dropped on [hovered] — the
/// slot the drop indicator marks, and the slot the reorder actually produces.
///
/// A downwards drag lands *after* [hovered], an upwards drag *before* it, which
/// is what makes dropping onto the neighbour directly below do something: a
/// plain insert-before would put the exercise back where it already was.
/// A null [hovered] means the trailing target, i.e. append.
///
/// Returns null when there is nothing to draw or move.
int? dropIndex(List<WorkoutExercise> items, WorkoutExercise? dragged, WorkoutExercise? hovered) {
  if (dragged == null) return null;
  if (hovered == null) return items.length;

  final from = items.indexOf(dragged);
  final to = items.indexOf(hovered);

  if (from < 0 || to < 0 || from == to) return null;

  return switch (from < to) {
    true => to + 1,
    false => to,
  };
}

Future<void> showFinishWorkoutDialog(BuildContext context, Workouts workouts, {VoidCallback? onFinish}) async {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final Workouts(:activeWorkout) = workouts;
  final Workout(:isValid, :isStarted) = activeWorkout!;
  final L(
    :cancel,
    :finish,
    :finishWorkoutTitle,
    :finishWorkoutBody,
    :finishWorkoutWarningTitle,
    :finishWorkoutWarningBody,
    :readyToFinish,
    :notReadyToFinish,
  ) = L.of(
    context,
  );
  final actions = [
    Column(
      spacing: 8,
      children: [
        PrimaryButton.wide(
          backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
          child: Center(
            child: Text(notReadyToFinish),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        PrimaryButton.wide(
          backgroundColor: colorScheme.primaryContainer,
          child: Center(
            child: Text(readyToFinish),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            _finishWorkout(context, workouts);
            onFinish?.call();
          },
        ),
      ],
    ),
  ];

  if (isValid) {
    return showBrandedDialog(
      context,
      title: Text(finishWorkoutTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.check_circle_outline_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      content: Text(
        finishWorkoutBody,
        textAlign: .center,
      ),
      actions: actions,
    );
  }

  if (isStarted) {
    return showBrandedDialog(
      context,
      title: Text(finishWorkoutWarningTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      content: Text(
        finishWorkoutWarningBody,
        textAlign: .center,
      ),
      actions: actions,
    );
  }

  return showCancelWorkoutDialog(context, onFinish: onFinish);
}

Future<void> showCancelWorkoutDialog(BuildContext context, {VoidCallback? onFinish}) {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final L(
    :cancelWorkoutBody,
    :cancelWorkoutTitle,
    :cancelWorkout,
    :resumeWorkout,
  ) = L.of(
    context,
  );
  return showBrandedDialog(
    context,
    title: Text(cancelWorkoutTitle),
    titleTextStyle: textTheme.titleMedium,
    content: Text(
      cancelWorkoutBody,
      textAlign: .center,
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
              child: Text(resumeWorkout),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.errorContainer,
            child: Center(
              child: Text(
                cancelWorkout,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).maybePop();
              cancelAllNotifications();
              Workouts.of(context).cancelActiveWorkout();
              onFinish?.call();
            },
          ),
        ],
      ),
    ],
  );
}

Future<void> _finishWorkout(BuildContext context, Workouts workouts) {
  workouts.activeWorkout?.resolveName(L.of(context).defaultWorkoutName());
  context.goToWorkoutDone(workouts.activeWorkout?.id);
  cancelAllNotifications();
  return workouts.finishActiveWorkout();
}

Future<void> showDeleteImageDialog(
  BuildContext context,
  Workout workout,
  WorkoutImage image, {
  required Future<void> Function(BuildContext context) onDeleted,
}) {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final L(
    :deleteImageDialogBody,
    :deleteImageDialogTitle,
    :cancel,
    :removePhoto,
  ) = L.of(
    context,
  );
  return showBrandedDialog(
    context,
    title: Text(deleteImageDialogTitle),
    titleTextStyle: textTheme.titleMedium,
    content: Text(
      deleteImageDialogBody,
      textAlign: .center,
    ),
    icon: Icon(
      Icons.delete_forever,
      color: colorScheme.onErrorContainer,
    ),
    actions: [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
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
                removePhoto,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
            onPressed: () => onDeleted(context),
          ),
        ],
      ),
    ],
  );
}
