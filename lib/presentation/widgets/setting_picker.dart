import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FixedLengthSettingPicker<T extends Object> extends StatelessWidget {
  final String title;
  final T value;
  final ValueChanged<T?> onValueChanged;
  final Map<T, Widget> children;

  const FixedLengthSettingPicker({
    super.key,
    required this.title,
    required this.value,
    required this.onValueChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: textTheme.bodyLarge,
          ),
          _Switcher(
            children: children,
            value: value,
            onValueChanged: onValueChanged,
          ),
        ],
      ),
    );
  }
}

class _Switcher<T extends Object> extends StatelessWidget {
  final T value;
  final Map<T, Widget> children;
  final ValueChanged<T?> onValueChanged;

  const _Switcher({
    super.key,
    required this.children,
    required this.value,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          children: children,
          onValueChanged: onValueChanged,
        );

      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return ToggleButtons(
          isSelected: [
            for (final key in children.keys) key == value,
          ],
          constraints: const BoxConstraints(maxHeight: 28, minHeight: 28),
          children: children.values.map(
            (child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: child,
              );
            },
          ).toList(),
          onPressed: (index) {
            onValueChanged(children.keys.elementAt(index));
          },
        );
    }
  }
}
