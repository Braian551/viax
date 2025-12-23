import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Estado vacío cuando no hay vehículo registrado
class VehicleEmptyState extends StatefulWidget {
  final VoidCallback? onRegister;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const VehicleEmptyState({
    super.key,
    this.onRegister,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<VehicleEmptyState> createState() => _VehicleEmptyStateState();
}

class _VehicleEmptyStateState extends State<VehicleEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isError = widget.errorMessage != null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: (isError ? AppColors.error : AppColors.primary)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isError
                            ? Icons.error_outline_rounded
                            : Icons.directions_car_outlined,
                        size: 60,
                        color: isError ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isError ? 'Error al cargar' : 'Sin Vehículo Registrado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isError
                          ? widget.errorMessage!
                          : 'Registra tu vehículo para comenzar a recibir solicitudes de viaje.',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.white70
                            : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isError && widget.onRetry != null)
                      OutlinedButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    else if (widget.onRegister != null)
                      ElevatedButton.icon(
                        onPressed: widget.onRegister,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Registrar Vehículo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
