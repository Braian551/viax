import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/thali_colors.dart';

/// Floating hearts and stars animation overlay
class FloatingHeartsOverlay extends StatefulWidget {
  const FloatingHeartsOverlay({super.key});

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with TickerProviderStateMixin {
  late final List<_FloatingParticle> _particles;
  late final AnimationController _controller;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(18, (_) => _FloatingParticle(_random));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _HeartsPainter(_particles, _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _FloatingParticle {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;
  final bool isStar;
  final double swayAmount;
  final double swaySpeed;

  _FloatingParticle(Random r)
      : x = r.nextDouble(),
        startY = r.nextDouble(),
        size = 8 + r.nextDouble() * 16,
        speed = 0.3 + r.nextDouble() * 0.7,
        opacity = 0.15 + r.nextDouble() * 0.35,
        isStar = r.nextDouble() > 0.65,
        swayAmount = 10 + r.nextDouble() * 25,
        swaySpeed = 1 + r.nextDouble() * 3;
}

class _HeartsPainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final double progress;

  _HeartsPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.startY + progress * p.speed) % 1.2) * size.height - size.height * 0.1;
      final sway = sin((progress * p.swaySpeed + p.startY) * 2 * pi) * p.swayAmount;
      final px = p.x * size.width + sway;

      final paint = Paint()
        ..color = (p.isStar ? ThaliColors.starGold : ThaliColors.pink)
            .withValues(alpha: p.opacity);

      if (p.isStar) {
        _drawStar(canvas, Offset(px, y), p.size * 0.5, paint);
      } else {
        _drawHeart(canvas, Offset(px, y), p.size, paint);
      }
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final s = size / 2;
    path.moveTo(center.dx, center.dy + s * 0.4);
    path.cubicTo(
      center.dx - s, center.dy - s * 0.2,
      center.dx - s * 0.5, center.dy - s,
      center.dx, center.dy - s * 0.4,
    );
    path.cubicTo(
      center.dx + s * 0.5, center.dy - s,
      center.dx + s, center.dy - s * 0.2,
      center.dx, center.dy + s * 0.4,
    );
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * pi / 5) - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.progress != progress;
}
