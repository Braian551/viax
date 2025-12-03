import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../theme/app_colors.dart';

// ============================================================================
// COMPONENTES GLASS REUTILIZABLES
// ============================================================================

/// Contenedor glass morphism
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
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.7),
                        ],
                ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.8)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
}

/// Botón glass morphism
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (activeColor ?? AppColors.primary).withOpacity(0.3),
                          (activeColor ?? AppColors.primary).withOpacity(0.15),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.06),
                              ]
                            : [
                                Colors.white.withOpacity(0.95),
                                Colors.white.withOpacity(0.8),
                              ],
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? (activeColor ?? AppColors.primary).withOpacity(0.5)
                      : (isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.8)),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: (activeColor ?? AppColors.primary).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill glass para títulos
class GlassPill extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const GlassPill({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.06),
                    ]
                  : [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.8),
                    ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Punto pulsante animado para indicador de estado
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 10,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.6),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// WIDGETS FACTORY PARA LA PANTALLA DE VIAJE ACTIVO
// ============================================================================

/// Widgets premium para la pantalla de viaje activo del conductor
/// Diseño glass morphism con animaciones fluidas
class ActiveTripWidgets {
  /// AppBar premium con efecto glass
  static PreferredSizeWidget buildAppBar(
    BuildContext context, {
    required bool isDark,
    required bool toPickup,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GlassButton(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context, true);
          },
          isDark: isDark,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.grey[800],
            size: 18,
          ),
        ),
      ),
      title: GlassPill(
        isDark: isDark,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsingDot(
              color: toPickup ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: 10),
            Text(
              toPickup ? 'Ir a recoger' : 'Hacia destino',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GlassButton(
            onTap: () {
              HapticFeedback.lightImpact();
            },
            isDark: isDark,
            child: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  /// Botón de control del mapa con efecto glass premium
  static Widget buildMapControlButton(
    IconData icon,
    VoidCallback onTap,
    bool isDark, {
    bool isActive = false,
    Color? activeColor,
  }) {
    return GlassButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      isDark: isDark,
      isActive: isActive,
      activeColor: activeColor,
      size: 50,
      child: Icon(
        icon,
        color: isActive
            ? (activeColor ?? AppColors.primary)
            : (isDark ? Colors.white : Colors.grey[700]),
        size: 22,
      ),
    );
  }

  /// Indicador de velocidad premium con efecto glow
  static Widget buildSpeedIndicator(bool isDark, double currentSpeed) {
    final speedInt = currentSpeed.toInt();
    final isMoving = speedInt > 0;

    return GlassContainer(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$speedInt',
            style: TextStyle(
              color: isMoving
                  ? AppColors.primary
                  : (isDark ? Colors.white : Colors.grey[800]),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'km/h',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta simple de próxima maniobra
  static Widget buildNextManeuverCard(
    bool isDark, {
    required String distText,
    required int etaMinutes,
    required bool toPickup,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.blue600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de maniobra
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.straight_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          // Información de distancia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  toPickup
                      ? 'hacia el punto de recogida'
                      : 'hacia el destino final',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Badge de tiempo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
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
          ),
        ],
      ),
    );
  }

  /// Indicador de carga premium
  static Widget buildLoadingIndicator(bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: GlassContainer(
            isDark: isDark,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Calculando ruta...',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner de error premium
  static Widget buildErrorBanner(String error, {VoidCallback? onDismiss}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.error,
                  AppColors.error.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tarjeta de información compacta
  static Widget buildInfoCard(
    IconData icon,
    String value,
    String label,
    bool isDark, {
    Color? iconColor,
  }) {
    return GlassContainer(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withOpacity(0.15),
          AppColors.blue700.withOpacity(0.08),
        ],
      ),
      borderColor: AppColors.primary.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
