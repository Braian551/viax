import 'package:flutter/material.dart';

/// RadarIndicator
/// Pequeño widget que muestra un radar giratorio y un pulso central.
class RadarIndicator extends StatefulWidget {
  final bool active;
  final double size;
  final Color color;

  const RadarIndicator({
    super.key,
    this.active = true,
    this.size = 36,
    required this.color,
  });

  @override
  State<RadarIndicator> createState() => _RadarIndicatorState();
}

class _RadarIndicatorState extends State<RadarIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.active) {
      _rotController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RadarIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _rotController.repeat();
        _pulseController.repeat(reverse: true);
      } else {
        _rotController.stop();
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulso sutil (más grande para llenar el espacio)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final val = _pulseController.value;
              return Container(
                width: size * (1.0 + val * 0.8),
                height: size * (1.0 + val * 0.8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.14 * (1 - val)),
                ),
              );
            },
          ),

          // Barra giratoria tipo radar (sweep gradient) ocupando casi todo el tamaño
          RotationTransition(
            turns: _rotController,
            child: Container(
              width: size * 1.0,
              height: size * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent,
                    widget.color.withValues(alpha: 0.14),
                    widget.color.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Punto central (pequeño)
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
