import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
         return CustomPaint(
           painter: _ScannerPainter(_controller.value),
         );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final double value;
  _ScannerPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final y = value * size.height;
    
    // Draw scanning line
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    
    // Draw gradient glow
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.primary.withOpacity(0.0), AppColors.primary.withOpacity(0.3)],
    );
    
    final rect = Rect.fromLTWH(0, y - 40, size.width, 40);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
