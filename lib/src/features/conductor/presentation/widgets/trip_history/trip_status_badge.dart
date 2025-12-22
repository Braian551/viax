import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Badge de estado del viaje con colores temáticos
/// Componente reutilizable para mostrar el estado de un viaje
class TripStatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const TripStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: statusConfig.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusConfig.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusConfig.icon,
            color: statusConfig.color,
            size: isCompact ? 14 : 16,
          ),
          SizedBox(width: isCompact ? 4 : 6),
          Text(
            statusConfig.label.toUpperCase(),
            style: TextStyle(
              color: statusConfig.color,
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status.toLowerCase()) {
      case 'completada':
      case 'entregado':
        return _StatusConfig(
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
          label: 'Completada',
        );
      case 'cancelada':
        return _StatusConfig(
          color: AppColors.error,
          icon: Icons.cancel_rounded,
          label: 'Cancelada',
        );
      case 'en_progreso':
      case 'en_curso':
        return _StatusConfig(
          color: AppColors.primary,
          icon: Icons.directions_car_rounded,
          label: 'En Curso',
        );
      case 'pendiente':
        return _StatusConfig(
          color: AppColors.warning,
          icon: Icons.access_time_rounded,
          label: 'Pendiente',
        );
      default:
        return _StatusConfig(
          color: Colors.grey,
          icon: Icons.help_outline_rounded,
          label: status,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}
