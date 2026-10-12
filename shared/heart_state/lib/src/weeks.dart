/// Midnight on the first day of [date]'s week, for a week that starts on
/// [firstWeekday] (a [DateTime] weekday: [DateTime.monday] … [DateTime.sunday]).
///
/// The week is the user's (#339): where it begins is a preference, not a fact
/// about the calendar. Built from calendar fields rather than by subtracting a
/// [Duration], so the answer is midnight in [date]'s zone across a DST change.
DateTime weekStart(DateTime date, int firstWeekday) {
  final back = (date.weekday - firstWeekday + 7) % 7;
  return DateTime(date.year, date.month, date.day - back);
}

/// The half-open [start, end) of [date]'s week, starting on [firstWeekday].
(DateTime, DateTime) weekOf(DateTime date, int firstWeekday) {
  final start = weekStart(date, firstWeekday);
  return (start, DateTime(start.year, start.month, start.day + 7));
}
