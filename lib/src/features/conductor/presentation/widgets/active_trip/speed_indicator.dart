import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Indicador de velocidad actual del conductor.
/// 
/// Muestra la velocidad en km/h con estilo visual diferenciado
/// según si el vehículo está en movimiento o detenido.
class SpeedIndicator extends StatelessWidget {
  final double currentSpeed;
  final bool isDark;

  const SpeedIndicator({
    super.key,
    required this.currentSpeed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final speedInt = currentSpeed.toInt();
    final isMoving = speedInt > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$speedInt',
            style: TextStyle(
              color: isMoving
                  ? AppColors.primary
                  : (isDark ? Colors.white : Colors.grey[800]),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'km/h',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
