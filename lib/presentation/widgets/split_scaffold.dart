import 'package:flutter/material.dart';

class SplitPaneScaffold extends StatelessWidget {
  final Widget leftPane;
  final Widget rightPane;
  final bool reverse;

  const SplitPaneScaffold({
    super.key,
    required this.leftPane,
    required this.rightPane,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final children = reverse ? [rightPane, leftPane] : [leftPane, rightPane];

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: reverse ? 1 : 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: _transition,
              child: Container(
                key: ValueKey(reverse),
                color: Theme.of(context).colorScheme.surface,
                child: children[0],
              ),
            ),
          ),
          Expanded(
            flex: reverse ? 2 : 1,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: _transition,
              child: Container(
                key: ValueKey(reverse),
                child: children[1],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transition(Widget child, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.1, 0),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
