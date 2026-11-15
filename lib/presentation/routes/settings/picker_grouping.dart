part of 'settings.dart';

/// How the exercise picker groups the library (#620): the same choice as the
/// Exercises tab's menu, listed with the other choices about how a screen
/// lays itself out.
///
/// A value-and-menu row ([MenuValue]), as the developer API's token purpose
/// is: four segments in Spanish, French or Russian overflowed a 360dp phone
/// at larger text, and a menu fits any number of choices at any size.
class const _PickerGroupingPicker() extends StatefulWidget {
  @override
  State<_PickerGroupingPicker> createState() => _PickerGroupingPickerState();
}

class _PickerGroupingPickerState extends State<_PickerGroupingPicker> with HasHaptic<_PickerGroupingPicker> {
  /// The value at the row's end, which the menu hangs off.
  final _valueKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Selector<Preferences, PickerGrouping?>(
      // nothing until the preferences have loaded, as History's row: a pick
      // before then would have nowhere to be stored
      selector: (_, preferences) => switch (preferences.isInitialized) {
        true => preferences.pickerGrouping,
        false => null,
      },
      builder: (_, grouping, _) {
        return switch (grouping) {
          null => const SizedBox.shrink(),
          PickerGrouping grouping => ListTile(
            key: AppKeys.settingsPickerGrouping,
            contentPadding: const .symmetric(horizontal: 16),
            title: Text(l.settingsPickerGrouping),
            trailing: MenuValue(grouping.label(l), key: _valueKey),
            onTap: () {
              buzz();
              if (_valueKey.currentContext case final value?) showPickerGroupingMenu(value);
            },
          ),
        };
      },
    );
  }
}
