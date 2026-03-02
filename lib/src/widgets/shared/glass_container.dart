import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Contenedor con efecto glass (glassmorphism) reutilizable.
/// Sigue el estilo moderno del sitio web con colores sólidos y efecto blur.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final double blurSigma;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.borderWidth = 1,
    this.blurSigma = 12,
    this.backgroundColor,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = backgroundColor ??
        (isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : AppColors.lightSurface.withValues(alpha: 0.75));

    final border = borderColor ??
        (isDark
            ? AppColors.darkDivider.withValues(alpha: 0.4)
            : AppColors.lightDivider.withValues(alpha: 0.5));

    Widget container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          margin: margin,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: borderWidth),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

/// Variante de GlassContainer con un color de acento sólido.
class AccentGlassContainer extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const AccentGlassContainer({
    super.key,
    required this.child,
    required this.accentColor,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: accentColor.withValues(alpha: 0.08),
      borderColor: accentColor.withValues(alpha: 0.25),
      onTap: onTap,
      child: child,
    );
  }
}
