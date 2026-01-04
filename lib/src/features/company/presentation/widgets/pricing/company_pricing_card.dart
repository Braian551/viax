import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyPricingCard extends StatelessWidget {
  final Map<String, dynamic> config;
  final VoidCallback onTap;
  
  const CompanyPricingCard({
    super.key,
    required this.config,
    required this.onTap,
  });

  static const Map<String, String> _vehicleTypeNames = {
    'moto': 'Moto',
    'auto': 'Auto',
    'motocarro': 'Motocarro',
  };

  static const Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
    'auto': Icons.directions_car_rounded,
    'motocarro': Icons.electric_rickshaw_rounded,
  };

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = double.tryParse(value.toString()) ?? 0.0;
    return number.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipo = config['tipo_vehiculo'];
    final icon = _vehicleTypeIcons[tipo] ?? Icons.local_shipping_rounded;
    final nombre = _vehicleTypeNames[tipo] ?? tipo?.toString().toUpperCase() ?? 'Vehículo';
    final isGlobal = config['es_global'] == true || config['heredado'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.05 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isGlobal)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Usando tarifa estándar',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildDataRow(context, 'Tarifa Base', '\$${_formatNumber(config['tarifa_base'])}', isDark),
                  _buildDataRow(context, 'Costo/Km', '\$${_formatNumber(config['costo_por_km'])}', isDark, highlight: true),
                  _buildDataRow(context, 'Costo/Min', '\$${_formatNumber(config['costo_por_minuto'])}', isDark, highlight: true),
                  _buildDataRow(context, 'Mínimo', '\$${_formatNumber(config['tarifa_minima'])}', isDark),
                  const SizedBox(height: 8),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  const SizedBox(height: 8),
                  _buildDataRow(context, 'Recargo H. Pico', '${config['recargo_hora_pico'] ?? 0}%', isDark, color: AppColors.warning),
                  _buildDataRow(context, 'Rec. Nocturno', '${config['recargo_nocturno'] ?? 0}%', isDark, color: const Color(0xFF5E5CE6)),
                  _buildDataRow(context, 'Tu Comisión', '${config['comision_plataforma'] ?? 0}%', isDark, color: AppColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String value, bool isDark, {Color? color, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Container(
            padding: highlight ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : EdgeInsets.zero,
            decoration: highlight
                ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? (highlight ? AppColors.primary : Theme.of(context).colorScheme.onSurface),
                fontSize: highlight ? 15 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
