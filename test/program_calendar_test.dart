import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/calendar.dart';
import 'package:heart/core/utils/program_calendar.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// A program's events in the device calendar (#391): what is written, what is
/// rewritten, and what is left alone.
void main() {
  group('ProgramSessionLink', () {
    test('names one occurrence, on the app host under /workout/', () {
      const link = ProgramSessionLink(programId: 'p1', session: 't1', week: 3);
      final uri = link.uri('heart-of.me');
      expect(uri.toString(), 'https://heart-of.me/workout/programs/p1/sessions/t1?week=3');
      expect(ProgramSessionLink.parse(uri), link);
    });

    test('anything else is not one', () {
      for (final other in [
        'https://heart-of.me/workout/programs/p1',
        'https://heart-of.me/workout/programs/p1/sessions/t1',
        'https://heart-of.me/workout/programs/p1/sessions/t1?week=0',
        'heart://app/start?template=t1',
      ]) {
        expect(ProgramSessionLink.parse(Uri.parse(other)), isNull, reason: other);
      }
    });
  });

  group('ProgramCalendars.sync', () {
    final today = DateTime(2026, 10, 14);
    late _Calendar calendar;
    late ProgramCalendars calendars;

    CalendarEventDraft event(DateTime day, {String description = 'Split · Push'}) {
      return CalendarEventDraft(title: 'Training', description: description, url: 'u', day: day);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      calendar = _Calendar();
      calendars = ProgramCalendars(calendar: calendar);
      await calendars.init();
      await calendars.set('p1', (calendarId: 'c1', calendar: 'Home', time: null));
    });

    test('writes what is wanted once, and rewrites only what changed', () async {
      await calendars.sync({
        'p1': [('t1@1', event(today)), ('t2@1', event(DateUtils.addDaysToDate(today, 2)))],
      }, today: today);
      expect(calendar.created, 2);

      await calendars.sync({
        'p1': [('t1@1', event(today)), ('t2@1', event(DateUtils.addDaysToDate(today, 3)))],
      }, today: today);
      expect(calendar.created, 3);
      expect(calendar.events.values.map((event) => event.day), {today, DateUtils.addDaysToDate(today, 3)});
    });

    test('an event no longer wanted goes, unless its day is over', () async {
      final yesterday = DateUtils.addDaysToDate(today, -1);
      await calendars.sync({
        'p1': [('t1@1', event(yesterday)), ('t2@1', event(today))],
      }, today: yesterday);

      await calendars.sync({'p1': []}, today: today);
      expect(calendar.events.values.map((event) => event.day), [yesterday]);
    });

    test('today stays once the program trained today: its link opens what was done', () async {
      await calendars.sync({
        'p1': [('t1@1', event(today))],
      }, today: today);

      await calendars.sync({'p1': []}, today: today, trainedToday: {'p1'});
      expect(calendar.events.values.map((event) => event.day), [today]);
    });

    test('taking a program out deletes what is ahead, and remembers nothing of it', () async {
      await calendars.sync({
        'p1': [('t1@1', event(DateUtils.addDaysToDate(today, 1)))],
      }, today: today);
      await calendars.remove('p1');

      expect(calendar.events, isEmpty);
      expect(calendars.settingOf('p1'), isNull);
    });

    test('what it wrote survives a restart, so nothing is written twice', () async {
      await calendars.sync({
        'p1': [('t1@1', event(today))],
      }, today: today);

      final again = ProgramCalendars(calendar: calendar);
      await again.init();
      await again.sync({
        'p1': [('t1@1', event(today))],
      }, today: today);
      expect(calendar.created, 1);
      expect(again.settingOf('p1'), (calendarId: 'c1', calendar: 'Home', time: null));
    });

    test('a refused permission writes nothing and throws nothing', () async {
      calendar.denied = true;
      await calendars.sync({
        'p1': [('t1@1', event(today))],
      }, today: today);
      expect(calendar.events, isEmpty);
    });
  });
}

class _Calendar implements DeviceCalendar {
  final events = <String, CalendarEventDraft>{};
  var created = 0;
  var denied = false;

  @override
  Future<List<CalendarChoice>> calendars() async => const [];

  @override
  Future<String> create(String calendarId, CalendarEventDraft event) async {
    if (denied) throw const CalendarDenied();
    final id = 'e${created++}';
    events[id] = event;
    return id;
  }

  @override
  Future<void> delete(String eventId) async => events.remove(eventId);
}
