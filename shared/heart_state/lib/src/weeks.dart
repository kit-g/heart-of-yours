/// Midnight on the first day of [date]'s week, for a week that starts on
/// [firstWeekday] (a [DateTime] weekday: [DateTime.monday] … [DateTime.sunday]).
///
/// The week is the user's (#339): where it begins is a preference, not a fact
/// about the calendar, and the app reads it in one place (`firstWeekdayOf`).
/// Built from calendar fields rather than by subtracting a [Duration], so the
/// answer is midnight in [date]'s zone across a DST change.
DateTime weekOf(DateTime date, {required int firstWeekday}) {
  final back = (date.weekday - firstWeekday) % 7;
  return DateTime(date.year, date.month, date.day - back);
}

/// The half-open [start, end) of [date]'s week, starting on [firstWeekday].
(DateTime, DateTime) weekRange(DateTime date, {required int firstWeekday}) {
  final start = weekOf(date, firstWeekday: firstWeekday);
  return (start, DateTime(start.year, start.month, start.day + 7));
}

/// The first days of the [weeks] weeks ending with [now]'s, oldest first, for
/// weeks that start on [firstWeekday].
List<DateTime> lastWeeksOf(int weeks, {required DateTime now, required int firstWeekday}) {
  final current = weekOf(now, firstWeekday: firstWeekday);
  return [
    for (final back in Iterable<int>.generate(weeks, (index) => weeks - 1 - index))
      DateTime(current.year, current.month, current.day - 7 * back),
  ];
}
