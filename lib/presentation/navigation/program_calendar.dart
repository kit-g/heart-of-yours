import 'dart:async';

import 'package:heart/core/env/calendar.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/utils/program_calendar.dart';
import 'package:heart/core/utils/weeks.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// How far ahead a program's sessions are written: two weeks, which the next
/// time the app runs moves along. Far enough to plan a week around, near enough
/// that a schedule which is only a suggestion does not fill a calendar.
const _horizon = 14;

/// Keeps each exported program's events what the program has ahead of it
/// (#391): told again whenever the programs, their history, the sessions or
/// the switches change. A program that moves on — a workout, a skip, a repeat,
/// a pause — moves its future events with it; a paused, finished or archived
/// one has none, and with either switch off no program has any.
class ProgramCalendarPresenter extends StatefulWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  State<ProgramCalendarPresenter> createState() => _ProgramCalendarPresenterState();
}

class _ProgramCalendarPresenterState extends State<ProgramCalendarPresenter> {
  final _listening = <Listenable>[];
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final each in _listening) {
      each.removeListener(_schedule);
    }
    _listening
      ..clear()
      ..addAll([
        Programs.of(context),
        Templates.of(context),
        Preferences.of(context),
        ProgramCalendars.of(context),
      ]);
    for (final each in _listening) {
      each.addListener(_schedule);
    }
    // the words follow the language
    L.of(context);
    _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final each in _listening) {
      each.removeListener(_schedule);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// A finish touches the programs, the templates and the history at once: one
  /// sync after they settle rather than three.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _sync);
  }

  void _sync() {
    if (!mounted) return;
    final calendars = ProgramCalendars.of(context);
    final programs = Programs.of(context);
    final templates = Templates.of(context);
    final preferences = Preferences.of(context);
    // before the programs are read every program looks deleted
    if (!calendars.hasLoaded || !programs.hasLoaded || programs.userId == null || !templates.hasLoaded) return;
    if (calendars.programs.isEmpty) return;

    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final on = preferences.isOn(.programs) && preferences.isOn(.programCalendar);
    final wanted = <String, List<(String, CalendarEventDraft)>>{};
    final trained = <String>{};

    for (final programId in [...calendars.programs]) {
      final program = programs.lookup(programId);
      // deleted: here, or on another device
      if (program == null) {
        unawaited(calendars.remove(programId));
        continue;
      }
      if (!on || program.archived) continue;
      final setting = calendars.settingOf(programId)!;
      final position = programs.position(program, now: now, firstWeekday: firstWeekdayOf(context));
      final trainedToday = programs.markedOn(programId, now);
      if (trainedToday) trained.add(programId);
      wanted[programId] = [
        for (final planned in plannedSessions(
          program,
          position,
          from: now,
          days: _horizon,
          trainedToday: trainedToday,
        ))
          if (templates.lookup(planned.session) case final Template session)
            ('${planned.session}@${planned.week}', _event(program, session, planned, setting)),
      ];
    }
    unawaited(calendars.sync(wanted, today: today, trainedToday: trained));
  }

  /// The title is the same plain word for every event: calendars are shared and
  /// shown as busy time, so it says nothing of the program, the session, the
  /// body or Heart. The description says more — still visible to anyone the
  /// user shares details with, so names and set counts only: never a weight, a
  /// health value or anything to go easy on.
  CalendarEventDraft _event(Program program, Template session, PlannedSession planned, ProgramCalendarSetting setting) {
    final copy = L.of(context);
    final link = ProgramSessionLink(programId: program.id!, session: planned.session, week: planned.week);
    final url = link.uri(AppConfig.of(context).appDomain).toString();
    final name = switch (session.name) {
      final String name when name.isNotEmpty => name,
      _ => copy.template,
    };
    final exercises = [
      for (final exercise in session.take(4)) copy.programCalendarExercise(exercise.length, exercise.exercise.name),
      if (session.length > 4) copy.programCalendarMore(session.length - 4),
    ];
    return CalendarEventDraft(
      title: copy.programCalendarEventTitle,
      description: [
        '${program.name} · $name',
        switch (program.weeks) {
          final int weeks => copy.programWeekOf(planned.week, weeks),
          null => copy.programWeek(planned.week),
        },
        '',
        ...exercises,
        '',
        copy.programCalendarOpen,
        url,
      ].join('\n'),
      url: url,
      day: planned.day,
      time: setting.time,
    );
  }
}
