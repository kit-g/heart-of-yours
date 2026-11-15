part of 'settings.dart';

/// How the exercise picker groups the library (#620): the same choice as the
/// Exercises tab's menu, listed with the other choices about how a screen
/// lays itself out.
///
/// A row with the value at its end and a menu off it, as the developer API's
/// token purpose is: four segments in Spanish, French or Russian overflowed a
/// 360dp phone at larger text, and a menu fits any number of choices at any
/// size.
class const _PickerGroupingPicker() extends StatefulWidget {
  @override
  State<_PickerGroupingPicker> createState() => _PickerGroupingPickerState();
}

class _PickerGroupingPickerState extends State<_PickerGroupingPicker> with HasHaptic<_PickerGroupingPicker> {
  /// The value at the row's end: the menu hangs off it, not off the row's far
  /// edge past the padding, as the developer API's token purpose does.
  final _valueKey = GlobalKey();

  /// The most of the row the value takes: the title keeps the rest, and the
  /// value ellipsizes before the title breaks into a letter a line.
  static const _valueShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    return Selector<Preferences, PickerGrouping>(
      selector: (_, preferences) => preferences.pickerGrouping,
      builder: (_, grouping, _) {
        return LayoutBuilder(
          builder: (_, constraints) {
            return ListTile(
              key: AppKeys.settingsPickerGrouping,
              contentPadding: const .symmetric(horizontal: 16),
              title: Text(l.settingsPickerGrouping),
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * _valueShare),
                child: Row(
                  key: _valueKey,
                  mainAxisSize: .min,
                  spacing: 4,
                  children: [
                    Flexible(
                      child: Text(
                        grouping.label(l),
                        style: textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                    ),
                    const Icon(Icons.unfold_more_rounded, size: 20),
                  ],
                ),
              ),
              onTap: () {
                buzz();
                if (_valueKey.currentContext case final value?) showPickerGroupingMenu(value);
              },
            );
          },
        );
      },
    );
  }
}
