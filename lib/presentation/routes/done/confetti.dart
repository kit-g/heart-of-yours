part of 'done.dart';

class _Particle {
  /// initial horizontal position
  final double startX;

  /// initial vertical position
  final double startY;

  /// initial horizontal speed
  final double initialVelocityX;

  /// initial vertical speed
  final double initialVelocityY;

  /// how fast it falls down
  final double gravity;

  /// size of the box it's in
  final double size;

  /// fill color
  final Color color;

  /// either a star or a heart
  final bool isStar;

  /// initial speed of spinning
  final double initialRotation;

  /// current speed of spinning
  double rotationSpeed;

  /// how fast it slows down spinning
  final double damping;

  /// how much it wobbles
  final double oscillationAmplitude;

  /// how fast it wobbles
  final double oscillationFrequency;

  _Particle()
      : startX = _rng.nextDouble() * 20 - 10,
        startY = _rng.nextDouble() * 10,
        initialVelocityX = (_rng.nextDouble() - 0.5) * 200,
        initialVelocityY = -(_rng.nextDouble() * 500 + 40),
        gravity = 100 + _rng.nextInt(500).toDouble(),
        size = _rng.nextDouble() * 20 + 8,
        color = Colors.primaries[_rng.nextInt(Colors.primaries.length)],
        isStar = _rng.nextBool(),
        initialRotation = _rng.nextDouble() * 2 * pi,
        rotationSpeed = (_rng.nextDouble() - 0.5) * 4,
        damping = 0.96 + Random().nextDouble() * 0.05,
        // wobble range (5-15px)
        oscillationAmplitude = _rng.nextDouble() * 10 + 5,
        // wobble speed (2-7 Hz)
        oscillationFrequency = _rng.nextDouble() * 5 + 2;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final time = progress * 2.0;

      // original trajectory
      final baseX = size.width / 2 + particle.startX + particle.initialVelocityX * time;
      final y =
          size.height / 2 + particle.startY + particle.initialVelocityY * time + 0.5 * particle.gravity * time * time;

      // side-to-side oscillation
      final driftX = particle.oscillationAmplitude * sin(particle.oscillationFrequency * time);

      final x = baseX + driftX; // final x position

      final double opacity = (1 - progress).clamp(0, 1);

      final paint = Paint()..color = particle.color.withValues(alpha: opacity);

      particle.rotationSpeed *= particle.damping;
      final rotation = particle.initialRotation + particle.rotationSpeed * time;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rotation);

      if (particle.isStar) {
        _drawStar(canvas, 0, 0, particle.size, paint);
      } else {
        _drawHeart(canvas, 0, 0, particle.size, paint);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double size, Paint paint) {
    final Path path = Path();
    const int numPoints = 5;
    final outerRadius = size / 2;
    final innerRadius = outerRadius / 2.5;
    const angle = pi / numPoints;

    for (int i = 0; i < numPoints * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final px = x + radius * cos(i * angle - pi / 2);
      final py = y + radius * sin(i * angle - pi / 2);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Confetti extends StatefulWidget {
  final int particleCount;
  final int duration;

  const Confetti({
    super.key,
    this.particleCount = 15,
    this.duration = 4,
  });

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..forward();

    particles = List.generate(widget.particleCount, (_) => _Particle());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _controller,
      builder: (_, value, __) {
        return CustomPaint(
          painter: _ConfettiPainter(particles, value),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();

    _controller
      ..reset()
      ..forward();
  }
}

final _rng = Random();
