part of 'goals.dart';

/// Swipe a row away to delete it, in either direction and without asking.
///
/// The same gesture an exercise set uses, down to the threshold and the single
/// haptic on crossing it — a goal and one of its rungs should not each have
/// their own idea of what a delete feels like.
///
/// No confirmation is deliberate. The travel needed to cross [_dismissThreshold]
/// is itself the confirmation, and the label only slides to the middle once you
/// have gone far enough for the release to count.
class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  /// Identifies the row being dismissed — `Dismissible` needs a stable one to
  /// tell rows apart as the list changes under it.
  final Key dismissKey;

  const _SwipeToDelete({
    required this.dismissKey,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> with HasHaptic<_SwipeToDelete> {
  final _hasCrossedThreshold = ValueNotifier<bool>(false);
  bool _hasBuzzed = false;

  @override
  void dispose() {
    _hasCrossedThreshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);

    return Dismissible(
      key: widget.dismissKey,
      background: _background(l, textTheme, colorScheme, Alignment.centerLeft),
      secondaryBackground: _background(l, textTheme, colorScheme, Alignment.centerRight),
      dismissThresholds: const {DismissDirection.horizontal: _dismissThreshold},
      onUpdate: _onSwipe,
      onDismissed: (_) {
        _hasBuzzed = false;
        widget.onDelete();
      },
      child: widget.child,
    );
  }

  /// The panel behind the travelling row. The label slides to the middle once
  /// the swipe has gone far enough to count, so the row says what releasing it
  /// will do before you let go.
  Widget _background(L l, TextTheme textTheme, ColorScheme colorScheme, Alignment alignment) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasCrossedThreshold,
      builder: (_, hasCrossed, _) {
        return Container(
          color: colorScheme.error,
          child: AnimatedAlign(
            curve: Curves.easeOutCubic,
            duration: const Duration(milliseconds: 200),
            alignment: switch (hasCrossed) {
              true => Alignment.center,
              false => alignment,
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: PoppingText(
                text: l.delete,
                style: textTheme.titleSmall?.copyWith(color: colorScheme.onError),
                trigger: _hasCrossedThreshold,
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSwipe(DismissUpdateDetails details) {
    switch (details.progress) {
      case > _dismissThreshold:
        if (!_hasBuzzed) {
          buzz();
          _hasBuzzed = true;
        }
        _hasCrossedThreshold.value = true;
      default:
        if (_hasBuzzed) {
          _hasBuzzed = false;
        }
        _hasCrossedThreshold.value = false;
    }
  }
}
