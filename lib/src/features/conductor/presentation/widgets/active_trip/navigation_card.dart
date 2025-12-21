import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Tarjeta de navegación con gradiente para mostrar distancia y tiempo.
/// 
/// Diseño estilo DiDi/Uber con información de la siguiente maniobra.
class NavigationCard extends StatelessWidget {
  final String distanceText;
  final int etaMinutes;
  final bool toPickup;
  final bool isDark;

  const NavigationCard({
    super.key,
    required this.distanceText,
    required this.etaMinutes,
    required this.toPickup,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.blue600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildDirectionIcon(),
          const SizedBox(width: 14),
          Expanded(child: _buildDistanceInfo()),
          _buildTimeBadge(),
        ],
      ),
    );
  }

  Widget _buildDirectionIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.straight_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildDistanceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          distanceText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          toPickup ? 'hacia el punto de recogida' : 'hacia el destino',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '$etaMinutes min',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
