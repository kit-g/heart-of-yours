/// Coaching messages (#556): one conversation per connection, sealed on the
/// device before it goes anywhere. A student reads theirs over the app; a
/// coach reads theirs in Coaching, beside the inbox on a wide window.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/message_runs.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/in_view.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/message_text.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

part 'actions.dart';

/// The conversation of [connectionId] as a page of its own.
class ThreadPage extends StatelessWidget {
  final String connectionId;

  /// Who it is with, when the caller knows better than the server.
  final String? name;

  /// Opens a workout a message is about, where there's somewhere to open it.
  final WorkoutOpeners? onOpenWorkout;

  const new({super.key, required this.connectionId, this.name, this.onOpenWorkout});

  @override
  Widget build(BuildContext context) {
    final thread = Messages.watch(context).threadOf(connectionId);
    return Scaffold(
      appBar: AppBar(
        title: Text(threadName(context, thread, connectionId: connectionId, fallback: name)),
        actions: [ThreadMenu(connectionId: connectionId)],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: .topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: threadWidth),
            child: ThreadView(key: ValueKey(connectionId), connectionId: connectionId, onOpenWorkout: onOpenWorkout),
          ),
        ),
      ),
    );
  }
}

/// [child] with how many messages wait unread, as the inbox shows them, the
/// count said as unread to a screen reader. Nothing over it at none.
class UnreadBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const new({super.key, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    final colorScheme = Theme.of(context).colorScheme;
    return Badge(
      label: Text('$count', semanticsLabel: L.of(context).messagesUnread(count)),
      backgroundColor: colorScheme.primary,
      textColor: colorScheme.onPrimary,
      child: child,
    );
  }
}

/// How wide a conversation grows: past this, bubbles drift too far apart to
/// read as a back and forth.
const threadWidth = 720.0;

/// Who a conversation is with: the name the server holds for them, else the
/// one [fallback] gives, else the one their connection carries, else the role
/// they play for this person. Before the thread is read, [connectionId] says
/// which conversation it is.
String threadName(BuildContext context, Thread? thread, {String? connectionId, String? fallback}) {
  final l = L.of(context);
  final coaching = Coaching.of(context);
  final connection = thread?.connectionId ?? connectionId;
  final student = coaching.coaches.any((each) => each.connectionId == connection);
  final named = _connectionOf(context, connection)?.name;
  return switch ((thread?.otherName?.trim(), fallback?.trim(), named?.trim())) {
    (final String name, _, _) when name.isNotEmpty => name,
    (_, final String name, _) when name.isNotEmpty => name,
    (_, _, final String name) when name.isNotEmpty => name,
    _ when student => switch (connection) {
      final String id => Preferences.of(context).coachName(id) ?? l.yourCoach,
      null => l.yourCoach,
    },
    _ => l.coachingClientUnnamed,
  };
}

/// The coaches a student can write to: live or paused, with a connection to
/// write in.
List<Connection> coachesToWrite(Coaching coaching) {
  return [
    for (final coach in coaching.coaches)
      if ((coach.connectionId, coach.status) case (String(), ConnectionStatus.active || ConnectionStatus.paused)) coach,
  ];
}

/// A coach as their student names them: as their profile does now, else as
/// their invitation did on this device.
String coachName(BuildContext context, Connection coach) {
  return switch ((coach.name?.trim(), coach.connectionId)) {
    (final String name, _) when name.isNotEmpty => name,
    (_, final String id) => Preferences.of(context).coachName(id) ?? L.of(context).yourCoach,
    _ => L.of(context).yourCoach,
  };
}

/// Where opening a conversation stands.
enum _Opening { opening, open, failed }

/// The conversation of [connectionId]: its messages, oldest at the top, and
/// the box to write in. Opens the thread on the server the first time.
class ThreadView extends StatefulWidget {
  final String connectionId;

  /// Opens a workout a message is about, where there's somewhere to open it.
  final WorkoutOpeners? onOpenWorkout;

  const new({super.key, required this.connectionId, this.onOpenWorkout});

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _opening = ValueNotifier(_Opening.opening);
  final _text = TextEditingController();
  late final Messages _messages;
  String? _threadId;

  @override
  void initState() {
    super.initState();
    _messages = Messages.of(context);
    _text.addListener(_keepDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    if (_threadId case final String id) _messages.close(id);
    _text
      ..removeListener(_keepDraft)
      ..dispose();
    _opening.dispose();
    super.dispose();
  }

  void _keepDraft() {
    if (_threadId case final String id) _messages.keepDraft(id, _text.text);
  }

  Future<void> _open() async {
    if (!mounted) return;
    _opening.value = .opening;
    try {
      final thread = await _messages.threadFor(widget.connectionId);
      if (!mounted) return;
      _threadId = thread.id;
      // what was being written here before, kept across a fold
      _text.text = _messages.draft(thread.id);
      _opening.value = .open;
      await _messages.open(thread.id);
      if (mounted) unawaited(_readSubjects(thread.id));
    } catch (_) {
      if (mounted) _opening.value = .failed;
    }
  }

  /// A coach's device names what a client's message is about from that
  /// client's workouts, which nothing may have read yet, or not as far back:
  /// read when a message here, or the one being written, is about one this
  /// device doesn't hold.
  Future<void> _readSubjects(String threadId) async {
    final roster = Provider.of<Roster?>(context, listen: false);
    final subjects = {
      ..._messages.thread(threadId).messages.map((each) => each.subject).nonNulls,
      ?_messages.about(widget.connectionId),
    };
    if (roster == null || subjects.isEmpty) return;
    // opened from a push, before anything read the roster
    if (roster.client(widget.connectionId) == null && roster.status == .idle) await roster.load();
    final client = roster.client(widget.connectionId);
    if (client == null) return;
    final id = client.studentId;
    bool missing(MessageSubject subject) => _find(subject, roster.heldOf(id), own: false) == null;
    if (!subjects.any(missing)) return;
    // the record may predate them, or have failed
    if (roster.recordStatus(id) != .loading) await roster.loadRecord(id);
    // a workout further back is read by itself
    await Future.wait([
      for (final subject in subjects.where(missing))
        if (subject.type == .workout) roster.loadWorkout(id, subject.id),
    ]);
  }

  Future<void> _send() async {
    final threadId = _threadId;
    final text = _text.text.trim();
    if (threadId == null || text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = L.of(context).messagesSendFailed;
    _text.clear();
    try {
      await _messages.send(threadId, text);
    } catch (_) {
      // nothing was kept: the words go back where they were written
      if (_text.text.isEmpty) _text.text = text;
      messenger.snack(failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ValueListenableBuilder(
      valueListenable: _opening,
      builder: (context, opening, _) {
        // on screen from the moment it opens, so a push about it says
        // nothing (#724), and not at all once opening failed
        return InView(
          subject: (.thread, widget.connectionId),
          shown: opening != .failed,
          child: switch ((opening, _threadId)) {
            (.open, final String threadId) => _Conversation(
              threadId: threadId,
              connectionId: widget.connectionId,
              text: _text,
              onSend: _send,
              onOpenWorkout: widget.onOpenWorkout,
            ),
            (.failed, _) => _Note(
              icon: Icons.cloud_off_rounded,
              title: l.messagesFailed,
              action: OutlinedButton(onPressed: _open, child: Text(l.retry)),
            ),
            _ => const Center(child: CircularProgressIndicator.adaptive()),
          },
        );
      },
    );
  }
}

class _Conversation extends StatelessWidget {
  final String threadId;
  final String connectionId;
  final TextEditingController text;
  final VoidCallback onSend;
  final WorkoutOpeners? onOpenWorkout;

  const new({
    required this.threadId,
    required this.connectionId,
    required this.text,
    required this.onSend,
    this.onOpenWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final messages = Messages.watch(context);
    final thread = messages.thread(threadId);
    final closed = thread.closed || _ended(_connectionOf(context, connectionId, listen: true));
    // a deletion leaves a line where the messages before it were
    final cleared = switch (messages.lookup(threadId)) {
      Thread(clearedAt: DateTime(), :final clearedBy) && final inbox =>
        clearedBy == messages.userId ? l.messagesClearedByYou : l.messagesClearedBy(threadName(context, inbox)),
      _ => null,
    };
    // newest at the bottom, where the eye and the box are
    final shown = thread.messages.reversed.toList();
    final places = const MessageRuns().of([for (final each in thread.messages) (at: each.at, mine: each.mine)]);
    return Column(
      children: [
        Expanded(
          child: switch ((shown, thread.status)) {
            ([], .idle || .loading) => const Center(child: CircularProgressIndicator.adaptive()),
            ([], .failed) => _Note(
              icon: Icons.cloud_off_rounded,
              title: l.messagesFailed,
              action: OutlinedButton(onPressed: () => messages.refresh(threadId), child: Text(l.retry)),
            ),
            ([], _) => switch (cleared) {
              final String cleared => _Note(icon: Icons.delete_sweep_outlined, title: cleared),
              null => _Note(icon: Icons.lock_outline_rounded, title: l.messagesEmpty, body: l.messagesEmptyBody),
            },
            _ => RefreshIndicator.adaptive(
              onRefresh: () => messages.pull(threadId),
              child: ListView.builder(
                key: AppKeys.thread,
                reverse: true,
                padding: const .symmetric(horizontal: 12, vertical: 8),
                itemCount: shown.length + 1,
                itemBuilder: (context, index) => switch (index < shown.length) {
                  true => Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      if (places[shown.length - 1 - index].newDay) _Day(at: shown[index].at),
                      _Bubble(
                        message: shown[index],
                        place: places[shown.length - 1 - index],
                        connectionId: connectionId,
                        onOpenWorkout: onOpenWorkout,
                      ),
                    ],
                  ),
                  false => switch (thread.hasOlder) {
                    true => Center(
                      child: TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                        onPressed: () => messages.older(threadId),
                        child: Text(l.messagesOlder),
                      ),
                    ),
                    false => switch (cleared) {
                      final String cleared => Padding(
                        padding: const .symmetric(vertical: 12),
                        child: Text(
                          cleared,
                          key: AppKeys.threadCleared,
                          textAlign: .center,
                          style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      null => const SizedBox(height: 8),
                    },
                  },
                },
              ),
            ),
          },
        ),
        switch (closed) {
          true => _Closed(),
          false => _Composer(connectionId: connectionId, text: text, onSend: onSend),
        },
      ],
    );
  }
}

/// A day's heading, above its first message.
class _Day extends StatelessWidget {
  final DateTime at;

  const new({required this.at});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final day = DateUtils.dateOnly(at.toLocal());
    final today = DateUtils.dateOnly(clock.now());
    // counted in calendar days: a day a clock change shortened is still a day
    final ago = DateTime.utc(today.year, today.month, today.day).difference(.utc(day.year, day.month, day.day)).inDays;
    final label = switch (ago) {
      0 => l.messagesToday,
      1 => l.messagesYesterday,
      _ when day.year == today.year => DateFormat.MMMMEEEEd(locale).format(day),
      _ => DateFormat.yMMMMEEEEd(locale).format(day),
    };
    return Padding(
      padding: const .only(top: 16, bottom: 8),
      child: Center(
        child: Semantics(
          header: true,
          child: Text(label, style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final MessagePlace place;
  final String connectionId;
  final WorkoutOpeners? onOpenWorkout;

  const new({required this.message, required this.place, required this.connectionId, this.onOpenWorkout});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final mine = message.mine;
    final (background, foreground, quiet, link) = switch (mine) {
      true => (
        colorScheme.primary,
        colorScheme.onPrimary,
        colorScheme.onPrimary.withValues(alpha: .72),
        colorScheme.onPrimary,
      ),
      false => (
        // the design system's fill: surfaceContainerHigh is the page itself
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurface,
        colorScheme.onSurfaceVariant,
        colorScheme.primary,
      ),
    };
    final time = DateFormat.jm(Localizations.localeOf(context).toString()).format(message.at.toLocal());
    final words = textTheme.bodyLarge?.copyWith(color: foreground) ?? TextStyle(color: foreground);
    final (text, style, leading) = switch (message.opened) {
      Opened(:final text) => (text, words, null),
      // says what opens it: the device has already asked for its key
      Locked() => (
        switch (mine) {
          true => l.messagesLockedYours,
          false => l.messagesLocked,
        },
        words.copyWith(fontStyle: .italic),
        Icons.key_rounded,
      ),
      Refused() => (l.messagesRefused, words.copyWith(fontStyle: .italic), Icons.block_rounded),
    };
    final (status, said) = switch ((mine, message.delivery)) {
      (false, _) => (null, null),
      (true, .sent) => (Icons.done_rounded, l.messagesSent),
      (true, .waiting) => (Icons.schedule_rounded, l.messagesWaiting),
      (true, .closed) => (null, l.messagesNotSent),
    };
    // on the writer's side a run reads as one: the corners that meet a
    // neighbour of the same run are tight, and so is the last one's bottom,
    // the run's tail
    const round = Radius.circular(18);
    const tight = Radius.circular(6);
    final top = place.firstOfRun ? round : tight;
    final radius = switch (mine) {
      true => BorderRadius.only(topLeft: round, bottomLeft: round, topRight: top, bottomRight: tight),
      false => BorderRadius.only(topRight: round, bottomRight: round, topLeft: top, bottomLeft: tight),
    };
    return Padding(
      key: AppKeys.message(message.id),
      padding: .only(
        top: switch (place.firstOfRun) {
          true => 8,
          false => 2,
        },
      ),
      child: Column(
        crossAxisAlignment: switch (mine) {
          true => .end,
          false => .start,
        },
        children: [
          // what it's about, above it: a workout or one set, opened from here
          if (message.subject case final MessageSubject subject)
            _SubjectLine(subject: subject, connectionId: connectionId, onOpenWorkout: onOpenWorkout),
          LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              // a bubble a hand can follow: never across the whole pane
              constraints: BoxConstraints(maxWidth: math.min(480, constraints.maxWidth * .8)),
              child: GestureDetector(
                onLongPressStart: switch (message.opened) {
                  Opened(:final text) => (details) => _menu(context, details.globalPosition, text),
                  _ => null,
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(color: background, borderRadius: radius),
                  child: Padding(
                    padding: const .fromLTRB(14, 8, 12, 7),
                    child: MessageText(
                      text: text,
                      style: style,
                      linkStyle: style.copyWith(color: link, decoration: .underline, decorationColor: link),
                      time: time,
                      // tight: the time is a quiet stamp, never a second line of words
                      timeStyle:
                          textTheme.labelSmall?.copyWith(
                            color: quiet,
                            fontSize: 11,
                            letterSpacing: 0,
                            height: 1,
                            fontFeatures: const [.tabularFigures()],
                          ) ??
                          TextStyle(color: quiet, fontSize: 11),
                      status: status,
                      leading: leading,
                      onLink: switch (message.opened) {
                        Opened() => _open,
                        _ => null,
                      },
                      linkAction: l.messagesOpenLink,
                      semanticsLabel: [text, time, ?said].join(', '),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (message.delivery == .closed && mine)
            Padding(
              padding: const .only(top: 2, right: 4),
              child: Text(l.messagesNotSent, style: textTheme.labelSmall?.copyWith(color: colorScheme.error)),
            ),
        ],
      ),
    );
  }

  static Future<void> _open(Uri uri) => launchUrl(uri, mode: .externalApplication);

  Future<void> _menu(BuildContext context, Offset at, String text) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final picked = await showMenu<_MessageAction>(
      context: context,
      position: menuAt(context, at),
      items: [
        PopupMenuItem(value: .copy, child: Text(l.messagesCopy)),
        // only what the other person wrote is theirs to answer for
        if (!message.mine) PopupMenuItem(key: AppKeys.messageReport, value: .report, child: Text(l.messagesReport)),
      ],
    );
    switch (picked) {
      case .copy:
        // needs nothing of the bubble, which may have gone meanwhile
        await Clipboard.setData(ClipboardData(text: text));
        messenger?.snack(l.copiedToClipboard);
      case .report:
        if (!context.mounted) return;
        if (Messages.of(context).lookup(message.item.threadId) case final Thread thread) {
          await showReportSheet(context, thread, name: threadName(context, thread), message: message);
        }
      case null:
        break;
    }
  }
}

/// What a long press on a message offers.
enum _MessageAction { copy, report }

class _Composer extends StatelessWidget {
  final String connectionId;
  final TextEditingController text;
  final VoidCallback onSend;

  const new({required this.connectionId, required this.text, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messages = Messages.watch(context);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        // what the next message is about, until it's said or let go
        if (messages.about(connectionId) case final MessageSubject subject)
          Padding(
            padding: const .fromLTRB(12, 4, 12, 0),
            child: Align(
              alignment: .centerLeft,
              child: InputChip(
                key: AppKeys.messageAbout,
                avatar: Icon(_subjectIcon(subject), size: 18),
                label: Text(
                  l.messagesAbout(_subjectLabel(context, subject, _placeOf(context, subject, connectionId))),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                deleteButtonTooltipMessage: l.messagesAboutNothing,
                onDeleted: () => messages.writeAbout(connectionId, null),
              ),
            ),
          ),
        _box(l),
      ],
    );
  }

  Widget _box(L l) {
    return Padding(
      padding: const .fromLTRB(12, 4, 8, 12),
      child: Row(
        crossAxisAlignment: .end,
        spacing: 4,
        children: [
          Expanded(
            child: TextField(
              key: AppKeys.messageBox,
              controller: text,
              minLines: 1,
              maxLines: 5,
              textCapitalization: .sentences,
              decoration: InputDecoration(hintText: l.messagesHint),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: text,
            builder: (context, value, _) => IconButton(
              key: AppKeys.messageSend,
              tooltip: l.messagesSend,
              icon: const Icon(Icons.send_rounded),
              onPressed: switch (value.text.trim().isEmpty) {
                true => null,
                false => onSend,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Where a conversation's subjects open: a client's workout, for the coach
/// (the connection is known), and one of the reader's own. Either may be
/// absent where there's nowhere to open it.
typedef WorkoutOpeners = ({ValueChanged<String>? client, ValueChanged<String>? own});

/// What a message is about, above it: tapped, the workout opens, where it
/// is one this device holds and there's somewhere to open it.
class _SubjectLine extends StatelessWidget {
  final MessageSubject subject;
  final String connectionId;
  final WorkoutOpeners? onOpenWorkout;

  const new({required this.subject, required this.connectionId, this.onOpenWorkout});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final place = _placeOf(context, subject, connectionId);
    final words = l.messagesAbout(_subjectLabel(context, subject, place));
    // a client's opens as the coach reads it, one's own as History does
    final open = switch ((place, onOpenWorkout)) {
      ((:final workout, own: false, exercise: _, set: _), (client: final open?, own: _)) => () => open(workout.id),
      ((:final workout, own: true, exercise: _, set: _), (own: final open?, client: _)) => () => open(workout.id),
      _ => null,
    };
    final style = textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    return Padding(
      padding: const .only(top: 4),
      child: switch (open) {
        final VoidCallback open => TextButton.icon(
          key: AppKeys.messageSubject,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, kMinInteractiveDimension),
            padding: const .symmetric(horizontal: 8),
            foregroundColor: colorScheme.onSurfaceVariant,
            textStyle: style,
          ),
          onPressed: open,
          icon: Icon(_subjectIcon(subject), size: 16),
          label: Text(words, maxLines: 1, overflow: .ellipsis),
        ),
        null => Padding(
          key: AppKeys.messageSubject,
          padding: const .symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: .min,
            spacing: 6,
            children: [
              Icon(_subjectIcon(subject), size: 16, color: colorScheme.onSurfaceVariant),
              Flexible(
                child: Text(words, style: style, maxLines: 1, overflow: .ellipsis),
              ),
            ],
          ),
        ),
      },
    );
  }
}

IconData _subjectIcon(MessageSubject subject) {
  return switch (subject.type) {
    .workout => Icons.fitness_center_rounded,
    .exerciseSet => Icons.format_list_numbered_rounded,
  };
}

/// Where a message's subject is among the workouts this device holds: the
/// workout, and for a set its exercise and the set; own for one of the
/// reader's own.
typedef _Place = ({Workout workout, WorkoutExercise? exercise, ExerciseSet? set, bool own});

/// Where [subject] is: among a client's workouts, as the roster holds them,
/// in a conversation with a client; among the reader's own otherwise. Null
/// where this device doesn't hold it.
_Place? _placeOf(BuildContext context, MessageSubject subject, String connectionId) {
  final roster = Provider.of<Roster?>(context);
  if (roster?.client(connectionId) case final ClientSummary client) {
    return _find(subject, roster!.heldOf(client.studentId), own: false);
  }
  final workouts = Provider.of<Workouts?>(context);
  return switch ((subject.type, workouts)) {
    (_, null) => null,
    (.workout, final workouts?) => switch (workouts.lookup(subject.id)) {
      final Workout workout when workout.isCompleted => (workout: workout, exercise: null, set: null, own: true),
      _ => null,
    },
    (.exerciseSet, final workouts?) => _find(subject, workouts.history, own: true),
  };
}

_Place? _find(MessageSubject subject, Iterable<Workout> workouts, {required bool own}) {
  return switch (subject.type) {
    .workout =>
      workouts
          .where((workout) => workout.id == subject.id)
          .map<_Place>((workout) => (workout: workout, exercise: null, set: null, own: own))
          .firstOrNull,
    .exerciseSet =>
      workouts
          .expand(
            (workout) => workout.expand(
              (exercise) => exercise
                  .where((set) => set.id == subject.id)
                  .map<_Place>((set) => (workout: workout, exercise: exercise, set: set, own: own)),
            ),
          )
          .firstOrNull,
  };
}

/// What [subject] is, in words: "Squat (Barbell), 60 kg x 5", "Day A, Tue
/// 12 Nov", or only a workout or a set where this device doesn't hold it.
/// A set by what was done in it, never its place: the two devices may hold
/// different sets around it.
String _subjectLabel(BuildContext context, MessageSubject subject, _Place? place) {
  final l = L.of(context);
  return switch ((subject.type, place)) {
    (_, (workout: _, exercise: final WorkoutExercise exercise, set: final ExerciseSet set, own: _)) =>
      l.messagesSubjectSet(
        exercise.exercise.name,
        setInWords(
          l,
          RecordFormats(
            l: l,
            prefs: Preferences.of(context),
            unit: Exercises.of(context).unitFor(exercise.exercise.id),
            category: exercise.exercise.category,
          ),
          (weight: set.weight, reps: set.reps, duration: set.duration, distance: set.distance),
        ),
      ),
    (_, (:final workout, exercise: _, set: _, own: _)) => l.messagesSubjectWorkout(
      workoutTitle(l, workout),
      DateFormat.MMMEd(l.localeName).format(workout.start.toLocal()),
    ),
    (.workout, null) => l.messagesSubjectSomeWorkout,
    (.exerciseSet, null) => l.messagesSubjectSomeSet,
  };
}

class _Closed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      padding: const .all(16),
      child: Text(
        L.of(context).messagesClosed,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        textAlign: .center,
      ),
    );
  }
}

/// What a conversation says in place of messages.
class _Note extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const new({required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const .all(32),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium, textAlign: .center),
            if (body case final String body) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: .center,
              ),
            ],
            if (action case final Widget action) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}
