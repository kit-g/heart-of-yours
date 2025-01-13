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
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium,
                  ),
                SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    scrollController: _controller(initialValue),
                    itemExtent: 40,
                    onSelectedItemChanged: (_) {
                      //
                    },
                    children: List<Widget>.generate(
                      120,
                      (index) => _Item(duration: _duration(index)),
                    ),
                  ),
                ),
                const _CancelButton(),
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
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: textTheme.bodyMedium,
                  ),
                SizedBox(
                  height: 200,
                  child: ListWheelScrollView(
                    itemExtent: 40,
                    onSelectedItemChanged: (_) => HapticFeedback.lightImpact(),
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

  const _Item({
    required this.duration,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, duration.inSeconds);
      },
      child: Center(
        child: Text(
          '${_pad(duration.inMinutes.remainder(60))}:${_pad(duration.inSeconds.remainder(60))}',
          style: textStyle,
        ),
      ),
    );
  }
}

Duration _duration(int index) => Duration(seconds: index * 5 + 5);

String _pad(int n) => n.toString().padLeft(2, '0');

FixedExtentScrollController _controller(int? initialValue) {
  return FixedExtentScrollController(
    initialItem: switch (initialValue) {
      int v => (v / 5 - 1).toInt(),
      null => 0,
    },
  );
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: PrimaryButton.wide(
        backgroundColor: colorScheme.error,
        child: Center(
          child: Text(
            L.of(context).cancelTimer,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onError),
          ),
        ),
        onPressed: () {
          HapticFeedback.heavyImpact();
          Navigator.pop(context, null);
        },
      ),
    );
  }
}
