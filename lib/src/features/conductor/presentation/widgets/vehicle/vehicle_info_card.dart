import 'package:flutter/material.dart';
import 'package:viax/src/core/utils/colombian_plate_utils.dart';

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

    final marca = widget.vehicleData?['vehiculo_marca'] ?? widget.vehicleData?['marca'] ?? 'Marca';
    final modelo = widget.vehicleData?['vehiculo_modelo'] ?? widget.vehicleData?['modelo'] ?? 'Modelo';
    final anio = widget.vehicleData?['vehiculo_anio']?.toString() ?? widget.vehicleData?['anio']?.toString() ?? '';
    final placa = ColombianPlateUtils.formatForDisplay(
      widget.vehicleData?['vehiculo_placa']?.toString() ?? widget.vehicleData?['placa']?.toString(),
    );
    final color = widget.vehicleData?['vehiculo_color'] ?? widget.vehicleData?['color'] ?? 'Color';
    final tipoVehiculo = widget.vehicleData?['vehiculo_tipo'] ?? widget.vehicleData?['tipo_vehiculo'] ?? 'auto';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE0F2FE), // SkyBlue 100
                    const Color(0xFFBAE6FD), // SkyBlue 200
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15), // SkyBlue 500
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getVehicleIcon(tipoVehiculo),
                          size: 32,
                          color: const Color(0xFF0284C7), // SkyBlue 600
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$marca $modelo',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C4A6E), // SkyBlue 900
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              anio,
                              style: TextStyle(
                                fontSize: 15,
                                color: const Color(0xFF0C4A6E).withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onEdit != null)
                        InkWell(
                          onTap: widget.onEdit,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Color(0xFF0284C7), // SkyBlue 600
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.grid_3x3_rounded,
                          color: Color(0xFF0284C7), // SkyBlue 600
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          placa,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Color(0xFF0C4A6E), // SkyBlue 900
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        size: 16,
                        color: const Color(0xFF0C4A6E).withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Color: $color',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF0C4A6E).withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
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
        return Icons.directions_car_filled_rounded;
    }
  }
}
