part of 'workout_detail.dart';

/// The ratings the picker offers, in the half steps the server takes (#234).
/// Below 6 the guess stops being reliable, so the scale starts there.
const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

/// What the picker falls back to when the keyboard's height was never seen,
/// as with a hardware keyboard.
const _rpePickerMinHeight = 216.0;

/// Which set is being typed into, and whether its RPE picker has taken the
/// keyboard's place. Owned by the workout's [WorkoutDetail]; the set rows tell
/// it about focus, and [_RpeBar] draws from it.
class _RpeEditing extends ChangeNotifier {
  ExerciseSet? _set;
  FocusNode? _field;
  bool _picking = false;

  /// The set whose field has focus, or whose picker is open.
  ExerciseSet? get set => _set;

  /// Whether the picker is open in the keyboard's place.
  bool get picking => _picking;

  /// A field of [set] took focus — from the keyboard or from another field,
  /// which closes an open picker.
  void focus(ExerciseSet set, FocusNode field) {
    _set = set;
    _field = field;
    _picking = false;
    notifyListeners();
  }

  /// [set]'s fields lost focus. Opening the picker is what makes them lose it,
  /// so that one is not a leaving.
  void blur(ExerciseSet set) {
    if (_picking || _set != set) return;
    _set = null;
    _field = null;
    notifyListeners();
  }

  /// The picker takes the keyboard's place.
  void pick() {
    _picking = true;
    notifyListeners();
    _field?.unfocus();
  }

  /// Back to the keyboard, on the field that was being typed into.
  void type() {
    _picking = false;
    notifyListeners();
    // the field's own focus node sits under the row's, and only it brings the
    // keyboard back
    switch (_field) {
      case FocusNode field:
        (field.children.firstOrNull ?? field).requestFocus();
    }
  }

  /// Nothing being typed into any more.
  void close() {
    if (_set == null && !_picking) return;
    _set = null;
    _field = null;
    _picking = false;
    notifyListeners();
  }
}

/// RPE over the number pad (#234): while a set's field has focus, a slim bar
/// with the RPE key; the key swaps the keyboard for a 6 … 10 picker in the
/// same place. Only while the feature is on, and only on screens that rate
/// sets ([onSetRpe]); otherwise nothing at all.
///
/// In the text fields' tap group, so pressing it does not count as tapping
/// away from the field being typed into.
class _RpeBar extends StatefulWidget {
  final _RpeEditing editing;
  final void Function(ExerciseSet, double?) onSetRpe;

  const new({required this.editing, required this.onSetRpe});

  @override
  State<_RpeBar> createState() => _RpeBarState();
}

class _RpeBarState extends State<_RpeBar> with HasHaptic<_RpeBar> {
  /// The keyboard's height the last time the RPE key was pressed, so the
  /// picker takes exactly its place. A plain field: nothing redraws for it.
  double _keyboard = 0;

  /// Whether the scale is unfolded under the hint.
  final _scale = ValueNotifier(false);

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Preferences.watch(context).isOn(.rpe)) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: widget.editing,
      builder: (context, _) {
        final editing = widget.editing;
        final child = switch ((editing.set, editing.picking)) {
          (ExerciseSet set, true) => _picker(context, set),
          (ExerciseSet set, false) => _key(context, set),
          (null, _) => const SizedBox.shrink(key: ValueKey('none')),
        };

        return TapRegion(
          groupId: EditableText,
          onTapOutside: (_) {
            if (editing.picking) editing.close();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: child,
          ),
        );
      },
    );
  }

  /// The bar over the keyboard: the RPE key, with the set's rating once it
  /// has one.
  Widget _key(BuildContext context, ExerciseSet set) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final l = L.of(context);

    return Container(
      key: const ValueKey('key'),
      decoration: _panel(colorScheme),
      padding: const .symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: .end,
        children: [
          PrimaryButton.shrunk(
            key: WorkoutDetailKeys.rpeKey,
            backgroundColor: colorScheme.surfaceContainerHighest,
            margin: const .symmetric(horizontal: 16, vertical: 6),
            onPressed: () {
              final view = View.of(context);
              _keyboard = view.viewInsets.bottom / view.devicePixelRatio;
              widget.editing.pick();
            },
            child: Text(switch (set.rpe) {
              double rpe => l.rpeValue(_rpeText(context, rpe)),
              null => l.rpe,
            }),
          ),
        ],
      ),
    );
  }

  /// The picker, where the keyboard was.
  Widget _picker(BuildContext context, ExerciseSet set) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = max(_keyboard - bottom, _rpePickerMinHeight);

    return Container(
      key: const ValueKey('picker'),
      decoration: _panel(colorScheme),
      constraints: BoxConstraints(minHeight: height),
      padding: .fromLTRB(16, 8, 16, 12 + bottom),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.aboutRpe,
                visualDensity: .compact,
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                ),
                icon: const Icon(Icons.question_mark_rounded, size: 18),
                onPressed: () => _scale.value = !_scale.value,
              ),
              const Spacer(),
              IconButton(
                tooltip: l.closeRpe,
                icon: const Icon(Icons.keyboard_rounded),
                onPressed: widget.editing.type,
              ),
            ],
          ),
          Padding(
            padding: const .symmetric(vertical: 8),
            child: Text(
              l.rpeHint,
              textAlign: .center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _scale,
            builder: (context, open, _) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: .topCenter,
                child: switch (open) {
                  true => Padding(
                    padding: const .only(bottom: 8),
                    child: Column(
                      children: [
                        for (final line in [l.rpeScale10, l.rpeScale9, l.rpeScale8, l.rpeScale7, l.rpeScale6])
                          Text(line, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  false => const SizedBox(width: double.infinity),
                },
              );
            },
          ),
          Row(
            spacing: 4,
            children: [
              for (final value in _rpeValues)
                Expanded(
                  child: _RpeValue(
                    value: value,
                    label: _rpeText(context, value),
                    selected: set.rpe == value,
                    onPressed: () {
                      buzz();
                      // the rating it already has clears it
                      widget.onSetRpe(set, switch (set.rpe == value) {
                        true => null,
                        false => value,
                      });
                      widget.editing.type();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bar's and the picker's plane: the keyboard's own tone, with a hairline
/// where the list ends, so the rows scrolling under it stay behind it.
BoxDecoration _panel(ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surfaceContainerLow,
    border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: .5)),
  );
}

class const _RpeValue({
  required final double value,
  required final String label,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Semantics(
      selected: selected,
      child: PrimaryButton.shrunk(
        key: WorkoutDetailKeys.rpeValue(value),
        // 48 tall, a whole tap target; nine across a phone cannot be as wide
        margin: const .symmetric(vertical: 14),
        // the accent fill is the rating the set has; the rest sit quiet
        backgroundColor: switch (selected) {
          true => null,
          false => colorScheme.surfaceContainerHighest,
        },
        onPressed: onPressed,
        child: Center(
          child: FittedBox(
            child: Text(
              label,
              // the text style names a colour of its own, so the accent's ink
              // has to be asked for
              style: textTheme.titleSmall?.copyWith(
                color: switch (selected) {
                  true => colorScheme.onTertiaryContainer,
                  false => null,
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An RPE as the user's language writes it: "8", "8.5", or "8,5".
String _rpeText(BuildContext context, double rpe) {
  return NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(rpe);
}
