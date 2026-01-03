part of 'done.dart';

class _Counter extends StatefulWidget {
  final int count;
  final int duration;
  final Color color;
  final double size;

  const _Counter({
    required this.count,
    required this.color,
    this.duration = 200,
    this.size = 50,
  });

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      widget.count,
      (index) {
        return AnimationController(
          duration: Duration(milliseconds: widget.duration),
          reverseDuration: Duration(milliseconds: (widget.duration / 2).ceil()),
          vsync: this,
        );
      },
    );

    _initAnimations();
    _animate();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _animations.map(
        (animation) {
          return ValueListenableBuilder<double>(
            valueListenable: animation,
            builder: (_, value, _) {
              return Transform.scale(
                scale: value,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _PulsePainter(color: widget.color),
                ),
              );
            },
          );
        },
      ).toList(),
    );
  }

  void _animate() {
    void animate((int, AnimationController) each) {
      final (index, controller) = each;
      Future.delayed(
        Duration(milliseconds: index * widget.duration),
        () {
          controller
            ..reset()
            ..forward().then(
              (_) => controller.reverse(),
            );
        },
      );
    }

    _controllers.indexed.forEach(animate);
  }

  void _initAnimations() {
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 1, end: 1.4).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.ease,
          reverseCurve: Curves.ease,
        ),
      );
    }).toList();
  }
}

class _PulsePainter extends CustomPainter {
  final Color color;

  const _PulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    _drawHeart(canvas, 0, 0, size.width, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
