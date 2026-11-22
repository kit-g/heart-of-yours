part of 'settings.dart';

/// What History opens on (#609, #739). Three views outgrow segments on a small
/// phone in some languages, so the row opens a menu of them.
class const _HistoryViewPicker() extends StatefulWidget {
  @override
  State<_HistoryViewPicker> createState() => _HistoryViewPickerState();
}

class _HistoryViewPickerState extends State<_HistoryViewPicker> with HasHaptic<_HistoryViewPicker> {
  /// The value at the row's end, which the menu hangs off.
  final _valueKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Selector<Preferences, HistoryView?>(
      // nothing until the preferences have loaded: a pick before then would
      // have nowhere to be stored
      selector: (_, preferences) => switch (preferences.isInitialized) {
        true => preferences.historyView,
        false => null,
      },
      builder: (_, view, _) {
        return switch (view) {
          null => const SizedBox.shrink(),
          final HistoryView view => ListTile(
            key: AppKeys.historyViewSetting,
            contentPadding: const .symmetric(horizontal: 16),
            title: Text(l.historyView),
            trailing: MenuValue(view.label(l), key: _valueKey),
            onTap: () {
              buzz();
              if (_valueKey.currentContext case final value?) showHistoryViewMenu(value);
            },
          ),
        };
      },
    );
  }
}
