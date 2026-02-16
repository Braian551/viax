import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Card con información de progreso del viaje.
/// Diseño moderno consistente con el estilo de la app.
class TripProgressCard extends StatelessWidget {
  final double distanceKm;
  final int etaMinutes;
  final int? elapsedMinutes;
  final double progress;
  final bool isDark;

  const TripProgressCard({
    super.key,
    required this.distanceKm,
    required this.etaMinutes,
    this.elapsedMinutes,
    required this.progress,
    required this.isDark,
  });

  String get _distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toInt()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get _etaText {
    if (etaMinutes < 1) return 'Llegando...';
    if (etaMinutes == 1) return '1 min';
    return '$etaMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Info principal
          Row(
            children: [
              // Icono destino con fondo gradiente
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Distancia
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _distanceText,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[900],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'hasta el destino',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Badges de tiempo
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Elapsed
                  if (elapsedMinutes != null) ...[
                    _buildTimeBadge(
                      icon: Icons.timer_outlined,
                      text: '$elapsedMinutes min',
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // ETA
                  _buildTimeBadge(
                    icon: Icons.access_time_rounded,
                    text: _etaText,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Barra de progreso moderna
          Stack(
            children: [
              // Background
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Foreground con gradiente
              FractionallySizedBox(
                widthFactor: progress.clamp(0, 1),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.blue600],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Texto de progreso
          Text(
            '${(progress * 100).toInt()}% del viaje completado',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
