part of 'workout_detail.dart';

/// The menu's one width, open explanation or not: wide enough to wrap a short
/// paragraph, and fixed so the help buttons stay where the finger left them
/// when a row grows. A multiple of 56, the step a popup menu rounds its width
/// up to, or the rows stop short of its right edge.
const _setTypeMenuWidth = 224.0;

/// The set's place in its exercise, and the way to say what kind of set it was
/// (#151). A plain set shows its number, a warm-up, drop or failure set its
/// letter. Tapping it opens the types, in the same popup the workout's options
/// use; picking the one the set already is makes it a plain set again, so the
/// menu never needs a fourth row.
///
/// Without [onSetType] (a screen that does not type sets) it is the number
/// alone, not a button that does nothing.
class _SetTypeButton extends StatefulWidget {
  final ExerciseSet set;
  final int number;
  final Color fill;
  final void Function(ExerciseSet, SetType)? onSetType;

  /// Rates the set, or clears its rating (#234). With it, and RPE on, the
  /// popup carries the ratings under the types.
  final void Function(ExerciseSet, double?)? onSetRpe;

  const new({
    super.key,
    required this.set,
    required this.number,
    required this.fill,
    this.onSetType,
    this.onSetRpe,
  });

  @override
  State<_SetTypeButton> createState() => _SetTypeButtonState();
}

class _SetTypeButtonState extends State<_SetTypeButton> with HasHaptic<_SetTypeButton> {
  /// Where the popup opens from: just under the set's number.
  final _anchor = GlobalKey();

  /// The type whose explanation is open under its row, if any. Closed again
  /// with the menu, so the next opening starts as short as it can be.
  final _explained = ValueNotifier<SetType?>(null);

  /// Whether the RPE scale is unfolded in the popup; folded with it too.
  final _rpeExplained = ValueNotifier(false);

  @override
  void dispose() {
    _explained.dispose();
    _rpeExplained.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :brightness) = Theme.of(context);
    final l = L.of(context);
    final ExerciseSet(:setType) = widget.set;

    final label = switch (setType) {
      .normal => Text('${widget.number}'),
      _ => Text(
        setType.letter(l),
        style: textTheme.titleSmall?.copyWith(
          color: setType.color(brightness),
          fontWeight: .w700,
        ),
      ),
    };

    final face = SizedBox(
      width: _setColumnWidth,
      height: _fixedButtonHeight,
      child: Center(child: label),
    );

    final onSetType = widget.onSetType;
    if (onSetType == null) {
      return Semantics(
        value: switch (setType) {
          .normal => null,
          _ => setType.copy(l),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(color: widget.fill, borderRadius: const .all(.circular(8))),
          child: face,
        ),
      );
    }

    void open() => _open(onSetType);

    // one node that says it all: which set, what kind, and that it opens the
    // types — a merge of the tooltip and the button's own node left the
    // tappable one unlabelled
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: switch (setType) {
        .normal => '${l.setType} ${widget.number}',
        _ => '${l.setType}: ${setType.copy(l)}',
      },
      onTap: open,
      child: Tooltip(
        key: _anchor,
        message: l.setType,
        excludeFromSemantics: true,
        child: PrimaryButton.shrunk(
          margin: .zero,
          backgroundColor: widget.fill,
          onPressed: open,
          child: face,
        ),
      ),
    );
  }

  /// The types a set can be marked as; [SetType.normal] is what un-marking
  /// one leaves.
  static const _typed = [SetType.warmup, SetType.drop, SetType.failure];

  Future<void> _open(void Function(ExerciseSet, SetType) onSetType) async {
    final ExerciseSet(setType: current, rpe: rated) = widget.set;
    final onSetRpe = Preferences.of(context).isOn(.rpe) ? widget.onSetRpe : null;
    final picked = await showMenu<_SetChoice>(
      context: context,
      position: _anchor.position(),
      items: [
        ..._typed.map((type) => _item(type, selected: type == current)),
        if (onSetRpe != null) _RpeEntry(set: widget.set, explained: _rpeExplained),
      ],
    );
    _explained.value = null;
    _rpeExplained.value = false;
    if (!mounted) return;

    switch (picked) {
      case _TypeChoice(:final type):
        buzz();
        // the type a set already is makes it plain again
        final retyped = type == current ? SetType.normal : type;
        Analytics.of(context).setTypeChanged(type: retyped);
        onSetType(widget.set, retyped);
      case _RpeChoice(:final rpe):
        buzz();
        // and the rating it already has clears it
        onSetRpe?.call(widget.set, rpe == rated ? null : rpe);
      case _RpeCleared():
        buzz();
        onSetRpe?.call(widget.set, null);
      case null:
        return;
    }
  }

  PopupMenuItem<_SetChoice> _item(SetType type, {required bool selected}) {
    final ThemeData(:textTheme, :brightness, :colorScheme) = Theme.of(context);
    final l = L.of(context);

    return PopupMenuItem<_SetChoice>(
      key: WorkoutDetailKeys.setTypeOption(type),
      value: _TypeChoice(type),
      padding: .zero,
      child: Semantics(
        selected: selected,
        child: Container(
          width: _setTypeMenuWidth,
          // the menu's own surface is the fill tone, so the type's hue, faint,
          // is what tells the current one apart
          color: selected ? type.color(brightness).withValues(alpha: .16) : null,
          padding: const .symmetric(horizontal: 12, vertical: 4),
          child: ValueListenableBuilder<SetType?>(
            valueListenable: _explained,
            builder: (context, explained, _) {
              return Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          type.letter(l),
                          textAlign: .center,
                          style: textTheme.titleMedium?.copyWith(color: type.color(brightness), fontWeight: .w700),
                        ),
                      ),
                      Expanded(child: Text(type.copy(l), style: textTheme.titleSmall)),
                      IconButton(
                        tooltip: l.aboutSetType(type.copy(l)),
                        visualDensity: .compact,
                        style: IconButton.styleFrom(
                          // the fill tone: the page's own ground is the popup's in light
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
                        ),
                        icon: const Icon(Icons.question_mark_rounded, size: 18),
                        onPressed: () {
                          _explained.value = explained == type ? null : type;
                        },
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: .topCenter,
                    child: switch (explained == type) {
                      true => Padding(
                        padding: const .only(top: 2, bottom: 8),
                        child: Text(
                          type.explanation(l),
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      false => const SizedBox(width: double.infinity),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Copy and color for a [SetType]; the model carries the wire word only.
/// A set type's copy, for every surface that names one: the set column and
/// its menu, and the watch (#236).
extension SetTypeCopy on SetType {
  String copy(L l) {
    return switch (this) {
      .normal => '',
      .warmup => l.setTypeWarmup,
      .drop => l.setTypeDrop,
      .failure => l.setTypeFailure,
    };
  }

  String letter(L l) {
    return switch (this) {
      .normal => '',
      .warmup => l.setTypeWarmupLetter,
      .drop => l.setTypeDropLetter,
      .failure => l.setTypeFailureLetter,
    };
  }

  String explanation(L l) {
    return switch (this) {
      .normal => '',
      .warmup => l.setTypeWarmupExplained,
      .drop => l.setTypeDropExplained,
      .failure => l.setTypeFailureExplained,
    };
  }

  /// A hue per type, readable as text on the set's fill in either brightness.
  /// Warm for the warm-up, red for failure, violet for the drop: none of
  /// them the accent, which belongs to completion.
  Color color(Brightness brightness) {
    return switch ((this, brightness)) {
      (.warmup, .light) => const Color(0xFFB0640A),
      (.warmup, .dark) => const Color(0xFFF2A33A),
      (.drop, .light) => const Color(0xFF6D45C9),
      (.drop, .dark) => const Color(0xFFA98BF5),
      (.failure, .light) => const Color(0xFFC93636),
      (.failure, .dark) => const Color(0xFFEE6B6B),
      (.normal, _) => Colors.transparent,
    };
  }
}
