import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' show WorkoutPause;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:heart/core/utils/visual.dart';

import '../buttons.dart';

/// Which inline picker, if any, is currently unfolded in the dialog.
enum _Unfolded { none, start, end }

/// Opens the "Edit start and end times" dialog. Works entirely in local time: the
/// caller passes local [start]/[end] and receives local values back through
/// [onSave], which fires once (batching both fields) when the user taps Save.
/// Returns after the dialog closes.
///
/// The duration it shows leaves out [pauses] (#134), cut to the times as
/// edited, the way the server cuts them on save.
///
/// [title] and [action] stand in for "Edit start and end times" and Save where
/// the times are a step rather than an edit: a past workout's, picked before
/// it is filled in (#530), which also has to last ([needsLength]).
Future<void> showAdjustTimesDialog(
  BuildContext context, {
  required DateTime start,
  required DateTime? end,
  required Future<void> Function(DateTime start, DateTime? end) onSave,
  Iterable<WorkoutPause> pauses = const [],
  String? title,
  String? action,
  bool needsLength = false,
}) {
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AdjustTimesDialog(
      start: start,
      end: end,
      onSave: onSave,
      pauses: pauses,
      title: title,
      action: action,
      needsLength: needsLength,
    ),
  );
}

class _AdjustTimesDialog extends StatefulWidget {
  final DateTime start;
  final DateTime? end;
  final Future<void> Function(DateTime start, DateTime? end) onSave;
  final Iterable<WorkoutPause> pauses;
  final String? title;
  final String? action;
  final bool needsLength;

  const new({
    required this.start,
    required this.end,
    required this.onSave,
    required this.pauses,
    this.title,
    this.action,
    required this.needsLength,
  });

  @override
  State<_AdjustTimesDialog> createState() => _AdjustTimesDialogState();
}

class _AdjustTimesDialogState extends State<_AdjustTimesDialog> {
  late final _start = ValueNotifier<DateTime>(widget.start);
  late final _end = ValueNotifier<DateTime?>(widget.end);
  final _unfolded = ValueNotifier<_Unfolded>(.none);
  final _saving = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _unfolded.dispose();
    _saving.dispose();
    super.dispose();
  }

  /// The times as the open row found them. A wheel tells of every notch it
  /// passes, so a move is worked out from here and never from the notch
  /// before: scrolled past and back again, it ends where it would have anyway
  /// (#738).
  late ({DateTime start, DateTime? end}) _from = (start: widget.start, end: widget.end);

  void _open() => _from = (start: _start.value, end: _end.value);

  /// Past this, an end away from its start is the day being moved, and not a
  /// longer workout.
  static const _longest = Duration(hours: 12);

  Duration get _length {
    return switch (_from) {
      (:final start, end: final DateTime end) => end.difference(start),
      _ => .zero,
    };
  }

  /// Now, to the minute, as the wheels pick it.
  static DateTime _thisMinute() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  /// A workout being filled in after the fact ([needsLength]) keeps its
  /// length when its start moves: picking yesterday's evening carries the end
  /// along, rather than leaving it at now and making a thirty-hour session. A
  /// finished workout's times move one at a time.
  void _moveStart(DateTime start) {
    _start.value = start;
    if (widget.needsLength && _end.value != null) _end.value = start.add(_length);
  }

  /// Its end makes it longer or shorter, and takes the start along when it
  /// goes to or before it, or so far past it that another day was meant: held
  /// at the start instead, the wheel went back by itself to the day it was
  /// scrolled away from (#738).
  void _moveEnd(DateTime end) {
    _end.value = end;
    if (!widget.needsLength) return;
    final start = _from.start;
    _start.value = switch (end.isAfter(start) && end.difference(start) < _longest) {
      true => start,
      false => end.subtract(_length),
    };
  }

  /// The day and time in the reader's language, "Wed, Nov 4, 1:26 AM":
  /// never an ISO date, which reads as a database's.
  String _formatValue(DateTime dt) => DateFormat.MMMEd(L.of(context).localeName).add_jm().format(dt);

  /// [start]..[end] less the part of every pause that falls inside it.
  Duration _trained(DateTime start, DateTime end) {
    final paused = widget.pauses.fold(Duration.zero, (sum, pause) {
      final from = pause.start.isAfter(start) ? pause.start : start;
      final to = pause.end.isBefore(end) ? pause.end : end;
      return to.isAfter(from) ? sum + to.difference(from) : sum;
    });
    return end.difference(start) - paused;
  }

  /// Duration as a running clock (`m:ss`, or `h:mm:ss` past an hour).
  String _formatDuration(Duration d) {
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$minutes:$seconds';
    }
    return '${d.inMinutes.remainder(60)}:$seconds';
  }

  void _toggle(_Unfolded which) {
    _open();
    _unfolded.value = _unfolded.value == which ? .none : which;
  }

  Future<void> _save() async {
    final end = _end.value;
    final l = L.of(context);
    final refusal = switch (end) {
      DateTime end when end.isBefore(_start.value) => l.endBeforeStart,
      // the wheels can meet: a workout of no time at all is no workout
      DateTime end when widget.needsLength && !end.isAfter(_start.value) => l.endAfterStart,
      _ => null,
    };
    if (refusal != null) {
      ScaffoldMessenger.maybeOf(context)?.snack(refusal);
      return;
    }
    _saving.value = true;
    await widget.onSave(_start.value, end);
    if (mounted) Navigator.of(context).pop();
  }

  /// Non-Cupertino path: sequential Material date + time popups. Same batching
  /// flow as the wheel — it only updates the notifier; nothing persists until Save.
  Future<void> _pickMaterial(
    BuildContext context, {
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
    DateTime? minimum,
    DateTime? maximum,
  }) async {
    _open();
    final date = await showDatePicker(
      context: context,
      initialDate: _clamp(initial, minimum, maximum),
      firstDate: DateUtils.dateOnly(minimum ?? DateTime(2000)),
      lastDate: DateUtils.dateOnly(maximum ?? DateTime.now()),
    );
    if (date == null || !context.mounted) return;
    // the day is picked by now: no to a new time keeps the old one, and not
    // the old day with it (#738)
    final time = await showTimePicker(context: context, initialTime: .fromDateTime(initial));
    if (!mounted) return;
    final picked = switch (time) {
      TimeOfDay(:final hour, :final minute) => DateTime(date.year, date.month, date.day, hour, minute),
      // to the second as it was
      null => initial.copyWith(year: date.year, month: date.month, day: date.day),
    };
    if (time == null && picked == initial) return;
    onChanged(_clamp(picked, minimum, maximum));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :brightness, :colorScheme, :platform) = Theme.of(context);
    final L(:adjustTimes, :duration, :startTime, :endTime, :save, :close) = L.of(context);
    // iOS/macOS get the inline Cupertino wheel; everywhere else the Cupertino
    // date picker misbehaves, so fall back to Material's popup date + time pickers.
    final cupertino = switch (platform) {
      .iOS || .macOS => true,
      _ => false,
    };

    return Dialog(
      insetPadding: const .symmetric(horizontal: 16),
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(16))),
      // capped like the app's other dialogs: uncapped, on an iPad it ran the
      // full width of the screen, a date wheel adrift in 1100pt of panel
      constraints: const BoxConstraints(maxWidth: dialogWidth),
      child: Padding(
        padding: const .fromLTRB(4, 4, 4, 12),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: _saving,
              builder: (context, saving, _) {
                return Row(
                  children: [
                    IconButton(
                      tooltip: close,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: saving ? null : () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(widget.title ?? adjustTimes, textAlign: .center, style: textTheme.titleMedium),
                    ),
                    switch (saving) {
                      true => const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                      false => Padding(
                        padding: const .only(right: 4.0),
                        child: PrimaryButton.shrunk(
                          backgroundColor: colorScheme.secondaryContainer,
                          onPressed: _save,
                          child: Text(widget.action ?? save),
                        ),
                      ),
                    },
                  ],
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_start, _end]),
              builder: (context, _) {
                final end = _end.value;
                if (end == null) return const SizedBox.shrink();
                return Padding(
                  padding: const .symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(duration, style: textTheme.titleMedium),
                      Text(_formatDuration(_trained(_start.value, end)), style: textTheme.titleMedium),
                    ],
                  ),
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_start, _end, _unfolded]),
              builder: (context, _) {
                // start can't land after the end (nor in the future when open),
                // unless the end goes with it: held there, the wheel couldn't
                // come forward again from a day it was scrolled back to (#738)
                final maximum = switch (widget.needsLength) {
                  // the end goes no later than now, and the length stays
                  true => _thisMinute().subtract(_length),
                  false => _end.value ?? DateTime.now(),
                };
                final expanded = cupertino && _unfolded.value == .start;
                return Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    _TimeRow(
                      label: startTime,
                      value: _formatValue(_start.value),
                      expanded: expanded,
                      onTap: switch (cupertino) {
                        true => () => _toggle(.start),
                        false => () => _pickMaterial(
                          context,
                          initial: _start.value,
                          maximum: maximum,
                          onChanged: _moveStart,
                        ),
                      },
                    ),
                    if (cupertino)
                      _Picker(
                        expanded: expanded,
                        brightness: brightness,
                        initial: _start.value,
                        maximum: maximum,
                        onChanged: _moveStart,
                      ),
                  ],
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_start, _end, _unfolded]),
              builder: (context, _) {
                final end = _end.value;
                if (end == null) return const SizedBox.shrink();
                final expanded = cupertino && _unfolded.value == .end;
                final minimum = widget.needsLength ? null : _start.value;
                return Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    _TimeRow(
                      label: endTime,
                      value: _formatValue(end),
                      expanded: expanded,
                      onTap: switch (cupertino) {
                        true => () => _toggle(.end),
                        false => () => _pickMaterial(
                          context,
                          initial: end,
                          minimum: minimum,
                          maximum: DateTime.now(),
                          onChanged: _moveEnd,
                        ),
                      },
                    ),
                    if (cupertino)
                      _Picker(
                        expanded: expanded,
                        brightness: brightness,
                        initial: end,
                        minimum: minimum,
                        maximum: DateTime.now(),
                        onChanged: _moveEnd,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A label + linkified value row; tapping it unfolds the matching picker.
class _TimeRow extends StatelessWidget {
  final String label;
  final String value;
  final bool expanded;
  final VoidCallback onTap;

  const new({required this.label, required this.value, required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Text(label, style: textTheme.titleMedium),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                color: expanded ? colorScheme.primary : colorScheme.primary.withValues(alpha: .85),
                fontWeight: expanded ? .bold : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline date-time wheel, animating open/closed. Cupertino-only: Material
/// has no inline combined date+time equivalent, so those platforms use the
/// [showDatePicker]/[showTimePicker] popup flow instead.
class _Picker extends StatelessWidget {
  final bool expanded;
  final Brightness brightness;
  final DateTime initial;
  final DateTime? minimum;
  final DateTime? maximum;
  final ValueChanged<DateTime> onChanged;

  const new({
    required this.expanded,
    required this.brightness,
    required this.initial,
    required this.onChanged,
    this.minimum,
    this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: .topCenter,
      child: switch (expanded) {
        false => const SizedBox(width: double.infinity),
        true => SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(brightness: brightness),
            child: CupertinoDatePicker(
              mode: .dateAndTime,
              initialDateTime: _clamp(initial, minimum, maximum),
              minimumDate: minimum,
              maximumDate: maximum,
              use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
              onDateTimeChanged: onChanged,
            ),
          ),
        ),
      },
    );
  }
}

DateTime _clamp(DateTime value, DateTime? lo, DateTime? hi) {
  if (lo != null && value.isBefore(lo)) return lo;
  if (hi != null && value.isAfter(hi)) return hi;
  return value;
}
