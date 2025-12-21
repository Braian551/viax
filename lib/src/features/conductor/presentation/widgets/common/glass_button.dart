import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Botón con efecto glass morphism.
/// 
/// Soporta estado activo con color personalizado y efecto glow.
class GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;
  final bool isActive;
  final Color? activeColor;
  final double size;

  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.isDark,
    this.isActive = false,
    this.activeColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
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
                gradient: _buildGradient(effectiveActiveColor),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _borderColor(effectiveActiveColor),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: _buildShadows(effectiveActiveColor),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _buildGradient(Color activeClr) {
    if (isActive) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          activeClr.withValues(alpha: 0.3),
          activeClr.withValues(alpha: 0.15),
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ]
          : [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.8),
            ],
    );
  }

  Color _borderColor(Color activeClr) {
    if (isActive) return activeClr.withValues(alpha: 0.5);
    return isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.8);
  }

  List<BoxShadow> _buildShadows(Color activeClr) {
    return [
      if (isActive)
        BoxShadow(
          color: activeClr.withValues(alpha: 0.3),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
