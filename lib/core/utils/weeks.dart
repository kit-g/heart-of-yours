import 'package:material_ui/material_ui.dart';

/// The user's first day of the week, ISO (1 Monday … 7 Sunday), from the
/// locale until #339 gives it a setting of its own. Everything that counts a
/// week reads it here, so the setting lands in one place.
int firstWeekdayOf(BuildContext context) {
  return switch (MaterialLocalizations.of(context).firstDayOfWeekIndex) {
    0 => DateTime.sunday,
    final index => index,
  };
}
