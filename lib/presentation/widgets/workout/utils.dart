part of 'active_workout.dart';

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

void _selectAllText(TextEditingController controller) {
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.value.text.length,
  );
}

enum _ExerciseOption {
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

class NDigitFloatingPointFormatter extends TextInputFormatter {
  final int n;

  const NDigitFloatingPointFormatter({this.n = 5});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // ensure only digits and at most one decimal point are present
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue; // Reject invalid input
    }

    // if only a decimal point is entered, reject it (prevents just ".")
    if (text == '.') return oldValue;

    if (text.endsWith('.') && text.length >= n) return oldValue;
    // split into integer and decimal parts
    final parts = text.split('.');

    // count total digits (excluding the decimal point)
    final totalDigits = parts.fold<int>(0, (sum, part) => sum + part.length);

    // enforce max digits (excluding the decimal point)
    if (totalDigits > n) {
      return oldValue;
    }

    return newValue;
  }
}

class TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // remove any existing formatting
    final rawText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');

    // allow only digits and reject input longer than 5 digits
    if (!RegExp(r'^[1-9]\d{0,4}$').hasMatch(rawText)) return oldValue;

    // format the number into time
    final formattedTime = switch (rawText.length) {
      1 => '00:${rawText.padLeft(2, '0')}',
      2 => '00:$rawText',
      3 => '${rawText[0]}:${rawText.substring(1).padLeft(2, '0')}',
      4 => '${rawText.substring(0, 2)}:${rawText.substring(2).padLeft(2, '0')}',
      5 => '${rawText[0]}:${rawText.substring(1, 3)}:${rawText.substring(3).padLeft(2, '0')}',
      _ => '',
    };

    // Return the formatted time with the correct cursor position
    return TextEditingValue(
      text: formattedTime,
      selection: TextSelection.collapsed(offset: formattedTime.length),
    );
  }
}
