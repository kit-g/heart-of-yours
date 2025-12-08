import 'package:flutter/material.dart';

extension Position on GlobalKey {
  RelativeRect? position() {
    final context = currentContext;
    if (context == null) return null;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
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
