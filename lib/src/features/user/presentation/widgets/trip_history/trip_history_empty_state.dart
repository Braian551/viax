import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Estado vacío animado para cuando no hay viajes
class TripHistoryEmptyState extends StatefulWidget {
  final String? filterText;
  final VoidCallback? onRefresh;
  final bool isDark;

  const TripHistoryEmptyState({
    super.key,
    this.filterText,
    this.onRefresh,
    this.isDark = false,
  });

  @override
  State<TripHistoryEmptyState> createState() => _TripHistoryEmptyStateState();
}

class _TripHistoryEmptyStateState extends State<TripHistoryEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _fadeController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _bounceAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono animado con Glow
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      ),
                      // Circle
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          size: 45,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Título
                Text(
                  widget.filterText != null
                      ? 'No hay viajes ${widget.filterText}'
                      : 'Aún no tienes viajes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Descripción
                Text(
                  widget.filterText != null
                      ? 'Prueba cambiando los filtros para ver otros resultados.'
                      : 'Tus viajes realizados aparecerán aquí.\n¡Pide tu primer viaje hoy!',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Botón de refrescar
                if (widget.onRefresh != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onRefresh,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              const Color(0xFF1976D2), // Darker blue
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Actualizar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
