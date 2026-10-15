part of 'workout.dart';

/// A program in the device calendar (#391), on its page: the one ask, the one
/// notice after a no, the row that says where its sessions go — or nothing.
/// Asked here and not when the program starts: here is where a schedule is
/// looked at.
class _ProgramCalendarSlot extends StatelessWidget {
  static const _feature = Feature.programCalendar;

  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final copy = L.of(context);

    final Widget? child = switch (preferences) {
      _ when preferences.isOn(_feature) => _ProgramCalendarRow(program: program),
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when preferences.shouldOffer(_feature) && program.sessions.isNotEmpty => FeatureOffer(
        key: AppKeys.programCalendarOffer,
        acceptKey: AppKeys.programCalendarAccept,
        declineKey: AppKeys.programCalendarDecline,
        icon: Icons.edit_calendar_rounded,
        title: copy.programCalendarOfferTitle,
        body: copy.programCalendarOfferBody(copy.programCalendarEventTitle),
        onAnswer: (yes) {
          preferences.answerOffer(_feature, yes: yes);
          // the yes is the way in: the OS asks next, then where and when
          if (yes) _showCalendarSetup(context, program);
        },
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };

    return switch (child) {
      final Widget child => Padding(padding: const .only(top: 16), child: child),
      null => const SizedBox.shrink(),
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
    final int minutes => copy.programCalendarAt(_clock(context, minutes)),
    null => copy.programCalendarAllDay,
  };
}

/// [minutes] after midnight on the device's own clock: "18:00" or "6:00 PM".
String _clock(BuildContext context, int minutes) {
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
                    Flexible(child: body),
                    Padding(
                      padding: const .fromLTRB(16, 8, 16, 16),
                      child: Wrap(
                        alignment: .end,
                        spacing: 8,
                        children: [
                          if (exported)
                            TextButton(
                              key: AppKeys.programCalendarRemove,
                              onPressed: () => _remove(context),
                              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                              child: Text(copy.programCalendarRemove),
                            ),
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
        return ListView(
          shrinkWrap: true,
          padding: const .symmetric(horizontal: 24),
          children: [
            Text(copy.programCalendarDays, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            _DayToggles(
              days: draft.days,
              onToggle: (day) => _change(
                days: switch (_draft.value.days.contains(day)) {
                  true => {..._draft.value.days}..remove(day),
                  false => {..._draft.value.days, day},
                },
              ),
            ),
            if (draft.days.isEmpty) ...[
              const SizedBox(height: 4),
              Text(copy.programCalendarNoDays, style: muted),
            ],
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              key: AppKeys.programCalendarAllDay,
              contentPadding: .zero,
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
                contentPadding: .zero,
                title: Text(copy.time),
                trailing: Text(_clock(context, time), style: textTheme.bodyLarge),
                onTap: () => _pickTime(context, time),
              ),
            const SizedBox(height: 8),
            Text(copy.programCalendarWhich, style: textTheme.titleSmall),
            for (final choice in calendars)
              ListTile(
                key: AppKeys.programCalendarChoice(choice.id),
                contentPadding: .zero,
                selected: draft.calendarId == choice.id,
                leading: Icon(Icons.circle, color: choice.color, size: 14),
                title: Text(choice.title),
                subtitle: switch (choice.account) {
                  final String account when account.isNotEmpty && account != choice.title => Text(account),
                  _ => null,
                },
                trailing: switch (draft.calendarId == choice.id) {
                  true => const Icon(Icons.check_rounded),
                  false => null,
                },
                onTap: () => _change(calendarId: choice.id, calendar: choice.title),
              ),
          ],
        );
      },
    );
  }

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
