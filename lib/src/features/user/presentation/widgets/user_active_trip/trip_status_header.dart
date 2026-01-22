import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

/// Header con estado del viaje y botón de regreso.
class TripStatusHeader extends StatelessWidget {
  final String tripState;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback? onCancel;
  final VoidCallback? onOptions;

  const TripStatusHeader({
    super.key,
    required this.tripState,
    required this.isDark,
    required this.onBack,
    this.onCancel,
    this.onOptions,
  });

  String get _statusText {
    switch (tripState) {
      case 'en_curso':
        return 'En viaje';
      case 'completada':
      case 'entregado':
        return '¡Llegaste!';
      case 'cancelada':
        return 'Cancelado';
      default:
        return 'En camino';
    }
  }

  IconData get _statusIcon {
    switch (tripState) {
      case 'en_curso':
        return Icons.directions_car_rounded;
      case 'completada':
      case 'entregado':
        return Icons.check_circle_rounded;
      case 'cancelada':
        return Icons.cancel_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }

  Color get _statusColor {
    switch (tripState) {
      case 'en_curso':
        return AppColors.primary;
      case 'completada':
      case 'entregado':
        return AppColors.success;
      case 'cancelada':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botón atrás
        Material(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 20,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Pill de estado
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(_statusIcon, color: _statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[900],
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Botón de opciones/cancelar
        Material(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (onOptions != null) {
                onOptions!();
              } else if (onCancel != null) {
                onCancel!();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
