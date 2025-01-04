import 'package:flutter/material.dart';

/// Text widget that slightly "pops" when triggered
/// to attract attention to itself
class PoppingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final ValueNotifier<bool> trigger;

  const PoppingText({
    required this.text,
    required this.trigger,
    this.style,
    super.key,
  });

  @override
  State<PoppingText> createState() => _PoppingTextState();
}

class _PoppingTextState extends State<PoppingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    widget.trigger.addListener(_animationListener);
  }

  void _animationListener() {
    if (widget.trigger.value) {
      _controller
        ..reset()
        ..forward().then(
          (_) {
            _controller.reverse();
          },
        );
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_animationListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (_, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}
