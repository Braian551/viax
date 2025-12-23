import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Tarjeta principal con información del vehículo
class VehicleInfoCard extends StatefulWidget {
  final Map<String, dynamic>? vehicleData;
  final VoidCallback? onEdit;

  const VehicleInfoCard({
    super.key,
    this.vehicleData,
    this.onEdit,
  });

  @override
  State<VehicleInfoCard> createState() => _VehicleInfoCardState();
}

class _VehicleInfoCardState extends State<VehicleInfoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
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

    final marca = widget.vehicleData?['marca'] ?? 'Sin registrar';
    final modelo = widget.vehicleData?['modelo'] ?? '';
    final anio = widget.vehicleData?['anio']?.toString() ?? '';
    final placa = widget.vehicleData?['placa'] ?? 'Sin placa';
    final color = widget.vehicleData?['color'] ?? 'No especificado';
    final tipoVehiculo = widget.vehicleData?['tipo_vehiculo'] ?? 'auto';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.darkCard.withValues(alpha: 0.8),
                            ]
                          : [
                              AppColors.primary.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.9),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Icono del vehículo
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getVehicleIcon(tipoVehiculo),
                              size: 38,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info del vehículo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$marca $modelo',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                if (anio.isNotEmpty)
                                  Text(
                                    anio,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Botón editar
                          if (widget.onEdit != null)
                            IconButton(
                              onPressed: widget.onEdit,
                              icon: Icon(
                                Icons.edit_rounded,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Editar vehículo',
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Placa destacada
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.confirmation_number_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              placa.toUpperCase(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Color
                      Row(
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white54
                                : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Color: $color',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getVehicleIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'camioneta':
        return Icons.local_shipping_rounded;
      case 'van':
        return Icons.airport_shuttle_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }
}
