import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Widget para mostrar información en formato chip (distancia, tiempo, etc)
/// 
/// Usado principalmente en paneles de solicitud de viaje para mostrar
/// métricas como distancia, tiempo estimado, precio, etc.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final String? label;
  final bool isDark;
  final double iconSize;
  final double fontSize;

  const InfoChip({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.label,
    this.isDark = true,
    this.iconSize = 16,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: iconSize,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.95) 
                    : Colors.grey[800],
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(
            label!,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget para mostrar información de ubicación con ícono y etiqueta
/// 
/// Usado para mostrar direcciones de origen/destino en paneles de viaje
class LocationInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final double iconContainerSize;

  const LocationInfoTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isDark = true,
    this.iconContainerSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: iconContainerSize,
          height: iconContainerSize,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget para el indicador de arrastre (drag handle) del panel
class PanelDragHandle extends StatelessWidget {
  final bool isDark;
  final double width;
  final double height;

  const PanelDragHandle({
    super.key,
    this.isDark = true,
    this.width = 45,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Widget para mostrar el temporizador circular con animación
class CircularTimerWidget extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final int seconds;
  final Color color;
  final double size;
  final bool isDark;

  const CircularTimerWidget({
    super.key,
    required this.progress,
    required this.seconds,
    required this.color,
    this.size = 52,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo del círculo
          SizedBox(
            width: size - 8,
            height: size - 8,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
          ),
          // Progreso animado
          SizedBox(
            width: size - 8,
            height: size - 8,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Segundos
          Text(
            '$seconds',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget para el badge de distancia entre conductor y cliente
class DistanceBadge extends StatelessWidget {
  final double distanceKm;
  final int? etaMinutes;
  final bool isDark;

  const DistanceBadge({
    super.key,
    required this.distanceKm,
    this.etaMinutes,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasEta = etaMinutes != null && etaMinutes! > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasEta) ...[
            const SizedBox(height: 2),
            Text(
              '~$etaMinutes min',
              style: TextStyle(
                color: AppColors.success.withValues(alpha: 0.8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget para botón de acción del viaje (Aceptar/Rechazar)
class TripActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final double? scale;
  final bool isDark;

  const TripActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = false,
    this.scale,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveScale = scale ?? 1.0;
    
    return Transform.scale(
      scale: effectiveScale,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary 
              ? color 
              : color.withValues(alpha: 0.15),
          foregroundColor: isPrimary ? Colors.white : color,
          padding: EdgeInsets.symmetric(
            horizontal: isPrimary ? 32 : 24,
            vertical: isPrimary ? 16 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isPrimary ? 20 : 16),
            side: isPrimary 
                ? BorderSide.none 
                : BorderSide(color: color.withValues(alpha: 0.3)),
          ),
          elevation: isPrimary ? 8 : 0,
          shadowColor: isPrimary ? color.withValues(alpha: 0.5) : null,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPrimary ? Colors.white : color,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: isPrimary ? 22 : 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isPrimary ? 16 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Widget separador con línea punteada vertical
class DottedLineSeparator extends StatelessWidget {
  final double height;
  final Color? color;
  final bool isDark;

  const DottedLineSeparator({
    super.key,
    this.height = 20,
    this.color,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? 
        (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.3));
    
    return Padding(
      padding: const EdgeInsets.only(left: 17), // Centrar con iconos de 36px
      child: Column(
        children: List.generate(
          (height / 8).floor(),
          (index) => Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}
