import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';

class PickupCenterPin extends StatelessWidget {
  final bool isMapMoving;
  final AnimationController pinBounceController;
  final String label;

  const PickupCenterPin({
    super.key,
    required this.isMapMoving,
    required this.pinBounceController,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, isMapMoving ? -20 : 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isMapMoving ? 1.0 : 0.8,
                child: _Label(isMapMoving: isMapMoving, label: label),
              ),
              const _Triangle(),
              const SizedBox(height: 2),
              AnimatedBuilder(
                animation: pinBounceController,
                builder: (context, child) {
                  final bounce = math.sin(pinBounceController.value * math.pi) * 6;
                  return Transform.translate(offset: Offset(0, -bounce), child: child);
                },
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: isMapMoving ? 1.15 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PinHead(isMapMoving: isMapMoving),
                      _PinNeedle(isMapMoving: isMapMoving),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: isMapMoving ? 20 : 12,
                height: isMapMoving ? 8 : 5,
                margin: EdgeInsets.only(top: isMapMoving ? 15 : 0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isMapMoving ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final bool isMapMoving;
  final String label;

  const _Label({required this.isMapMoving, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isMapMoving ? AppColors.primary : const Color(0xFF00C853);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isMapMoving ? Icons.place : Icons.touch_app, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Triangle extends StatelessWidget {
  const _Triangle();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 7),
      painter: _TrianglePainter(color: AppColors.primary),
    );
  }
}

class _PinHead extends StatelessWidget {
  final bool isMapMoving;

  const _PinHead({required this.isMapMoving});

  @override
  Widget build(BuildContext context) {
    final colors = isMapMoving
      ? [AppColors.primary.withValues(alpha: 0.9), AppColors.primary]
      : [const Color(0xFF00E676), const Color(0xFF00C853)];

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }
}

class _PinNeedle extends StatelessWidget {
  final bool isMapMoving;

  const _PinNeedle({required this.isMapMoving});

  @override
  Widget build(BuildContext context) {
    final colors = isMapMoving
      ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.2)]
      : [const Color(0xFF00C853), const Color(0xFF00C853).withValues(alpha: 0.2)];

    return Container(
      width: 5,
      height: 18,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3)),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}