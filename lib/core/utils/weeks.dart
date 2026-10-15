import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The user's first day of the week, ISO (1 Monday … 7 Sunday): their choice
/// in Settings, the locale's first day until they make one (#339). Everything
/// that counts a week reads it here.
///
/// [listen] as in `Provider.of`: true from a build that shows something
/// weekly, so the page follows a change made in Settings.
int firstWeekdayOf(BuildContext context, {bool listen = false}) {
  return switch (listen) {
    true => Preferences.watch(context).firstWeekday,
    false => Preferences.of(context).firstWeekday,
  };
}
