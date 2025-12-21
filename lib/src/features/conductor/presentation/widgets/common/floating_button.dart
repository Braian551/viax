import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Botón flotante simple con soporte para estado activo.
/// 
/// Usado para controles del mapa y acciones secundarias.
class FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final double size;
  final bool isActive;
  final Color? activeColor;

  const FloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.size = 48,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive
                ? effectiveActiveColor.withValues(alpha: 0.15)
                : (isDark ? Colors.black54 : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(
                    color: effectiveActiveColor.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isActive
                ? effectiveActiveColor
                : (isDark ? Colors.white70 : Colors.grey[700]),
            size: 22,
          ),
        ),
      ),
    );
  }
}
