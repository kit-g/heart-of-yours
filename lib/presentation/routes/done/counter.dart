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
        final controller = AnimationController(
          duration: Duration(milliseconds: widget.duration),
          vsync: this,
        );
        controller.repeat(reverse: true); // pulse effect
        return controller;
      },
    );

    _initAnimations();
    _animate();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _animations.map((animation) {
        return ValueListenableBuilder<double>(
          valueListenable: animation,
          builder: (_, value, __) {
            return Transform.scale(
              scale: value,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _PulsePainter(color: widget.color),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _initAnimations();
    _animate();
  }

  void _animate() {
    void animate((int, AnimationController) each) {
      Future.delayed(
        Duration(milliseconds: each.$1 * widget.duration),
        () {
          each.$2
            ..reset()
            ..forward();
        },
      );
    }

    _controllers.indexed.forEach(animate);
  }

  void _initAnimations() {
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 1.4, end: 1).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
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
