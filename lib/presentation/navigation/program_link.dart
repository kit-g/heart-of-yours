import 'dart:async';

import 'package:heart/core/utils/program_calendar.dart';
import 'package:heart/core/utils/weeks.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// How long a link waits for the state it needs before acting on what is
/// known.
const _patience = Duration(seconds: 10);

/// The link being applied, while one is: a cold start decides the same
/// location more than once, and each decision would act again.
ProgramSessionLink? _inFlight;

/// Opens what a calendar event's link names (#391): one occurrence of a
/// session. Still ahead, it starts the session as Start on the program's band
/// does — over a running workout, the same question, never a silent replace.
/// Done or set aside, it opens the workout or the skip in History, and never
/// starts the session a second time. Passed with nothing to show, or a session
/// no longer in the program, it opens the program. A program gone altogether
/// leaves the workouts tab the router already landed on.
///
/// Called from the router's redirect; like a shortcut's link, it waits —
/// bounded — for the programs, the templates and the active workout to be read.
Future<void> runProgramSessionLink(
  ProgramSessionLink link, {
  required Programs programs,
  required Templates templates,
  required Workouts workouts,
  required GlobalKey<NavigatorState> navigator,
}) async {
  if (_inFlight == link) return;
  _inFlight = link;
  try {
    // off the redirect's own turn
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await Future.wait([
      _settled(programs, () => programs.hasLoaded),
      _settled(templates, () => templates.hasLoaded),
      _settled(workouts, () => workouts.hasResolvedActiveWorkout),
    ]);

    final context = navigator.currentContext;
    if (context == null || !context.mounted) return;
    final router = HeartRouter.of(context);
    final analytics = Analytics.of(context);
    final program = programs.lookup(link.programId);
    if (program == null) return;

    final state = await programs.occurrence(
      program,
      session: link.session,
      week: link.week,
      now: DateTime.now(),
      firstWeekday: firstWeekdayOf(context),
    );
    if (!context.mounted) return;
    final session = templates.lookup(link.session);

    switch ((state, session)) {
      case (OccurrenceDone(:final workoutId), _):
        analytics.programLinkOpened(outcome: .workout);
        router.goToWorkoutEditor(workoutId);
      case (OccurrenceSkipped(:final skipId), _):
        analytics.programLinkOpened(outcome: .skip);
        router.goToSkip(skipId);
      case (OccurrenceAhead(), final Template session) when !program.archived:
        final started = await startWorkoutOverActive(
          context,
          () => workouts.startWorkout(
            source: .program,
            template: startingWorkout(context, session),
            applyPinnedNotes: true,
          ),
        );
        if (started) analytics.programLinkOpened(outcome: .started);
        // started, or the running one kept: either way there is one to show
        if (started || workouts.hasActiveWorkout) {
          workouts.notifyOfActiveWorkout();
          await router.showActiveWorkout();
        }
      case _:
        analytics.programLinkOpened(outcome: .program);
        router.goToProgram(link.programId);
    }
  } finally {
    _inFlight = null;
  }
}

/// Completes once [done] holds, or once [_patience] has run out.
Future<void> _settled(ChangeNotifier notifier, bool Function() done) {
  if (done()) return Future.value();
  final settled = Completer<void>();
  void check() {
    if (!done() || settled.isCompleted) return;
    notifier.removeListener(check);
    settled.complete();
  }

  notifier.addListener(check);
  return settled.future.timeout(_patience, onTimeout: () => notifier.removeListener(check));
}
