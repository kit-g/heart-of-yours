import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

extension Position on GlobalKey {
  RelativeRect? position() => currentContext?.menuPosition();
}

extension MenuPosition on BuildContext {
  /// Where a menu dropping from the widget at this context sits: under it,
  /// as wide as it.
  RelativeRect menuPosition() {
    final RenderBox renderBox = findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height, // top (below the button)
      offset.dx + size.width,
      offset.dy + size.height, // bottom (same as top for a dropdown effect)
    );
  }
}

/// A row's value with the mark that says a menu opens from it: the trailing
/// end of a value-and-menu row, the stand-in for [SettingSwitcher] when the
/// choices do not fit as segments (docs/style.md). Key it and hang the menu
/// off the key's context, so the menu sits under the value, not under the
/// row's far edge past its padding.
///
/// It takes at most [share] of the width it is offered — a list tile offers
/// its whole width to what trails it — and ellipsizes past that, so at the
/// largest text the row's title keeps the rest instead of breaking a letter a
/// line.
class MenuValue extends StatelessWidget {
  final String label;
  final double share;

  const new(this.label, {super.key, this.share = 0.4});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return _ShareOfWidth(
      share: share,
      child: Row(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          Flexible(
            child: Text(label, style: textTheme.bodyMedium, maxLines: 1, overflow: .ellipsis),
          ),
          const Icon(Icons.unfold_more_rounded, size: 20),
        ],
      ),
    );
  }
}

/// Lays its child out within [share] of the width offered, and is the child's
/// size. Not a [LayoutBuilder]: a dialog measures its content's intrinsic
/// width, which a layout builder cannot answer.
class _ShareOfWidth extends SingleChildRenderObjectWidget {
  final double share;

  const new({required this.share, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShareOfWidth(share);

  @override
  void updateRenderObject(BuildContext context, _RenderShareOfWidth renderObject) {
    renderObject.share = share;
  }
}

class _RenderShareOfWidth extends RenderProxyBox {
  double _share;

  new(this._share);

  set share(double value) {
    if (value == _share) return;
    _share = value;
    markNeedsLayout();
  }

  BoxConstraints _capped(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return constraints;
    final cap = constraints.maxWidth * _share;
    return constraints.copyWith(maxWidth: cap, minWidth: math.min(constraints.minWidth, cap));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return child?.getDryLayout(_capped(constraints)) ?? constraints.smallest;
  }

  @override
  void performLayout() {
    if (child case final child?) {
      child.layout(_capped(constraints), parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      size = constraints.smallest;
    }
  }
}

/// A section's title inside a menu: not a choice, so not a [PopupMenuItem],
/// which would be announced as a dimmed button.
class MenuHeading<T> extends PopupMenuEntry<T> {
  final String title;

  const new(this.title, {super.key});

  @override
  double get height => 32;

  @override
  bool represents(T? value) => false;

  @override
  State<MenuHeading<T>> createState() => _MenuHeadingState<T>();
}

class _MenuHeadingState<T> extends State<MenuHeading<T>> {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const .fromLTRB(12, 8, 12, 4),
        child: Text(
          widget.title,
          style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
