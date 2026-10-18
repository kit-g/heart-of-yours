part of 'goals.dart';

/// Swipe a row toward its start to uncover a Delete button behind its end; a
/// tap on that button deletes. Two steps on purpose: a full swipe that
/// deleted at once took goals away by accident, again and again.
///
/// Swiping back, tapping the row, or scrolling the list closes it. A screen
/// reader reaches the same delete as a custom action on the row.
class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  /// Identifies the row — and its Delete button, for tests.
  final Key dismissKey;

  const new({
    required this.dismissKey,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> with SingleTickerProviderStateMixin, HasHaptic<_SwipeToDelete> {
  /// How far the row slides to show the button.
  static const _reveal = 96.0;

  /// 0 closed, 1 open: the share of [_reveal] the row has slid.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.removeListener(_close);
    _scroll = Scrollable.maybeOf(context)?.position?..addListener(_close);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_close);
    _open.dispose();
    super.dispose();
  }

  void _close() {
    if (_open.value > 0 && !_open.isAnimating) _open.animateTo(0, curve: Curves.easeOutCubic);
  }

  /// The row follows the finger toward its start, [_reveal] at most.
  void _onDrag(DragUpdateDetails details, bool rtl) {
    final toStart = switch (rtl) {
      false => -details.primaryDelta!,
      true => details.primaryDelta!,
    };
    _open.value = (_open.value + toStart / _reveal).clamp(0, 1);
  }

  /// Let go past halfway, it stays open; short of it, it goes back.
  void _onDragEnd(DragEndDetails details) {
    final opens = _open.value > .5;
    if (opens && _open.value < 1) buzz();
    _open.animateTo(opens ? 1 : 0, curve: Curves.easeOutCubic);
  }

  void _delete() {
    _open.value = 0;
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);
    final rtl = Directionality.of(context) == .rtl;

    return Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: l.delete): _delete},
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => _onDrag(details, rtl),
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            // the button behind the row's end, there once uncovered
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SizedBox(
                  width: _reveal,
                  child: Material(
                    color: colorScheme.error,
                    child: InkWell(
                      key: switch (widget.dismissKey) {
                        ValueKey<String>(:final value) => ValueKey('$value.delete'),
                        final key => ValueKey('$key.delete'),
                      },
                      onTap: _delete,
                      child: Center(
                        child: Text(l.delete, style: textTheme.titleSmall?.copyWith(color: colorScheme.onError)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _open,
              builder: (context, child) {
                final open = _open.value > 0;
                return Transform.translate(
                  offset: Offset((rtl ? 1 : -1) * _reveal * _open.value, 0),
                  // open, a tap on the row closes it rather than opening it
                  child: switch (open) {
                    true => GestureDetector(
                      behavior: .opaque,
                      onTap: _close,
                      child: AbsorbPointer(child: child),
                    ),
                    false => child!,
                  },
                );
              },
              child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: widget.child),
            ),
          ],
        ),
      ),
    );
  }
}
