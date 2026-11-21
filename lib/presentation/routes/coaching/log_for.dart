part of 'coaching.dart';

/// The way to log a session a coach trained with a client (#560): it becomes
/// the client's workout, in their history, marked as logged by the coach.
class _LogForButton extends StatefulWidget {
  final ClientSummary client;

  /// Opens the workout to fill in.
  final ValueChanged<PastWorkout> onLog;

  const new({required this.client, required this.onLog});

  @override
  State<_LogForButton> createState() => _LogForButtonState();
}

class _LogForButtonState extends State<_LogForButton> {
  /// Reading their program, and asking which session and when: a second tap
  /// meanwhile would start a second log.
  final _busy = ValueNotifier(false);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    return Tooltip(
      // what it is for, which the button's two words don't say
      message: l.coachingLogWorkoutBody,
      child: PrimaryButton.shrunk(
        key: AppKeys.coachingLogFor,
        // the house 32pt look, and a full tap target
        hitHeight: kMinInteractiveDimension,
        backgroundColor: colorScheme.secondaryContainer,
        onPressed: _start,
        child: Row(
          mainAxisSize: .min,
          spacing: 8,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (_, busy, _) => switch (busy) {
                true => const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
                false => Icon(Icons.edit_calendar_outlined, size: 18, color: colorScheme.onSecondaryContainer),
              },
            ),
            Flexible(
              child: Text(
                l.coachingLogWorkout,
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Runs one log at a time: a tap while one is under way does nothing.
  Future<void> _start() async {
    if (_busy.value) return;
    _busy.value = true;
    try {
      await _log(context);
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  /// Which of their program's sessions it was, when they follow one, then
  /// when it was, then the workout to fill in. A session starts as the
  /// client's own device would have laid it out then, targets and all, and
  /// goes with the plan it was asked to be (heart-api#439).
  Future<void> _log(BuildContext context) async {
    final client = widget.client;
    final l = L.of(context);
    final name = _clientName(l, client);
    final sessions = await _sessionsOf(context);
    if (!context.mounted) return;
    final _LogStart start;
    switch (sessions) {
      case (:final sessions, :final next) when sessions.isNotEmpty:
        final picked = await showMenu<_LogStart>(
          context: context,
          position: menuUnder(context),
          items: [
            for (final session in sessions)
              PopupMenuItem(
                key: AppKeys.coachingLogSession(session.id),
                value: _FromSession(session),
                child: _SessionItem(session: session, next: session.id == next),
              ),
            PopupMenuItem(
              key: AppKeys.coachingLogBlank,
              value: const _Blank(),
              child: Text(l.coachingLogOther),
            ),
          ],
        );
        if (picked == null || !context.mounted) return;
        start = picked;
      case _:
        start = const _Blank();
    }
    final programs = ClientPrograms.of(context);
    final round = roundToPlates(context);
    await logPastWorkout(
      context,
      logTo: _logFor(client.studentId, name),
      loggingFor: name,
      // a session is laid out once its time is known: as it stood then
      open: (past) => widget.onLog(switch (start) {
        _FromSession(:final session) => _planned(programs, session, past, name: name, round: round),
        _Blank() => past,
      }),
    );
  }

  /// [session] as the client's device would have started it when [past]
  /// began, at the time picked for it, sent with its plan.
  PastWorkout _planned(
    ClientPrograms programs,
    Template session,
    PastWorkout past, {
    required String name,
    required RoundWeight round,
  }) {
    final (:workout, :plan) = programs.plan(session, at: past.workout.start, now: clock.now(), round: round);
    workout
      ..start = past.workout.start
      ..end = past.workout.end;
    return PastWorkout(
      workout: workout,
      logTo: _logFor(widget.client.studentId, name, plan: plan),
      loggingFor: past.loggingFor,
    );
  }

  /// The sessions of the program they follow, the next one marked: read
  /// afresh, since where they are moves with every session they train. None
  /// when they follow none, or it can't be read; a blank workout still logs.
  Future<({List<Template> sessions, String? next})> _sessionsOf(BuildContext context) async {
    final client = widget.client;
    final programId = client.programId;
    if (programId == null) return (sessions: const <Template>[], next: null);
    final programs = ClientPrograms.of(context);
    await programs.open(client.studentId, programId);
    final view = programs.view(programId);
    return (
      sessions: view?.sessions ?? const <Template>[],
      next: switch (view?.position['next']) {
        final String id => id,
        _ => null,
      },
    );
  }
}

/// Where a session the coach logs comes from.
sealed class _LogStart {
  const new();
}

final class _FromSession extends _LogStart {
  final Template session;

  const new(this.session);
}

final class _Blank extends _LogStart {
  const new();
}

class _SessionItem extends StatelessWidget {
  final Template session;
  final bool next;

  const new({required this.session, required this.next});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        Flexible(
          child: Text(
            switch (session.name?.trim()) {
              final String name when name.isNotEmpty => name,
              _ => l.coachingReviewUntitled,
            },
            overflow: .ellipsis,
          ),
        ),
        if (next) Text(l.coachingLogNext, style: textTheme.labelMedium?.copyWith(color: colorScheme.primary)),
      ],
    );
  }
}

/// Sends a workout the coach filled in as [studentId]'s. The editor has gone
/// by then, so what happens is said in a snackbar. A failure that may pass,
/// the network or the server's, offers to send it again under the same id,
/// which the server takes once; a refusal says why, and nothing more: sending
/// it again would be refused the same way. [plan] goes with it once it is
/// in; a plan that doesn't land waits for the next try (`Roster.sendOwedPlans`).
LogTo _logFor(String studentId, String name, {WorkoutPlan? plan}) {
  return (context, workout) async {
    final l = L.of(context);
    final roster = Roster.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> send() async {
      try {
        await roster.logFor(studentId, workout, plan: plan);
        messenger.snack(l.coachingLogged(name));
      } catch (error, stacktrace) {
        switch (_refusal(l, name, error)) {
          case final String why:
            messenger.snack(why);
          case null:
            reportToSentry(error, stacktrace: stacktrace);
            messenger.snack(
              l.coachingLogFailed(name),
              action: SnackBarAction(label: l.retry, onPressed: () => unawaited(send())),
            );
        }
      }
    }

    await send();
  };
}

/// What the server's refusal of a log says, for one that sending again can't
/// change; null for a failure that may pass, a rate limit's among them.
String? _refusal(L l, String name, Object error) {
  return switch (error) {
    ServerRefusal(code: 'forbidden' || 'not_found') => l.coachingLogNotClient(name),
    ServerRefusal(code: 'id_taken' || 'bad_request') => l.coachingLogRefused,
    _ => null,
  };
}
