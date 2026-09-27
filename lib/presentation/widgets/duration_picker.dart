import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';

/// Shows a platform-adaptive duration picker
/// and returns the selected duration in seconds
Future<int?> showDurationPicker(BuildContext context, {int? initialValue, String? subtitle}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.iOS:
      return _cupertinoDialog(context, initialValue: initialValue, subtitle: subtitle);
    default:
      return _defaultDialog(context, initialValue: initialValue, subtitle: subtitle);
  }
}

Future<int?> _cupertinoDialog(BuildContext context, {int? initialValue, String? subtitle}) {
  final L(:restTimer) = L.of(context);
  final ThemeData(:textTheme) = Theme.of(context);
  // the wheel's index, not seconds: what the wheel reports as it turns, and
  // what Set timer turns back into a duration
  final selected = ValueNotifier<int>(_index(initialValue));

  return showAdaptiveDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Wrap(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    restTimer,
                    style: textTheme.titleMedium,
                  ),
                ),
                // centred under the title and inset from the dialog's edge: a
                // long exercise name wraps, and bare it ran edge to edge
                if (subtitle != null)
                  Padding(
                    padding: const .symmetric(horizontal: 16),
                    child: Text(
                      subtitle,
                      textAlign: .center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    scrollController: _controller(initialValue),
                    itemExtent: 40,
                    onSelectedItemChanged: (v) => selected.value = v,
                    children: List<Widget>.generate(
                      120,
                      (index) => _Item(duration: _duration(index)),
                    ),
                  ),
                ),
                const _CancelButton(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: _OkButton(currentValue: selected),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<int?> _defaultDialog(BuildContext context, {int? initialValue, String? subtitle}) {
  final L(:restTimer) = L.of(context);
  final ThemeData(:textTheme) = Theme.of(context);

  // the wheel's index, not seconds: what the wheel reports as it turns, and
  // what Set timer turns back into a duration
  final selected = ValueNotifier<int>(_index(initialValue));

  return showAdaptiveDialog<int?>(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Wrap(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    restTimer,
                    style: textTheme.titleMedium,
                  ),
                ),
                // centred under the title and inset from the dialog's edge: a
                // long exercise name wraps, and bare it ran edge to edge
                if (subtitle != null)
                  Padding(
                    padding: const .symmetric(horizontal: 16),
                    child: Text(
                      subtitle,
                      textAlign: .center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                SizedBox(
                  height: 200,
                  child: ListWheelScrollView(
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      HapticFeedback.lightImpact();
                      selected.value = index;
                    },
                    controller: _controller(initialValue),
                    children: List<Widget>.generate(
                      120,
                      (index) => _Item(
                        duration: _duration(index),
                        textStyle: textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
                const _CancelButton(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: _OkButton(currentValue: selected),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _Item extends StatelessWidget {
  final Duration duration;
  final TextStyle? textStyle;

  const new({
    required this.duration,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = formatRestTimer(duration.inSeconds);
    return Semantics(
      button: true,
      label: L.of(context).durationPickerSetTo(formatted),
      child: GestureDetector(
        behavior: .opaque,
        onTap: () {
          HapticFeedback.heavyImpact();
          Navigator.pop(context, duration.inSeconds);
        },
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              formatted,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

Duration _duration(int index) => Duration(seconds: index * 5 + 5);

/// A rest timer as the picker shows it, `mm:ss`, so a list of timers reads
/// the same as the wheel that set them.
String formatRestTimer(int seconds) {
  final duration = Duration(seconds: seconds);
  return '${_pad(duration.inMinutes.remainder(60))}:${_pad(duration.inSeconds.remainder(60))}';
}

String _pad(int n) => n.toString().padLeft(2, '0');

/// The wheel row showing [seconds]; the first row when there is no timer yet.
int _index(int? seconds) {
  return switch (seconds) {
    int v => (v / 5 - 1).toInt(),
    null => 0,
  };
}

FixedExtentScrollController _controller(int? initialValue) {
  return FixedExtentScrollController(initialItem: _index(initialValue));
}

class _Button extends StatelessWidget {
  final String copy;
  final Color? color;
  final TextStyle? style;
  final VoidCallback onPressed;

  const new({
    required this.copy,
    required this.onPressed,
    this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16),
      child: PrimaryButton.wide(
        backgroundColor: color,
        onPressed: onPressed,
        child: Center(
          child: Text(
            copy,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return _Button(
      copy: L.of(context).cancelTimer,
      color: colorScheme.error,
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError),
      onPressed: () {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, 0);
      },
    );
  }
}

class _OkButton extends StatelessWidget {
  final ValueNotifier<int> currentValue;

  const new({required this.currentValue});

  @override
  Widget build(BuildContext context) {
    // no color or style: the CTA wears the accent fill and the button
    // paints its own content color on it
    return _Button(
      copy: L.of(context).setTimer,
      onPressed: () {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, _duration(currentValue.value).inSeconds);
      },
    );
  }
}
