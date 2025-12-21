import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../common/pulsing_dot.dart';

/// Pill/badge de estado del viaje activo.
/// 
/// Muestra el estado actual ("Ir a recoger" o "En camino") con
/// un indicador visual de color correspondiente.
class TripStatusPill extends StatelessWidget {
  final bool toPickup;
  final bool isDark;

  const TripStatusPill({
    super.key,
    required this.toPickup,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = toPickup ? AppColors.warning : AppColors.success;
    final text = toPickup ? 'Ir a recoger' : 'En camino';
    final icon = toPickup ? Icons.navigation_rounded : Icons.directions_car_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsingDot(color: color, size: 8),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
