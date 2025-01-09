part of 'active_workout.dart';

const _fixedColumnWidth = 32.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

final _inputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?')),
  LengthLimitingTextInputFormatter(5), // todo change to five digits, e.g. 123.45
  FilteringTextInputFormatter.singleLineFormatter,
];

void _selectAllText(TextEditingController controller) {
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.value.text.length,
  );
}

enum _ExerciseOption {
  addNote,
  replace,
  weightUnit,
  autoRestTimer,
  remove;
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
  ) = L.of(context);

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
    return _showDialog(
      context,
      title: Text(finishWorkoutTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.check_circle_outline_rounded,
        color: colorScheme.onPrimaryContainer,
      ),
      content: Text(
        finishWorkoutBody,
        textAlign: TextAlign.center,
      ),
      actions: actions,
    );
  }

  if (isStarted) {
    return _showDialog(
      context,
      title: Text(finishWorkoutWarningTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      content: Text(
        finishWorkoutWarningBody,
        textAlign: TextAlign.center,
      ),
      actions: actions,
    );
  }

  return showCancelWorkoutDialog(context, workouts, onFinish: onFinish);
}

Future<void> showCancelWorkoutDialog(BuildContext context, Workouts workouts, {VoidCallback? onFinish}) {
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final L(
    :cancelWorkoutBody,
    :cancelWorkoutTitle,
    :cancelWorkout,
    :resumeWorkout,
  ) = L.of(context);
  return _showDialog(
    context,
    title: Text(cancelWorkoutTitle),
    titleTextStyle: textTheme.titleMedium,
    content: Text(
      cancelWorkoutBody,
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
              Workouts.of(context).cancelActiveWorkout();
              onFinish?.call();
            },
          ),
        ],
      ),
    ],
  );
}

Future<void> _showDialog(
  BuildContext context, {
  required Widget title,
  required Widget content,
  Widget? icon,
  TextStyle? titleTextStyle,
  TextStyle? contentTextStyle,
  List<Widget>? actions,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        contentPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        icon: icon,
        title: title,
        titleTextStyle: titleTextStyle,
        content: content,
        contentTextStyle: contentTextStyle,
        actions: actions,
      );
    },
  );
}

Future<void> _finishWorkout(BuildContext context, Workouts workouts) {
  context.goToWorkoutDone(workouts.activeWorkout?.id);
  return workouts.finishWorkout();
}
