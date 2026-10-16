import 'dart:async';
import 'dart:convert';

import 'package:heart/core/env/calendar.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The link an event carries (#391): one occurrence of a session, the
/// program week it was planned in included, on the app's own https host —
/// `/workout/programs/<program>/sessions/<session>?week=<n>`. Under
/// `/workout/`, which the universal links and Android's app links already
/// claim, so it is tappable in any calendar app and lands on the website
/// without the app.
final class ProgramSessionLink {
  final String programId;
  final String session;
  final int week;

  const new({required this.programId, required this.session, required this.week});

  Uri uri(String host) {
    return Uri.https(host, '/workout/programs/$programId/sessions/$session', {'week': '$week'});
  }

  /// Null for any other path.
  static ProgramSessionLink? parse(Uri uri) {
    return switch ((uri.pathSegments, int.tryParse(uri.queryParameters['week'] ?? ''))) {
      (['workout', 'programs', final programId, 'sessions', final session], final int week) when week > 0 =>
        ProgramSessionLink(programId: programId, session: session, week: week),
      _ => null,
    };
  }

  /// By value: the same link arriving twice is the same ask.
  @override
  bool operator ==(Object other) {
    return other is ProgramSessionLink &&
        other.programId == programId &&
        other.session == session &&
        other.week == week;
  }

  @override
  int get hashCode => Object.hash(programId, session, week);
}

/// Where a program's sessions go in the calendar (#391): which calendar, and at
/// what time — [time] in minutes after midnight, null for all day.
typedef ProgramCalendarSetting = ({String calendarId, String calendar, int? time});

/// One event Heart wrote: its id, the calendar it is in, the day it is on, and
/// what it said, to tell whether it needs writing again. A [calendarId] of null
/// is one written before it was kept, which the next sync writes again.
typedef _Written = ({String id, String? calendarId, DateTime day, String fingerprint});

/// The calendar export of each program, and the events it wrote (#391).
///
/// Device-only: a calendar id means nothing on another device, and the events
/// are the device calendar's to sync — Google's or iCloud's, never Heart's. So
/// all of it lives in this device's preferences, out of the account, the export
/// and the backup.
///
/// [sync] makes the calendar say what it is given and nothing else of Heart's:
/// events no longer wanted are deleted, unless their day is over — a past day
/// is history, and a missed one is no failure to erase.
class ProgramCalendars with ChangeNotifier {
  static const _key = 'programCalendars';

  final DeviceCalendar? _calendar;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// What "today" is when a program is taken out: the device's clock, or a
  /// test's fixed day.
  final DateTime Function() _now;

  new({this._calendar, this.onError, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static ProgramCalendars of(BuildContext context) => Provider.of<ProgramCalendars>(context, listen: false);

  static ProgramCalendars watch(BuildContext context) => Provider.of<ProgramCalendars>(context, listen: true);

  final _settings = <String, ProgramCalendarSetting>{};
  final _events = <String, Map<String, _Written>>{};
  bool _loaded = false;

  bool get hasLoaded => _loaded;

  /// The programs whose sessions go in a calendar.
  Iterable<String> get programs => _settings.keys;

  ProgramCalendarSetting? settingOf(String programId) => _settings[programId];

  /// The device's writable calendars. Asks for the OS permission the first
  /// time; throws [CalendarDenied] when it is refused.
  Future<List<CalendarChoice>> calendars() async => await _calendar?.calendars() ?? const [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) case final String stored) {
      try {
        _read(jsonDecode(stored));
      } catch (error, stacktrace) {
        onError?.call(error, stacktrace: stacktrace);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Puts [programId] in a calendar, or moves it to another one or another
  /// time; [sync] writes the events.
  Future<void> set(String programId, ProgramCalendarSetting setting) {
    return _serially(() async {
      final before = _settings[programId];
      _settings[programId] = setting;
      // another calendar: the events in the old one go, and the next sync
      // writes them where they now belong
      if (before != null && before.calendarId != setting.calendarId) await _clear(programId, all: true);
      await _save();
      notifyListeners();
    });
  }

  /// Takes [programId] out of the calendar: its events from today on go, and
  /// the setting with them.
  Future<void> remove(String programId) {
    return _serially(() async {
      await _clear(programId);
      _settings.remove(programId);
      _events.remove(programId);
      await _save();
      notifyListeners();
    });
  }

  // what changes the settings or the events runs one at a time: a sync
  // halfway through its loop would otherwise write into a calendar the user
  // just left, or into a map no longer kept
  Future<void> _last = Future.value();

  Future<void> _serially(Future<void> Function() body) {
    final next = _last.then((_) => body());
    _last = next.catchError((_) {});
    return next;
  }

  Future<void>? _running;
  Map<String, List<(String, CalendarEventDraft)>>? _queued;
  DateTime? _queuedToday;
  Set<String> _queuedTrained = const {};

  /// Makes each program's events the [wanted] ones, keyed by occurrence: a
  /// program with a setting and nothing in [wanted] keeps only its past days.
  /// A program in [trainedToday] counts today as past too: the session it did
  /// or set aside keeps its event, whose link opens it in History. Calls
  /// arriving while one runs are folded into a single next run.
  Future<void> sync(
    Map<String, List<(String, CalendarEventDraft)>> wanted, {
    required DateTime today,
    Set<String> trainedToday = const {},
  }) {
    _queued = wanted;
    _queuedToday = today;
    _queuedTrained = trainedToday;
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      for (var wanted = _queued; wanted != null; wanted = _queued) {
        final (asked, today, trained) = (wanted, _queuedToday!, _queuedTrained);
        _queued = null;
        await _serially(() => _sync(asked, today, trained));
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _sync(
    Map<String, List<(String, CalendarEventDraft)>> wanted,
    DateTime today,
    Set<String> trainedToday,
  ) async {
    final calendar = _calendar;
    if (calendar == null) return;
    var changed = false;
    try {
      for (final MapEntry<String, ProgramCalendarSetting>(key: programId, value: setting) in [..._settings.entries]) {
        final written = _events.putIfAbsent(programId, () => {});
        final over = switch (trainedToday.contains(programId)) {
          true => DateUtils.addDaysToDate(today, 1),
          false => today,
        };
        final events = {
          for (final (key, event) in wanted[programId] ?? const <(String, CalendarEventDraft)>[]) key: event,
        };

        for (final MapEntry<String, _Written>(:key, value: event) in [...written.entries]) {
          if (events.containsKey(key)) continue;
          if (event.day.isBefore(over)) {
            written.remove(key);
          } else {
            await calendar.delete(event.id);
            written.remove(key);
          }
          changed = true;
        }

        for (final MapEntry<String, CalendarEventDraft>(:key, value: event) in events.entries) {
          final held = written[key];
          if ((held?.fingerprint, held?.calendarId) == (event.fingerprint, setting.calendarId)) continue;
          if (held != null) await calendar.delete(held.id);
          written.remove(key);
          changed = true;
          try {
            final id = await calendar.create(setting.calendarId, event);
            written[key] = (id: id, calendarId: setting.calendarId, day: event.day, fingerprint: event.fingerprint);
          } on CalendarMissing {
            // the calendar went: nothing of this program's can be written
            // until the user picks another
            break;
          }
        }
      }
    } on CalendarDenied {
      // the permission was taken back in Settings: nothing to do until it is
      // given again, and the program page says so
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    } finally {
      if (changed) await _save();
    }
  }

  /// Deletes [programId]'s events from today on — or [all] of them, the past
  /// ones too, when it leaves for another calendar.
  Future<void> _clear(String programId, {bool all = false}) async {
    final written = _events[programId];
    final calendar = _calendar;
    if (written == null || calendar == null) return;
    final today = DateUtils.dateOnly(_now());
    try {
      for (final MapEntry<String, _Written>(:key, value: event) in [...written.entries]) {
        if (all || !event.day.isBefore(today)) await calendar.delete(event.id);
        written.remove(key);
      }
    } on CalendarDenied {
      written.clear();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  void _read(Object? json) {
    if (json is! Map) return;
    for (final MapEntry(:key, :value) in json.entries) {
      if (value case {'calendarId': String calendarId, 'calendar': String name}) {
        _settings['$key'] = (calendarId: calendarId, calendar: name, time: value['time'] as int?);
        _events['$key'] = {
          if (value['events'] case Map events)
            for (final MapEntry(key: occurrence, value: event) in events.entries)
              if (event case {'id': String id, 'day': String day, 'print': String print})
                if (DateTime.tryParse(day) case final DateTime day)
                  '$occurrence': (
                    id: id,
                    calendarId: event['calendar'] as String?,
                    day: day,
                    fingerprint: print,
                  ),
        };
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final MapEntry(key: programId, value: (:calendarId, :calendar, :time)) in _settings.entries)
          programId: {
            'calendarId': calendarId,
            'calendar': calendar,
            'time': time,
            'events': {
              for (final MapEntry(:key, value: (:id, :calendarId, :day, :fingerprint))
                  in (_events[programId] ?? const {}).entries)
                key: {'id': id, 'calendar': ?calendarId, 'day': day.toIso8601String(), 'print': fingerprint},
            },
          },
      }),
    );
  }
}
