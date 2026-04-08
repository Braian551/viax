import 'package:flutter/material.dart';
import '../theme/thali_colors.dart';

/// An animated pulsing heart with glow effect
class PulsingHeart extends StatefulWidget {
  final double size;

  const PulsingHeart({super.key, this.size = 60});

  @override
  State<PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ThaliColors.pinkAccent.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ShaderMask(
          shaderCallback: (bounds) =>
              ThaliColors.accentGradient.createShader(bounds),
          child: Icon(
            Icons.favorite_rounded,
            size: widget.size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
