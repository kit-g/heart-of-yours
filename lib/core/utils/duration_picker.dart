import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart_language/heart_language.dart';

/// Shows a platform-adaptive duration picker
/// and returns the selected duration in seconds
Future<int?> showDurationPicker(BuildContext context, {int? initialValue}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.iOS:
      return _cupertinoDialog(context, initialValue: initialValue);
    default:
      return _defaultDialog(context, initialValue: initialValue);
  }
}

Future<int?> _cupertinoDialog(BuildContext context, {int? initialValue}) {
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
                SizedBox(
                  height: 200,
                  child: CupertinoPicker(
                    itemExtent: 40,
                    onSelectedItemChanged: (_) {
                      //
                    },
                    children: List<Widget>.generate(
                      120,
                      (index) => _CupertinoItem(duration: _duration(index)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<int?> _defaultDialog(BuildContext context, {int? initialValue}) {
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
                SizedBox(
                  height: 200,
                  child: ListWheelScrollView(
                    itemExtent: 40,
                    onSelectedItemChanged: (_) => HapticFeedback.lightImpact(),
                    controller: FixedExtentScrollController(
                      initialItem: 5, // todo
                    ),
                    children: List<Widget>.generate(
                      120,
                      (index) => _CupertinoItem(
                        duration: _duration(index),
                        textStyle: textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _CupertinoItem extends StatelessWidget {
  final Duration duration;
  final TextStyle? textStyle;

  const _CupertinoItem({
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
