import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

/// Header con estado del viaje y botón de regreso.
/// Diseño moderno consistente con el estilo de la app.
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
        _buildCircleButton(
          icon: Icons.close_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            onBack();
          },
        ),

        const SizedBox(width: 12),

        // Pill de estado
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dot pulsante
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.4),
                        blurRadius: 8,
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Botón de opciones
        _buildCircleButton(
          icon: Icons.more_vert_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            if (onOptions != null) {
              onOptions!();
            } else if (onCancel != null) {
              onCancel!();
            }
          },
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white : Colors.grey[700],
            size: 22,
          ),
        ),
      ),
    );
  }
}
