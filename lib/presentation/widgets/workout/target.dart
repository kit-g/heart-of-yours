part of 'workout_detail.dart';

/// What a set aims for, on its row and in a template's editor (#173): the
/// faint value an empty cell shows, and the dialog that sets it.

/// The popup's choice that opens the target dialog.
final class _TargetChoice extends _SetChoice {
  const new();
}

extension on SetColumn {
  /// The measure a target names for this column.
  TargetMeasure get measure {
    return switch (this) {
      .weight => .weight,
      .reps => .reps,
      .distance => .distance,
      .duration => .duration,
    };
  }
}

/// [range] as a cell writes it, each bound through [shown]: "8", "6–10", and
/// "8+" for as many as you can.
String _rangeText(TargetRange range, String Function(num) shown) {
  return switch (range) {
    TargetRange(isExact: true, :final min) => shown(min),
    TargetRange(:final min, max: null) => '${shown(min)}+',
    TargetRange(:final min, :final num max) => '${shown(min)}–${shown(max)}',
  };
}

/// How a set's measures are written in its cells and read back out of them:
/// in the user's units, or the ones the exercise has its own of, the way the
/// cells write and read the set itself.
class _Cells {
  final Preferences prefs;
  final MeasurementUnit? override;
  final Category category;

  const new(this.prefs, this.override, this.category);

  /// [stored] (kilograms, kilometres, seconds, reps) as a cell shows it.
  String shown(TargetMeasure measure, num stored) {
    return switch (measure) {
      .reps => '${stored.round()}',
      .weight => prefs.weight(stored, unit: override),
      .distance => switch (category) {
        // a carry is written in metres or yards
        .weightedDistance => prefs.shortDistance(stored, unit: override),
        _ => prefs.distance(stored, unit: override),
      },
      .duration => stored.round().toDuration(),
    };
  }

  /// [typed] back in the stored unit; null when it says no value: blank, not a
  /// number, no reps, no time, no way.
  num? stored(TargetMeasure measure, String typed) {
    return switch (measure) {
      .reps => switch (int.tryParse(typed)) {
        final int reps when reps > 0 => reps,
        _ => null,
      },
      // 0 is a weight here as in the cells (#383): a dip without the belt
      .weight => switch (double.tryParse(typed)) {
        final double weight when weight >= 0 => switch (override ?? prefs.weightUnit) {
          .imperial => weight.asKilograms,
          .metric => weight,
        },
        _ => null,
      },
      .distance => switch (double.tryParse(typed)) {
        final double distance when distance > 0 => switch ((category, override ?? prefs.distanceUnit)) {
          (.weightedDistance, final unit) => prefs.shortDistanceStored(distance, unit: unit),
          (_, .imperial) => distance.asKilometers,
          (_, .metric) => distance,
        },
        _ => null,
      },
      .duration => switch (_secondsIn(typed)) {
        > 0 && final seconds => seconds,
        _ => null,
      },
    };
  }

  /// [set]'s target for [measure] as its empty cell shows it, faint; null when
  /// it aims at nothing there.
  String? ghost(ExerciseSet set, TargetMeasure measure) {
    return switch (set.target?[measure]) {
      final TargetRange range => _rangeText(range, (value) => shown(measure, value)),
      null => null,
    };
  }

  /// [set]'s whole target in a line, column by column, for the popup's row:
  /// "60 · 6–10". Null when there is none this build can show.
  String? summary(ExerciseSet set) {
    final ghosts = SetColumn.of(category).map((column) => ghost(set, column.measure)).nonNulls;
    return switch (ghosts.isEmpty) {
      true => null,
      false => ghosts.join(' · '),
    };
  }
}

/// "1:30" or "90" as seconds, as a duration cell reads it.
int _secondsIn(String text) {
  int part(String value) => int.tryParse(value) ?? 0;
  return switch (text.split(':')) {
    [final s] => part(s),
    [final m, final s] => part(m) * 60 + part(s),
    [final h, final m, final s] => part(h) * 3600 + part(m) * 60 + part(s),
    _ => 0,
  };
}

/// Sets what set [number] of a template aims for (#173). From and to per
/// column the exercise records; "to" left empty is an open top, "8+", and the
/// same number in both an exact one.
///
/// Returns the target to keep, [SetTarget.none] to take it away, and null when
/// the dialog was closed without a word.
Future<SetTarget?> _showTargetDialog(
  BuildContext context, {
  required ExerciseSet set,
  required int number,
  required _Cells cells,
  required String Function(SetColumn) label,
}) {
  return showBrandedDialog<SetTarget>(
    context,
    title: Text(L.of(context).setTargetTitle(number), textAlign: .center),
    content: _TargetForm(set: set, cells: cells, label: label),
  );
}

/// One column's pair of fields in the dialog.
class _TargetRow {
  final SetColumn column;
  final TextEditingController from;
  final TextEditingController to;

  /// The pair says nothing a target can hold: a "to" under its "from", or a
  /// "to" with no "from".
  final error = ValueNotifier(false);

  new(this.column, {required String from, required String to})
    : from = TextEditingController(text: from),
      to = TextEditingController(text: to);

  void dispose() {
    from.dispose();
    to.dispose();
    error.dispose();
  }
}

class _TargetForm extends StatefulWidget {
  final ExerciseSet set;
  final _Cells cells;
  final String Function(SetColumn) label;

  const new({required this.set, required this.cells, required this.label});

  @override
  State<_TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<_TargetForm> {
  late final List<_TargetRow> _rows = [
    for (final column in SetColumn.of(widget.set.category)) _row(column),
  ];

  _TargetRow _row(SetColumn column) {
    String shown(num value) => widget.cells.shown(column.measure, value);
    return switch (widget.set.target?[column.measure]) {
      TargetRange(:final min, :final max) => _TargetRow(
        column,
        from: shown(min),
        to: switch (max) {
          final num max => shown(max),
          null => '',
        },
      ),
      null => _TargetRow(column, from: '', to: ''),
    };
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ..._rows.map((row) => _fields(context, row)),
        Text(
          l.setTargetOpenTop,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        Row(
          mainAxisAlignment: .end,
          spacing: 8,
          children: [
            // only while there is a target to take away
            if (widget.set.target != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(SetTarget.none),
                child: Text(l.setTargetClear),
              ),
            PrimaryButton.shrunk(
              onPressed: _submit,
              child: Padding(
                padding: const .symmetric(horizontal: 12, vertical: 6),
                child: Text(l.save),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fields(BuildContext context, _TargetRow row) {
    final l = L.of(context);
    final label = widget.label(row.column);
    final formatters = switch (row.column) {
      .reps => _integerFormatters,
      .duration => [TimeFormatter()],
      .weight || .distance => _floatingPointFormatters,
    };

    Widget field(Key key, TextEditingController controller, String hint, {required bool hasError}) {
      return SizedBox(
        width: 72,
        child: TextField(
          key: key,
          controller: controller,
          keyboardType: switch (row.column) {
            .reps || .duration => TextInputType.number,
            .weight || .distance => const TextInputType.numberWithOptions(decimal: true),
          },
          inputFormatters: formatters,
          textAlign: .center,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            // the pair is wrong together, so the border says so and no line
            // under one field pretends it is that field's fault
            error: switch (hasError) {
              true => const SizedBox.shrink(),
              false => null,
            },
          ),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: row.error,
      builder: (context, hasError, _) {
        return Row(
          spacing: 8,
          children: [
            Expanded(child: Text(label)),
            // the row's word goes with each field: "Reps, from"
            Semantics(
              label: label,
              child: field(WorkoutDetailKeys.targetFrom(row.column), row.from, l.setTargetFrom, hasError: hasError),
            ),
            const Text('–'),
            Semantics(
              label: label,
              child: field(WorkoutDetailKeys.targetTo(row.column), row.to, l.setTargetTo, hasError: hasError),
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    var target = widget.set.target ?? SetTarget.none;
    var valid = true;
    for (final row in _rows) {
      final measure = row.column.measure;
      final from = row.from.text.trim();
      final to = row.to.text.trim();
      final (ok, range) = switch ((from, widget.cells.stored(measure, from), to, widget.cells.stored(measure, to))) {
        // nothing in either: this column aims at nothing
        ('', _, '', _) => (true, null),
        (_, final num min?, '', _) => (true, TargetRange(min: min)),
        (_, final num min?, _, final num max?) when max >= min => (true, TargetRange(min: min, max: max)),
        _ => (false, null),
      };
      row.error.value = !ok;
      valid = valid && ok;
      if (ok) target = target.withRange(measure, range);
    }
    if (valid) Navigator.of(context).pop(target);
  }
}
