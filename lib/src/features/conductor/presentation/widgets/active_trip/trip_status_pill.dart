import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../common/pulsing_dot.dart';

/// Pill/badge de estado del viaje activo.
/// 
/// Muestra el estado actual del viaje:
/// - "Ir a recoger": En camino al punto de recogida
/// - "Esperando": Llegó al punto, esperando al pasajero
/// - "En viaje": Viaje en curso hacia el destino
class TripStatusPill extends StatelessWidget {
  final bool toPickup;
  final bool arrivedAtPickup;
  final bool isDark;

  const TripStatusPill({
    super.key,
    required this.toPickup,
    this.arrivedAtPickup = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    if (toPickup) {
      // Estado 1: En camino al punto de recogida
      color = AppColors.warning;
      text = 'Ir a recoger';
      icon = Icons.navigation_rounded;
    } else if (arrivedAtPickup) {
      // Estado 2: Llegó al punto, esperando al pasajero
      color = AppColors.accent;
      text = 'Esperando';
      icon = Icons.person_pin_circle_rounded;
    } else {
      // Estado 3: Viaje en curso hacia el destino
      color = AppColors.success;
      text = 'En viaje';
      icon = Icons.directions_car_rounded;
    }

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
