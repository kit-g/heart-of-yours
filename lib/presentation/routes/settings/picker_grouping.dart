part of 'settings.dart';

/// How the exercise picker groups the library (#620): the same choice as the
/// picker's own button, listed with the other choices about how a screen lays
/// itself out.
///
/// The control sits under its name rather than beside it: four segments, in
/// Russian or French, do not share a phone's row with a title.
class const _PickerGroupingPicker() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    return Selector<Preferences, PickerGrouping>(
      selector: (_, preferences) => preferences.pickerGrouping,
      builder: (context, grouping, _) {
        return Padding(
          padding: const .symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Text(l.settingsPickerGrouping, style: textTheme.bodyLarge),
              SizedBox(
                width: double.infinity,
                child: SettingSwitcher<PickerGrouping>(
                  value: grouping,
                  onValueChanged: (picked) {
                    if (picked != null) Preferences.of(context).setPickerGrouping(picked);
                  },
                  children: {
                    for (final each in PickerGrouping.values)
                      each: Text(each.label(l), maxLines: 1, overflow: .ellipsis),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
