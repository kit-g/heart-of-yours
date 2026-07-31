import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';
import 'package:intl/intl.dart';

import '../buttons.dart';

/// Which inline picker, if any, is currently unfolded in the dialog.
enum _Unfolded { none, start, end }

/// Opens the "Adjust Start/End Time" dialog. Works entirely in local time: the
/// caller passes local [start]/[end] and receives local values back through
/// [onSave], which fires once (batching both fields) when the user taps Save.
/// Returns after the dialog closes.
Future<void> showAdjustTimesDialog(
  BuildContext context, {
  required DateTime start,
  required DateTime? end,
  required Future<void> Function(DateTime start, DateTime? end) onSave,
}) {
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AdjustTimesDialog(start: start, end: end, onSave: onSave),
  );
}

class _AdjustTimesDialog extends StatefulWidget {
  final DateTime start;
  final DateTime? end;
  final Future<void> Function(DateTime start, DateTime? end) onSave;

  const _AdjustTimesDialog({required this.start, required this.end, required this.onSave});

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

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :brightness, :colorScheme) = Theme.of(context);
    final L(:adjustTimes, :duration, :startTime, :endTime, :save) = L.of(context);

    return Dialog(
      insetPadding: const .symmetric(horizontal: 16),
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(16))),
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
                      Text(_formatDuration(end.difference(_start.value)), style: textTheme.titleMedium),
                    ],
                  ),
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_start, _end, _unfolded]),
              builder: (context, _) {
                final expanded = _unfolded.value == .start;
                return Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    _TimeRow(
                      label: startTime,
                      value: _formatValue(_start.value),
                      expanded: expanded,
                      onTap: () => _toggle(.start),
                    ),
                    _Picker(
                      expanded: expanded,
                      brightness: brightness,
                      initial: _start.value,
                      // start can't land after the end (nor in the future when open)
                      maximum: _end.value ?? DateTime.now(),
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
                final expanded = _unfolded.value == .end;
                return Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .stretch,
                  children: [
                    _TimeRow(
                      label: endTime,
                      value: _formatValue(end),
                      expanded: expanded,
                      onTap: () => _toggle(.end),
                    ),
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

  const _TimeRow({required this.label, required this.value, required this.expanded, required this.onTap});

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

/// The inline date-time wheel, animating open/closed. Uses [CupertinoDatePicker]
/// on every platform — Material has no inline combined date+time equivalent, and
/// the app already leans on Cupertino wheels for its pickers.
class _Picker extends StatelessWidget {
  final bool expanded;
  final Brightness brightness;
  final DateTime initial;
  final DateTime? minimum;
  final DateTime? maximum;
  final ValueChanged<DateTime> onChanged;

  const _Picker({
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

  static DateTime _clamp(DateTime value, DateTime? lo, DateTime? hi) {
    if (lo != null && value.isBefore(lo)) return lo;
    if (hi != null && value.isAfter(hi)) return hi;
    return value;
  }
}
