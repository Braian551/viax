import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Sección con detalles adicionales del vehículo
class VehicleDetailsSection extends StatefulWidget {
  final Map<String, dynamic>? vehicleData;

  const VehicleDetailsSection({
    super.key,
    this.vehicleData,
  });

  @override
  State<VehicleDetailsSection> createState() => _VehicleDetailsSectionState();
}

class _VehicleDetailsSectionState extends State<VehicleDetailsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
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

    final capacidad = widget.vehicleData?['capacidad_pasajeros']?.toString() ?? '4';
    final tipoVehiculo = widget.vehicleData?['tipo_vehiculo'] ?? 'auto';
    final combustible = widget.vehicleData?['combustible'] ?? 'Gasolina';
    final aireAcondicionado = widget.vehicleData?['aire_acondicionado'] ?? true;

    final details = [
      _DetailItem(
        icon: Icons.people_rounded,
        label: 'Capacidad',
        value: '$capacidad pasajeros',
      ),
      _DetailItem(
        icon: Icons.category_rounded,
        label: 'Tipo',
        value: _formatVehicleType(tipoVehiculo),
      ),
      _DetailItem(
        icon: Icons.local_gas_station_rounded,
        label: 'Combustible',
        value: combustible,
      ),
      _DetailItem(
        icon: Icons.ac_unit_rounded,
        label: 'A/C',
        value: aireAcondicionado ? 'Sí' : 'No',
      ),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles del Vehículo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard.withValues(alpha: 0.6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: details.asMap().entries.map((entry) {
                      final index = entry.key;
                      final detail = entry.value;
                      final isLast = index == details.length - 1;

                      return Column(
                        children: [
                          _buildDetailRow(detail, isDark),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.withValues(alpha: 0.15),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(_DetailItem detail, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              detail.icon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              detail.label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Text(
            detail.value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatVehicleType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'auto':
        return 'Automóvil';
      case 'moto':
        return 'Motocicleta';
      case 'camioneta':
        return 'Camioneta';
      case 'van':
        return 'Van';
      default:
        return tipo;
    }
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;

  _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
