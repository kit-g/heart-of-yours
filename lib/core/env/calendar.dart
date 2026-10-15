import 'dart:ui';

import 'package:eventide/eventide.dart';

/// A calendar the device holds that Heart may write to (#391): the user's own,
/// iCloud's or Google's, whichever accounts the device is signed in to.
typedef CalendarChoice = ({String id, String title, String account, Color color});

/// What one event says and when (#391). [time] is minutes after midnight, or
/// null for an all-day event.
final class CalendarEventDraft {
  final String title;
  final String description;
  final String url;
  final DateTime day;
  final int? time;
  final Duration length;

  const new({
    required this.title,
    required this.description,
    required this.url,
    required this.day,
    this.time,
    this.length = const Duration(hours: 1),
  });

  DateTime get start => switch (time) {
    final int minutes => DateTime(day.year, day.month, day.day, 0, minutes),
    null => DateTime(day.year, day.month, day.day),
  };

  DateTime get end => switch (time) {
    int() => start.add(length),
    // an all-day event ends at the next midnight
    null => DateTime(day.year, day.month, day.day + 1),
  };

  /// Everything an update would change, as one string: what was written last
  /// is compared against it, so an unchanged event is never written again.
  String get fingerprint => [title, description, url, start.toIso8601String(), end.toIso8601String()].join('\u0000');
}

/// The calendar would not let Heart in: the permission was refused or taken
/// back.
final class CalendarDenied implements Exception {
  const new();
}

/// The calendar an export names is gone from the device.
final class CalendarMissing implements Exception {
  const new();
}

/// The device's calendars, as far as Heart touches them: list the writable
/// ones, and write, rewrite and delete its own events. The first call asks for
/// the OS permission, so nothing calls this before the user said yes in the
/// app.
abstract interface class DeviceCalendar {
  Future<List<CalendarChoice>> calendars();

  /// The new event's id.
  Future<String> create(String calendarId, CalendarEventDraft event);

  /// Deletes [eventId]; one already gone — deleted by hand — is not an error.
  Future<void> delete(String eventId);
}

/// [DeviceCalendar] over EventKit and Android's calendar provider.
final class EventideCalendar implements DeviceCalendar {
  final Eventide _eventide;

  new([Eventide? eventide]) : _eventide = eventide ?? Eventide();

  @override
  Future<List<CalendarChoice>> calendars() {
    return _guard(() async {
      final calendars = await _eventide.retrieveCalendars();
      return [
        for (final calendar in calendars)
          (id: calendar.id, title: calendar.title, account: calendar.account.name, color: calendar.color),
      ];
    });
  }

  @override
  Future<String> create(String calendarId, CalendarEventDraft event) {
    return _guard(() async {
      final created = await _eventide.createEvent(
        calendarId: calendarId,
        title: event.title,
        startDate: event.start,
        endDate: event.end,
        isAllDay: event.time == null,
        description: event.description,
        url: event.url,
      );
      return created.id;
    });
  }

  @override
  Future<void> delete(String eventId) async {
    try {
      await _guard(() => _eventide.deleteEvent(eventId: eventId));
    } on CalendarMissing {
      // deleted by hand, or with its calendar: already what was asked
    }
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ETPermissionException {
      throw const CalendarDenied();
    } on ETNotFoundException {
      throw const CalendarMissing();
    }
  }
}
