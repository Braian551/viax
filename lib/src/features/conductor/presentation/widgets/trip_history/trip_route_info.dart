import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Información de ruta con icono y línea conectora
/// Muestra origen y destino de manera visual
class TripRouteInfo extends StatelessWidget {
  final String? origin;
  final String? destination;
  final bool showConnector;

  const TripRouteInfo({
    super.key,
    this.origin,
    this.destination,
    this.showConnector = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    
    return Column(
      children: [
        _RoutePoint(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.success,
          text: origin ?? 'Punto de recogida',
          textColor: textColor,
          isDark: isDark,
        ),
        if (showConnector) _RouteConnector(isDark: isDark),
        _RoutePoint(
          icon: Icons.flag_rounded,
          iconColor: AppColors.error,
          text: destination ?? 'Destino',
          textColor: textColor,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final bool isDark;

  const _RoutePoint({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RouteConnector extends StatelessWidget {
  final bool isDark;

  const _RouteConnector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.6),
                  AppColors.error.withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
