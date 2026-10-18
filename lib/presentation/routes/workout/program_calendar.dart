part of 'workout.dart';

/// A program in the device calendar (#391), on its page: the row that says
/// where its sessions go or offers to put them there, while Programs' calendar
/// is selected in Settings, and nothing otherwise. Nothing is asked here: the
/// OS asks for the calendar once the user opens the setup.
class _ProgramCalendarSlot extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    return switch (Preferences.watch(context).isOptionOn(.programsCalendar)) {
      true => Padding(
        padding: const .only(top: 16),
        child: _ProgramCalendarRow(program: program),
      ),
      false => const SizedBox.shrink(),
    };
  }
}

/// Where [program]'s sessions go, or the way to put them there.
class _ProgramCalendarRow extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final setting = ProgramCalendars.watch(context).settingOf(program.id!);
    return ListTile(
      key: AppKeys.programCalendarRow,
      contentPadding: .zero,
      leading: Icon(switch (setting) {
        null => Icons.edit_calendar_rounded,
        _ => Icons.event_available_rounded,
      }),
      title: Text(switch (setting) {
        final setting? => copy.programCalendarIn(setting.calendar),
        null => copy.programCalendarAdd,
      }),
      subtitle: switch (setting) {
        final setting? => Text(_calendarTime(context, setting.time)),
        null => null,
      },
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showCalendarSetup(context, program),
    );
  }
}

/// "All day", or "At 6:00 PM".
String _calendarTime(BuildContext context, int? time) {
  final copy = L.of(context);
  return switch (time) {
    final int minutes => copy.programCalendarAt(_timeOfDay(context, minutes)),
    null => copy.programCalendarAllDay,
  };
}

/// [minutes] after midnight on the device's own clock: "18:00" or "6:00 PM".
String _timeOfDay(BuildContext context, int minutes) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

Future<void> _showCalendarSetup(BuildContext context, Program program) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CalendarSetup(program: program),
  );
}

/// What the calendar dialog holds before it is saved.
typedef _CalendarDraft = ({String? calendarId, String? calendar, Set<int> days, int? time});

/// Which calendar, which days and what time (#391). Opening it lists the
/// device's calendars, which is what asks the OS for the permission — after
/// the yes in the app, never before it. The days are the program's own: picked
/// here, they are its preferred days everywhere.
class _CalendarSetup extends StatefulWidget {
  final Program program;

  const new({required this.program});

  @override
  State<_CalendarSetup> createState() => _CalendarSetupState();
}

class _CalendarSetupState extends State<_CalendarSetup> {
  late final Future<List<CalendarChoice>> _calendars = ProgramCalendars.of(context).calendars();
  late final ValueNotifier<_CalendarDraft> _draft;

  @override
  void initState() {
    super.initState();
    final setting = ProgramCalendars.of(context).settingOf(widget.program.id!);
    _draft = ValueNotifier((
      calendarId: setting?.calendarId,
      calendar: setting?.calendar,
      days: {...widget.program.days},
      time: setting?.time,
    ));
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final exported = ProgramCalendars.of(context).settingOf(widget.program.id!) != null;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: dialogWidth),
        child: FutureBuilder<List<CalendarChoice>>(
          future: _calendars,
          builder: (context, snapshot) {
            final body = switch (snapshot) {
              AsyncSnapshot(hasError: true, :final error) => _Notice(
                text: switch (error) {
                  CalendarDenied() => copy.programCalendarDenied,
                  _ => copy.programCalendarNone,
                },
                action: switch (error) {
                  CalendarDenied() => TextButton(
                    onPressed: () => AppSettings.openAppSettings(asAnotherTask: true),
                    child: Text(copy.programCalendarOpenSettings),
                  ),
                  _ => null,
                },
              ),
              AsyncSnapshot(connectionState: .done, data: final List<CalendarChoice> calendars)
                  when calendars.isEmpty =>
                _Notice(text: copy.programCalendarNone),
              AsyncSnapshot(connectionState: .done, data: final List<CalendarChoice> calendars) => _form(
                context,
                calendars,
              ),
              _ => const Padding(
                padding: .all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            };

            return ValueListenableBuilder<_CalendarDraft>(
              valueListenable: _draft,
              builder: (context, draft, _) {
                final ready = draft.calendarId != null && draft.days.isNotEmpty && snapshot.hasData;
                return Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    Padding(
                      padding: const .fromLTRB(24, 24, 24, 8),
                      child: Text(copy.programCalendarSetup, style: textTheme.titleMedium),
                    ),
                    // what an event will say, before anything is saved: a
                    // shared calendar shows no more than this
                    Padding(
                      padding: const .fromLTRB(24, 0, 24, 8),
                      child: Text(
                        copy.programCalendarSetupNote(copy.programCalendarEventTitle),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Flexible(child: body),
                    // the destructive one on a line of its own, apart from the
                    // pair that closes the dialog: three in a row broke on a
                    // phone, with Save alone on the next line
                    if (exported)
                      Padding(
                        padding: const .fromLTRB(16, 8, 16, 0),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: AppKeys.programCalendarRemove,
                            onPressed: () => _remove(context),
                            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                            icon: const Icon(Icons.event_busy_rounded, size: 18),
                            label: Text(copy.programCalendarRemove),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const .fromLTRB(16, 8, 16, 16),
                      child: OverflowBar(
                        alignment: .end,
                        overflowAlignment: .end,
                        spacing: 8,
                        overflowSpacing: 8,
                        children: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(copy.cancel)),
                          PrimaryButton.shrunk(
                            key: AppKeys.programCalendarSave,
                            onPressed: switch (ready) {
                              true => () => _save(context),
                              false => null,
                            },
                            child: Text(copy.save),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, List<CalendarChoice> calendars) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return ValueListenableBuilder<_CalendarDraft>(
      valueListenable: _draft,
      builder: (context, draft, _) {
        // 16 in, and each row's ink 8 in again with its content: the text
        // sits where the title's does, and the ink stops short of the edge
        return ListView(
          shrinkWrap: true,
          padding: const .symmetric(horizontal: 16),
          children: [
            _inset(Text(copy.programCalendarDays, style: textTheme.titleSmall)),
            const SizedBox(height: 8),
            _inset(
              _DayToggles(
                days: draft.days,
                onToggle: (day) => _change(
                  days: switch (_draft.value.days.contains(day)) {
                    true => {..._draft.value.days}..remove(day),
                    false => {..._draft.value.days, day},
                  },
                ),
              ),
            ),
            if (draft.days.isEmpty) ...[
              const SizedBox(height: 4),
              _inset(Text(copy.programCalendarNoDays, style: muted)),
            ],
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              key: AppKeys.programCalendarAllDay,
              contentPadding: _rowInset,
              shape: _rowShape,
              title: Text(copy.programCalendarAllDay),
              value: draft.time == null,
              // an evening, when most people train after work
              onChanged: (allDay) => switch (allDay) {
                true => _change(allDay: true),
                false => _change(time: 18 * 60),
              },
            ),
            if (draft.time case final int time)
              ListTile(
                contentPadding: _rowInset,
                shape: _rowShape,
                title: Text(copy.time),
                trailing: Text(_timeOfDay(context, time), style: textTheme.bodyLarge),
                onTap: () => _pickTime(context, time),
              ),
            const SizedBox(height: 8),
            _inset(Text(copy.programCalendarWhich, style: textTheme.titleSmall)),
            // under the account each comes from: iCloud, a Gmail address,
            // Exchange — "Home" and "Work" alone say nothing of where they live
            for (final MapEntry(key: account, value: choices) in _byAccount(calendars).entries) ...[
              Padding(
                padding: const .fromLTRB(8, 12, 8, 2),
                child: Text(account, style: muted),
              ),
              for (final choice in choices)
                ListTile(
                  key: AppKeys.programCalendarChoice(choice.id),
                  contentPadding: _rowInset,
                  shape: _rowShape,
                  // one the app cannot add to: there, greyed, and why
                  enabled: choice.writable,
                  selected: draft.calendarId == choice.id,
                  leading: Icon(Icons.circle, color: choice.color, size: 14),
                  title: Text(choice.title),
                  subtitle: switch (choice.writable) {
                    false => Text(copy.programCalendarReadOnly),
                    true => null,
                  },
                  trailing: switch (draft.calendarId == choice.id) {
                    true => const Icon(Icons.check_rounded),
                    false => null,
                  },
                  onTap: () => _change(calendarId: choice.id, calendar: choice.title),
                ),
            ],
            // EventKit lists only the accounts added to the phone itself: a
            // Google Calendar app's own calendars are not among them
            if (Theme.of(context).platform == .iOS) ...[
              const SizedBox(height: 12),
              _inset(Text(copy.programCalendarGoogleHint, style: muted)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: AppKeys.programCalendarSettings,
                  onPressed: () => AppSettings.openAppSettings(asAnotherTask: true),
                  child: Text(copy.programCalendarOpenSettings),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// [calendars] under their accounts, in the order the device lists them.
  static Map<String, List<CalendarChoice>> _byAccount(List<CalendarChoice> calendars) {
    return calendars.fold({}, (accounts, choice) => accounts..putIfAbsent(choice.account, () => []).add(choice));
  }

  /// A row's content, inset as far as a tile's is, so its ink is too.
  static const _rowInset = EdgeInsets.symmetric(horizontal: 8);
  static const _rowShape = RoundedRectangleBorder(borderRadius: .all(.circular(12)));

  /// What is not a tile, in line with the tiles' content.
  Widget _inset(Widget child) => Padding(padding: _rowInset, child: child);

  Future<void> _pickTime(BuildContext context, int time) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time ~/ 60, minute: time % 60),
    );
    if (picked == null) return;
    _change(time: picked.hour * 60 + picked.minute);
  }

  /// [_draft] with what changed, read at the moment of the change: taps quicker
  /// than a frame each build on the last.
  void _change({String? calendarId, String? calendar, Set<int>? days, int? time, bool allDay = false}) {
    final draft = _draft.value;
    _draft.value = (
      calendarId: calendarId ?? draft.calendarId,
      calendar: calendar ?? draft.calendar,
      days: days ?? draft.days,
      time: switch (allDay) {
        true => null,
        false => time ?? draft.time,
      },
    );
  }

  Future<void> _save(BuildContext context) async {
    final (:calendarId, :calendar, :days, :time) = _draft.value;
    if (calendarId == null || calendar == null) return;
    final calendars = ProgramCalendars.of(context);
    final programs = Programs.of(context);
    final analytics = Analytics.of(context);
    final program = programs.lookup(widget.program.id!) ?? widget.program;
    final before = calendars.settingOf(program.id!);
    Navigator.of(context).pop();
    if (!setEquals(days, program.days)) await programs.update(program.copyWith(days: days));
    await calendars.set(program.id!, (calendarId: calendarId, calendar: calendar, time: time));
    analytics.programCalendar(
      change: switch (before) {
        null => .added,
        _ => .changed,
      },
    );
  }

  Future<void> _remove(BuildContext context) async {
    final calendars = ProgramCalendars.of(context);
    final analytics = Analytics.of(context);
    Navigator.of(context).pop();
    await calendars.remove(widget.program.id!);
    analytics.programCalendar(change: .removed);
  }
}

/// A line where the form would be, and the one thing to do about it.
class _Notice extends StatelessWidget {
  final String text;
  final Widget? action;

  const new({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [Text(text), ?action],
      ),
    );
  }
}
