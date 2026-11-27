import 'package:heart/core/utils/visual.dart' show menuEndingUnder;
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

extension HistoryViewCopy on HistoryView {
  String label(L l) {
    return switch (this) {
      .list => l.historyAsList,
      .calendar => l.calendar,
      .month => l.historyByMonth,
    };
  }

  IconData get icon {
    return switch (this) {
      .list => Icons.view_agenda_outlined,
      .calendar => Icons.calendar_month_rounded,
      .month => Icons.today_rounded,
    };
  }
}

/// History's views, the one it is on checked, under [anchor]: the menu that
/// Settings' row and History's own switch both open (#739).
///
/// The checked one picked again is a choice only while nothing was stored
/// since the menu opened: a view adopted meanwhile from another device is newer
/// than what the menu showed.
Future<void> showHistoryViewMenu(BuildContext anchor) async {
  final l = L.of(anchor);
  final preferences = Preferences.of(anchor);
  final shown = preferences.historyView;
  final stored = preferences.screenChoices[ScreenChoice.historyView];
  final (:position, :constraints) = menuEndingUnder(anchor, width: 220);
  final picked = await showMenu<HistoryView>(
    context: anchor,
    position: position,
    constraints: constraints,
    items: [
      for (final each in HistoryView.values)
        CheckedPopupMenuItem<HistoryView>(
          key: AppKeys.historyViewChoice(each.value),
          value: each,
          checked: each == shown,
          child: Text(each.label(l)),
        ),
    ],
  );
  if (picked == null) return;
  if (picked == shown && preferences.screenChoices[ScreenChoice.historyView] != stored) return;
  preferences.setHistoryView(picked);
}
