import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:viax/src/theme/app_colors.dart';

/// Widget reutilizable para el logo con animación
/// Se usa tanto en splash como en welcome para crear transición fluida
class AnimatedLogo extends StatelessWidget {
  final double size;
  final double glowOpacity;
  final double scale;
  final double rotation;
  final bool showGlow;
  
  const AnimatedLogo({
    super.key,
    this.size = 86,
    this.glowOpacity = 0.25,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final containerSize = size * 1.5;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Ajustar opacidad del glow según el tema
    final adjustedGlowOpacity = isDark ? glowOpacity : glowOpacity * 0.4;
    
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: showGlow
                ? RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: adjustedGlowOpacity * 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.9],
                  )
                : null,
            boxShadow: showGlow
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.03),
                      blurRadius: isDark ? 30 : 15,
                      spreadRadius: isDark ? 8 : 3,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.02),
                      blurRadius: isDark ? 50 : 25,
                      spreadRadius: isDark ? 15 : 5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                  stops: [0.3, 1.0],
                ).createShader(bounds);
              },
              child: Image.asset(
                'assets/images/logo.png',
                width: size,
                height: size,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador de carga con energía mágica
class LoadingEnergy extends StatefulWidget {
  const LoadingEnergy({super.key});

  @override
  State<LoadingEnergy> createState() => _LoadingEnergyState();
}

class _LoadingEnergyState extends State<LoadingEnergy> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final List<Animation<double>> _particleAnimations;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Crear animaciones para 8 partículas de energía
    _particleAnimations = List.generate(8, (index) {
      return Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            1.0,
            curve: Curves.linear,
          ),
        ),
      );
    });

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _pulseController]),
      builder: (context, child) {
        return Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Partículas de energía orbitando
              ...List.generate(8, (index) {
                final angle = _particleAnimations[index].value;
                final radius = 25 + (5 * math.sin(angle * 2));
                final x = radius * math.cos(angle + index * 0.2);
                final y = radius * math.sin(angle + index * 0.2);

                return Transform.translate(
                  offset: Offset(x, y),
                  child: Container(
                    width: 3 + (math.sin(angle * 3) * 2),
                    height: 3 + (math.sin(angle * 3) * 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Anillo de energía pulsante
              Container(
                width: 50 + (10 * _glowAnimation.value),
                height: 50 + (10 * _glowAnimation.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: _glowAnimation.value * 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),

              // Núcleo de energía
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),

              // Chispas aleatorias
              ...List.generate(3, (index) {
                final randomAngle = math.sin(_controller.value * 2 + index) * math.pi * 2;
                final randomRadius = 35 + math.cos(_controller.value * 3 + index) * 10;
                final sparkX = randomRadius * math.cos(randomAngle);
                final sparkY = randomRadius * math.sin(randomAngle);

                return Transform.translate(
                  offset: Offset(sparkX, sparkY),
                  child: Container(
                    width: 2,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Transición Hero personalizada para el logo
class LogoHeroTransition extends StatelessWidget {
  final Widget child;
  final String tag;

  const LogoHeroTransition({
    super.key,
    required this.child,
    this.tag = 'app_logo',
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            // Animación de transformación durante el vuelo
            return Transform.scale(
              scale: 1.0 + (0.2 * animation.value),
              child: Transform.rotate(
                angle: animation.value * 0.1,
                child: Opacity(
                  opacity: 1.0,
                  child: toHeroContext.widget,
                ),
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
