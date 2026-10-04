import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' show WorkoutPause;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:heart/core/utils/visual.dart';

import '../buttons.dart';

/// Which inline picker, if any, is currently unfolded in the dialog.
enum _Unfolded { none, start, end }

/// Opens the "Adjust Start/End Time" dialog. Works entirely in local time: the
/// caller passes local [start]/[end] and receives local values back through
/// [onSave], which fires once (batching both fields) when the user taps Save.
/// Returns after the dialog closes.
///
/// The duration it shows leaves out [pauses] (#134), cut to the times as
/// edited, the way the server cuts them on save.
Future<void> showAdjustTimesDialog(
  BuildContext context, {
  required DateTime start,
  required DateTime? end,
  required Future<void> Function(DateTime start, DateTime? end) onSave,
  Iterable<WorkoutPause> pauses = const [],
}) {
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AdjustTimesDialog(start: start, end: end, onSave: onSave, pauses: pauses),
  );
}

class _AdjustTimesDialog extends StatefulWidget {
  final DateTime start;
  final DateTime? end;
  final Future<void> Function(DateTime start, DateTime? end) onSave;
  final Iterable<WorkoutPause> pauses;

  const new({required this.start, required this.end, required this.onSave, required this.pauses});

  @override
  State<_AdjustTimesDialog> createState() => _AdjustTimesDialogState();
}

class _AdjustTimesDialogState extends State<_AdjustTimesDialog> {
  late final _start = ValueNotifier<DateTime>(widget.start);
  late final _end = ValueNotifier<DateTime?>(widget.end);
  final _unfolded = ValueNotifier<_Unfolded>(.none);
  final _saving = ValueNotifier<bool>(false);

  static final _valueFormat = DateFormat('yyyy-MM-dd, ').add_jm();

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _unfolded.dispose();
    _saving.dispose();
    super.dispose();
  }

  String _formatValue(DateTime dt) => _valueFormat.format(dt);

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
    _unfolded.value = _unfolded.value == which ? .none : which;
  }

  Future<void> _save() async {
    final end = _end.value;
    if (end != null && end.isBefore(_start.value)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(L.of(context).endBeforeStart)),
      );
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
    final date = await showDatePicker(
      context: context,
      initialDate: _clamp(initial, minimum, maximum),
      firstDate: DateUtils.dateOnly(minimum ?? DateTime(2000)),
      lastDate: DateUtils.dateOnly(maximum ?? DateTime.now()),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: .fromDateTime(initial));
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
                      child: Text(adjustTimes, textAlign: .center, style: textTheme.titleMedium),
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
                          child: Text(save),
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
                // start can't land after the end (nor in the future when open)
                final maximum = _end.value ?? DateTime.now();
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
                          onChanged: (value) => _start.value = value,
                        ),
                      },
                    ),
                    if (cupertino)
                      _Picker(
                        expanded: expanded,
                        brightness: brightness,
                        initial: _start.value,
                        maximum: maximum,
                        onChanged: (value) => _start.value = value,
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
                          minimum: _start.value,
                          maximum: DateTime.now(),
                          onChanged: (value) => _end.value = value,
                        ),
                      },
                    ),
                    if (cupertino)
                      _Picker(
                        expanded: expanded,
                        brightness: brightness,
                        initial: end,
                        minimum: _start.value,
                        maximum: DateTime.now(),
                        onChanged: (value) => _end.value = value,
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
