import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';

/// Shows a platform-adaptive date picker and returns the chosen day.
///
/// Material's `showDatePicker` is a calendar grid with its own chrome, which is
/// not what a date field looks like on iOS — the same reason [showDurationPicker]
/// forks. Both sides return a plain date: goals deal in calendar days, not
/// instants, so the time of day is dropped either way.
Future<DateTime?> showAdaptiveDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? title,
}) {
  final now = DateTime.now();
  final first = firstDate ?? DateTime(now.year, now.month, now.day);
  final last = lastDate ?? DateTime(now.year + 10);
  final initial = _clamp(initialDate ?? now, first, last);

  return switch (Theme.of(context).platform) {
    .iOS || .macOS => _cupertinoDialog(
      context,
      initial: initial,
      first: first,
      last: last,
      title: title,
    ),
    _ => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    ).then(_dayOf),
  };
}

Future<DateTime?> _cupertinoDialog(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? title,
}) {
  final ThemeData(:textTheme) = Theme.of(context);
  final selected = ValueNotifier<DateTime>(initial);

  return showAdaptiveDialog<DateTime?>(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: .all(.circular(12)),
        ),
        // A Dialog is as wide as it is allowed to be, and `Wrap` passes that
        // straight down — on a tablet the full-width buttons then ran the whole
        // way across. Same ceiling `showBrandedDialog` uses.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: dialogWidth),
          child: Wrap(
            children: [
              Column(
                children: [
                  if (title != null)
                    Padding(
                      padding: const .all(8.0),
                      child: Text(title, style: textTheme.titleMedium),
                    ),
                  SizedBox(
                    height: 200,
                    child: CupertinoDatePicker(
                      mode: .date,
                      initialDateTime: initial,
                      minimumDate: first,
                      maximumDate: last,
                      onDateTimeChanged: (value) => selected.value = value,
                    ),
                  ),
                  // Intrinsic width, right-aligned: full-width buttons ran the
                  // whole span of the dialog, which is not what a footer looks
                  // like anywhere else in the app.
                  Padding(
                    padding: const .fromLTRB(8, 4, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Text(L.of(context).cancel),
                        ),
                        ValueListenableBuilder<DateTime>(
                          valueListenable: selected,
                          builder: (context, value, _) {
                            return PrimaryButton.shrunk(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context, _dayOf(value));
                              },
                              child: Text(L.of(context).ok),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(selected.dispose);
}

/// Midnight local. A deadline is a calendar date — Christmas is Christmas
/// wherever the user is standing — and `GoalStage.toMap` serialises it as one.
DateTime? _dayOf(DateTime? value) {
  if (value == null) return null;
  return DateTime(value.year, value.month, value.day);
}

DateTime _clamp(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}
