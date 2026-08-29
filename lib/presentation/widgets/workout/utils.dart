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
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Center(
            child: Text(notReadyToFinish),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        PrimaryButton.wide(
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
            backgroundColor: colorScheme.surfaceContainerHighest,
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

  // Read before navigating: the screen this context belongs to is on its way
  // out, and the mirror below runs long after it has gone.
  final health = Health.of(context);

  // Whether Heart may put a permission sheet in front of this user. True only
  // once they have engaged with health at all — someone who never accepted the
  // invitation should not meet a Health prompt because they finished a workout.
  // See [Health.recordWorkout].
  final mayAsk = Preferences.of(context).healthAsked(health.userId);

  // **The session this device holds, not the one the finish resolves to.**
  //
  // `finishActiveWorkout` completes with the server's copy, because the server
  // mints the id anything referring to the session afterwards must use. Its
  // embedded exercises are not the catalogue's, though: they arrive without the
  // library's health annotation, so reading the activity off them labelled
  // every swim `other` in the Health app. Caught on a simulator, with the
  // annotation sitting correctly in the local catalogue the whole time.
  //
  // This object is the one `finish()` mutates in place, so by the time the
  // future below runs it carries the same start and end — and the exercises the
  // user actually picked.
  final session = workouts.activeWorkout;

  context.goToWorkoutDone(workouts.activeWorkout?.id);
  cancelAllNotifications();

  final finishing = workouts.finishActiveWorkout();

  // Mirror the session into the device's health store — deliberately not
  // awaited. The user is already looking at the summary screen, and whether
  // HealthKit accepted a courtesy copy is not something a finished workout
  // should wait on, let alone fail on.
  //
  // Chained off the finish rather than fired beside it, so the write sees an
  // ended workout with its empty sets already dropped.
  unawaited(
    finishing.then(
      (_) async {
        if (session case Workout finished) {
          // The name is copy, and this is the layer that owns it.
          await health.recordWorkout(finished, title: finished.name, mayAsk: mayAsk);
        }
      },
    ),
  );

  return finishing;
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
