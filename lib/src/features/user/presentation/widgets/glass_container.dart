import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

/// Contenedor con efecto glass/frosted moderno - Diseño Viax
/// Usa los colores de la app para consistencia visual
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final double? width;
  final double? height;
  final bool usePrimaryAccent;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 25,
    this.backgroundColor,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.boxShadow,
    this.border,
    this.width,
    this.height,
    this.usePrimaryAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Colores base con tinte azul de la app
    final baseColor = backgroundColor ?? (isDark 
        ? AppColors.darkCard.withOpacity(0.85)
        : Colors.white.withOpacity(0.9));
    
    final borderColor = usePrimaryAccent
        ? AppColors.primary.withOpacity(0.3)
        : (isDark 
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.6));

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: usePrimaryAccent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor,
                        baseColor.withOpacity(0.7),
                      ],
                    )
                  : null,
              color: usePrimaryAccent ? null : baseColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: boxShadow ?? [
                BoxShadow(
                  color: usePrimaryAccent
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: usePrimaryAccent ? 2 : 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botón con efecto glass
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = 16,
    this.padding,
    this.color,
    this.isLoading = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GlassContainer(
          borderRadius: widget.borderRadius,
          padding: widget.padding ?? const EdgeInsets.symmetric(
            horizontal: 20, 
            vertical: 14,
          ),
          backgroundColor: widget.color,
          child: widget.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : widget.child,
        ),
      ),
    );
  }
}
