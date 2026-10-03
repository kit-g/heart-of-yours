part of 'workout_detail.dart';

/// The menu's width once an explanation opens under a row: wide enough for
/// a short paragraph, narrow enough to stay a menu beside the set it types.
const _setTypeMenuWidth = 280.0;

/// The set's place in its exercise, and the way to say what kind of set it was
/// (#151). A plain set shows its number, a warm-up, drop or failure set its
/// letter. Tapping it opens the types; picking the one the set already is
/// makes it a plain set again, so the menu never needs a fourth row.
///
/// Without [onSetType] (a screen that does not type sets) it is the number
/// alone, not a button that does nothing.
class _SetTypeButton extends StatefulWidget {
  final ExerciseSet set;
  final int number;
  final Color fill;
  final void Function(ExerciseSet, SetType)? onSetType;

  const new({
    super.key,
    required this.set,
    required this.number,
    required this.fill,
    this.onSetType,
  });

  @override
  State<_SetTypeButton> createState() => _SetTypeButtonState();
}

class _SetTypeButtonState extends State<_SetTypeButton> with HasHaptic<_SetTypeButton> {
  final _menu = MenuController();

  /// The type whose explanation is open under its row, if any. Closed again
  /// with the menu, so the next opening starts as short as it can be.
  final _explained = ValueNotifier<SetType?>(null);

  @override
  void dispose() {
    _explained.dispose();
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

    return MenuAnchor(
      controller: _menu,
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(.symmetric(vertical: 4)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: .all(.circular(8)))),
      ),
      onClose: () => _explained.value = null,
      menuChildren: [
        for (final type in _typed) _row(context, type, onSetType),
      ],
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();

        // one node that says it all: which set, what kind, and that it opens
        // the types — a merge of the tooltip and the button's own node left
        // the tappable one unlabelled
        return Semantics(
          container: true,
          button: true,
          excludeSemantics: true,
          label: switch (setType) {
            .normal => '${l.setType} ${widget.number}',
            _ => '${l.setType}: ${setType.copy(l)}',
          },
          onTap: toggle,
          child: Tooltip(
            message: l.setType,
            excludeFromSemantics: true,
            child: PrimaryButton.shrunk(
              margin: .zero,
              backgroundColor: widget.fill,
              onPressed: toggle,
              child: face,
            ),
          ),
        );
      },
    );
  }

  /// The types a set can be marked as; [SetType.normal] is what un-marking
  /// one leaves.
  static const _typed = [SetType.warmup, SetType.drop, SetType.failure];

  Widget _row(BuildContext context, SetType type, void Function(ExerciseSet, SetType) onSetType) {
    final ThemeData(:textTheme, :brightness, :colorScheme, :scaffoldBackgroundColor) = Theme.of(context);
    final l = L.of(context);
    final selected = widget.set.setType == type;

    return ValueListenableBuilder<SetType?>(
      valueListenable: _explained,
      builder: (context, explained, _) {
        final item = MenuItemButton(
          key: WorkoutDetailKeys.setTypeOption(type),
          closeOnActivate: true,
          style: switch (selected) {
            // the menu's own surface is the fill tone, so the type's hue,
            // faint, is what tells the current one apart
            true => ButtonStyle(backgroundColor: WidgetStatePropertyAll(type.color(brightness).withValues(alpha: .16))),
            false => null,
          },
          leadingIcon: SizedBox(
            width: 20,
            child: Text(
              type.letter(l),
              textAlign: .center,
              style: textTheme.titleMedium?.copyWith(color: type.color(brightness), fontWeight: .w700),
            ),
          ),
          trailingIcon: IconButton(
            tooltip: l.aboutSetType(type.copy(l)),
            visualDensity: .compact,
            style: IconButton.styleFrom(
              backgroundColor: scaffoldBackgroundColor,
              shape: const RoundedRectangleBorder(borderRadius: .all(.circular(8))),
            ),
            icon: const Icon(Icons.question_mark_rounded, size: 18),
            onPressed: () {
              _explained.value = switch (explained == type) {
                true => null,
                false => type,
              };
            },
          ),
          onPressed: () {
            buzz();
            final picked = switch (selected) {
              true => SetType.normal,
              false => type,
            };
            // read before the retype: it rebuilds the rows and closes the
            // menu, and the menu's own context goes with it
            Analytics.of(this.context).setTypeChanged(type: picked);
            onSetType(widget.set, picked);
          },
          child: Semantics(
            selected: selected,
            child: Text(type.copy(l), style: textTheme.titleSmall),
          ),
        );

        return Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            item,
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: .topCenter,
              child: switch (explained == type) {
                true => SizedBox(
                  width: _setTypeMenuWidth,
                  child: Padding(
                    padding: const .fromLTRB(12, 0, 12, 10),
                    child: Text(
                      type.explanation(l),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                false => const SizedBox.shrink(),
              },
            ),
          ],
        );
      },
    );
  }
}

/// Copy and color for a [SetType]; the model carries the wire word only.
extension on SetType {
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
