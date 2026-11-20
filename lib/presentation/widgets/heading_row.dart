import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A section's heading and the actions that belong to it: on one line, the
/// actions at its end, when they fit; the actions on a line of their own under
/// the heading when they don't — a longer language at a large text size on a
/// narrow phone (#701), where a `Row` ran the actions past the edge.
///
/// Not a `Wrap` with `spaceBetween`: under a loose width a wrap is as wide as
/// its widest line, which leaves no space to put between, and the actions
/// stop at the heading's end. Not a [LayoutBuilder] either, which cannot
/// answer an intrinsic measurement. This fills the width it is offered, like
/// a `Row`, and only an unbounded width makes it its content's size.
class HeadingRow extends StatelessWidget {
  final Widget heading;

  /// Laid out together, in a [Wrap], so several can still break among
  /// themselves when even their own line is too narrow for them.
  final List<Widget> actions;

  /// The least room between the heading and the actions on a shared line.
  final double spacing;

  /// Between the heading and the actions under it.
  final double runSpacing;

  /// Between one action and the next.
  final double actionSpacing;

  const new({
    super.key,
    required this.heading,
    required this.actions,
    this.spacing = 12,
    this.runSpacing = 6,
    this.actionSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _HeadingRowLayout(
      heading: heading,
      actions: switch (actions) {
        [] => null,
        _ => Wrap(
          spacing: actionSpacing,
          runSpacing: runSpacing,
          crossAxisAlignment: .center,
          children: actions,
        ),
      },
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }
}

class _HeadingRowLayout extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  final Widget heading;
  final Widget? actions;
  final double spacing;
  final double runSpacing;

  const new({
    required this.heading,
    required this.actions,
    required this.spacing,
    required this.runSpacing,
  });

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) {
    return switch (slot) {
      .heading => heading,
      .actions => actions,
    };
  }

  @override
  _RenderHeadingRow createRenderObject(BuildContext context) {
    return _RenderHeadingRow(
      spacing: spacing,
      runSpacing: runSpacing,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHeadingRow renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }
}

enum _Slot { heading, actions }

/// Where everything goes for one set of constraints.
typedef _Arrangement = ({Size size, Size heading, Size actions, bool oneLine});

class _RenderHeadingRow extends RenderBox with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  double _spacing;
  double _runSpacing;
  TextDirection _textDirection;

  new({
    required this._spacing,
    required this._runSpacing,
    required this._textDirection,
  });

  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _heading => childForSlot(.heading);

  RenderBox? get _actions => childForSlot(.actions);

  /// No gap to keep when there is nothing to keep it from.
  double get _gap => switch (_actions) {
    null => 0,
    _ => _spacing,
  };

  _Arrangement _arrange(BoxConstraints constraints, ChildLayouter layoutChild) {
    final heading = _heading;
    final actions = _actions;
    final width = constraints.maxWidth;
    final actionsSize = switch (actions) {
      RenderBox box => layoutChild(box, BoxConstraints(maxWidth: width)),
      null => Size.zero,
    };
    // the heading's one-line width against what the actions leave it
    final beside = width - actionsSize.width - _gap;
    final oneLine = actions == null || (heading?.getMaxIntrinsicWidth(.infinity) ?? 0) <= beside;
    final headingSize = switch (heading) {
      RenderBox box => layoutChild(box, BoxConstraints(maxWidth: oneLine ? beside : width)),
      null => Size.zero,
    };
    final natural = switch (oneLine) {
      true => Size(
        headingSize.width + _gap + actionsSize.width,
        math.max(headingSize.height, actionsSize.height),
      ),
      false => Size(
        math.max(headingSize.width, actionsSize.width),
        headingSize.height + _runSpacing + actionsSize.height,
      ),
    };
    return (
      // the whole width when there is one to fill, so the actions sit at its end
      size: constraints.constrain(Size(constraints.hasBoundedWidth ? width : natural.width, natural.height)),
      heading: headingSize,
      actions: actionsSize,
      oneLine: oneLine,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;
  }

  @override
  void performLayout() {
    final (:size, :heading, :actions, :oneLine) = _arrange(constraints, ChildLayoutHelper.layoutChild);
    this.size = size;

    // x of a box [width] wide at the line's start or end, in reading order
    double atStart(double width) => _textDirection == .rtl ? size.width - width : 0;
    double atEnd(double width) => _textDirection == .rtl ? 0 : size.width - width;

    // two lines centre together in any height they were given beyond their own
    final top = (size.height - heading.height - _runSpacing - actions.height) / 2;
    final (headingOffset, actionsOffset) = switch (oneLine) {
      true => (
        Offset(atStart(heading.width), (size.height - heading.height) / 2),
        Offset(atEnd(actions.width), (size.height - actions.height) / 2),
      ),
      false => (
        Offset(atStart(heading.width), top),
        Offset(atStart(actions.width), top + heading.height + _runSpacing),
      ),
    };
    _place(_heading, headingOffset);
    _place(_actions, actionsOffset);
  }

  static void _place(RenderBox? child, Offset offset) {
    if (child?.parentData case BoxParentData data) data.offset = offset;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return math.max(
      _heading?.getMinIntrinsicWidth(height) ?? 0,
      _actions?.getMinIntrinsicWidth(height) ?? 0,
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return (_heading?.getMaxIntrinsicWidth(height) ?? 0) + _gap + (_actions?.getMaxIntrinsicWidth(height) ?? 0);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _arrange(BoxConstraints(maxWidth: width), ChildLayoutHelper.dryLayoutChild).size.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (_heading case final heading?) {
      final offset = (heading.parentData! as BoxParentData).offset;
      return switch (heading.getDistanceToActualBaseline(baseline)) {
        double distance => distance + offset.dy,
        null => null,
      };
    }
    return null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return children.any((child) {
      return result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
    });
  }
}
