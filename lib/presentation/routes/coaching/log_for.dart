part of 'coaching.dart';

/// The way to log a session a coach trained with a client (#560): it becomes
/// the client's workout, in their history, marked as logged by the coach.
class _LogForTile extends StatelessWidget {
  final ClientSummary client;

  /// Opens the workout to fill in.
  final ValueChanged<PastWorkout> onLog;

  const new({required this.client, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListTile(
      key: AppKeys.coachingLogFor,
      leading: const Icon(Icons.edit_calendar_outlined),
      title: Text(l.coachingLogWorkout),
      subtitle: Text(l.coachingLogWorkoutBody),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _start(context),
    );
  }

  /// Which of their program's sessions it was, when they follow one, then
  /// when it was, then the workout to fill in.
  Future<void> _start(BuildContext context) async {
    final l = L.of(context);
    final name = _clientName(l, client);
    final logTo = _logFor(client.studentId, name);
    final sessions = await _sessionsOf(context);
    if (!context.mounted) return;
    final Workout workout;
    switch (sessions) {
      case (:final sessions, :final next, :final programId) when sessions.isNotEmpty:
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
        workout = switch (picked) {
          _FromSession(:final session) => Workout.fromExercises(
            session.toWorkout(),
            name: session.name,
            templateId: session.id,
            programId: programId,
          ),
          _Blank() => Workout(),
        };
      case _:
        workout = Workout();
    }
    await logPastWorkout(
      context,
      workout: workout,
      logTo: logTo,
      loggingFor: name,
      open: onLog,
    );
  }

  /// The sessions of the program they follow, the next one marked: read when
  /// this device hasn't yet. None when they follow none, or it can't be read.
  Future<({List<Template> sessions, String? next, String? programId})> _sessionsOf(BuildContext context) async {
    final programId = client.programId;
    if (programId == null) return (sessions: const <Template>[], next: null, programId: null);
    final programs = ClientPrograms.of(context);
    if (programs.view(programId) == null) {
      try {
        await programs.open(client.studentId, programId);
      } catch (_) {
        // a blank workout still logs
      }
    }
    final view = programs.view(programId);
    return (
      sessions: view?.sessions ?? const <Template>[],
      next: switch (view?.position['next']) {
        final String id => id,
        _ => null,
      },
      programId: programId,
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
/// by then, so what happens is said in a snackbar, and a failure offers to
/// send it again under the same id, which the server takes once.
LogTo _logFor(String studentId, String name) {
  return (context, workout) async {
    final l = L.of(context);
    final roster = Roster.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> send() async {
      try {
        await roster.logFor(studentId, workout);
        messenger.snack(l.coachingLogged(name));
      } catch (error, stacktrace) {
        reportToSentry(error, stacktrace: stacktrace);
        messenger.snack(
          l.coachingLogFailed(name),
          action: SnackBarAction(label: l.retry, onPressed: () => unawaited(send())),
        );
      }
    }

    await send();
  };
}
