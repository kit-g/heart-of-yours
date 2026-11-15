part of 'settings.dart';

/// How the exercise picker groups the library (#620): the same choice as the
/// picker's own button, listed with the other choices about how a screen lays
/// itself out.
///
/// A row with the value at its end and a menu off it, as the developer API's
/// token purpose is: four segments in Spanish, French or Russian overflowed a
/// 360dp phone at larger text, and a menu fits any number of choices at any
/// size.
class const _PickerGroupingPicker() extends StatelessWidget with HasHaptic {
  static const _menuWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    return Selector<Preferences, PickerGrouping>(
      selector: (_, preferences) => preferences.pickerGrouping,
      // this context's render box is the row's: the menu hangs off its far
      // end, where the value is
      builder: (row, grouping, _) {
        return ListTile(
          key: AppKeys.settingsPickerGrouping,
          contentPadding: const .symmetric(horizontal: 16),
          title: Text(l.settingsPickerGrouping),
          trailing: Row(
            mainAxisSize: .min,
            spacing: 4,
            children: [
              Text(grouping.label(l), style: textTheme.bodyMedium),
              const Icon(Icons.unfold_more_rounded, size: 20),
            ],
          ),
          onTap: () async {
            buzz();
            final picked = await showMenu<PickerGrouping>(
              context: row,
              position: menuEndingUnder(row, width: _menuWidth),
              constraints: const .tightFor(width: _menuWidth),
              items: [
                for (final each in PickerGrouping.values)
                  CheckedPopupMenuItem<PickerGrouping>(
                    value: each,
                    checked: each == grouping,
                    child: Text(each.label(l)),
                  ),
              ],
            );
            if (!row.mounted) return;
            if (picked case final PickerGrouping picked when picked != grouping) {
              Preferences.of(row).setPickerGrouping(picked);
            }
          },
        );
      },
    );
  }
}
