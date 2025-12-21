import 'dart:ui';
import 'package:flutter/material.dart';

/// Contenedor con efecto glass morphism reutilizable.
/// 
/// Proporciona un fondo difuminado con gradiente y bordes sutiles,
/// ideal para crear interfaces modernas estilo iOS/DiDi.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets? padding;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderRadius;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    required this.isDark,
    this.padding,
    this.gradient,
    this.borderColor,
    this.borderRadius = 16,
    this.blur = 15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ?? _defaultGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? _defaultBorderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  LinearGradient get _defaultGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ]
            : [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.7),
              ],
      );

  Color get _defaultBorderColor => isDark
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.white.withValues(alpha: 0.8);
}
