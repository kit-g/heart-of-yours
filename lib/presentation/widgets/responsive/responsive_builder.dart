library;

import 'package:flutter/material.dart';

enum LayoutSize { compact, wide }

typedef LayoutWidgetBuilder = Widget Function(BuildContext context, LayoutSize layout, int stackIndex);

/// A widget that provides layout information to its descendants.
///
/// It determines the [LayoutSize] based on the screen width and a specified
/// breakpoint. It also takes a [currentStack] index, which can be used to
/// manage navigation or different views within the layout.
///
/// The [builder] function is called to build the UI, receiving the current
/// [BuildContext], [LayoutSize], and [currentStack] index.
///
/// Descendant widgets can access the [LayoutSize] and [currentStack] using
/// `LayoutProvider.of(context)` and `LayoutProvider.currentStackOf(context)`
/// respectively.
class LayoutProvider extends StatelessWidget {
  final LayoutWidgetBuilder builder;
  final int currentStack;
  final double breakpoint;

  const LayoutProvider({
    super.key,
    required this.builder,
    required this.currentStack,
    this.breakpoint = 600,
  });

  static LayoutSize of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_LayoutInherited>();
    assert(inherited != null, 'No LayoutProvider found in context');
    return inherited!.layout;
  }

  static int currentStackOf(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_LayoutInherited>();
    assert(inherited != null, 'No LayoutProvider found in context');
    return inherited!.stackIndex;
  }

  @override
  Widget build(BuildContext context) {
    final layout = MediaQuery.sizeOf(context).width >= breakpoint ? LayoutSize.wide : LayoutSize.compact;
    return _LayoutInherited(
      layout: layout,
      stackIndex: currentStack,
      child: Builder(
        builder: (context) => builder(context, layout, currentStack),
      ),
    );
  }
}

class _LayoutInherited extends InheritedWidget {
  final LayoutSize layout;
  final int stackIndex;

  const _LayoutInherited({
    required super.child,
    required this.layout,
    required this.stackIndex,
  });

  @override
  bool updateShouldNotify(_LayoutInherited old) => old.layout != layout || old.stackIndex != stackIndex;
}
