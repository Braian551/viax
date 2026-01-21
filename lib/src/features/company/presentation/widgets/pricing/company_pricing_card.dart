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
    'motocarro': 'Motocarro',
    'taxi': 'Taxi',
    'carro': 'Carro',
  };

  static const Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
    'motocarro': Icons.electric_rickshaw_rounded,
    'taxi': Icons.local_taxi_rounded,
    'carro': Icons.directions_car_rounded,
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
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header - Subtle blue, not garish
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.blue900.withValues(alpha: 0.4) : AppColors.blue50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isGlobal)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Usando tarifa estándar',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                  ),
                ],
              ),
            ),
            
            // Content - Clean and minimal
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRow(context, 'Tarifa Base', '\$${_formatNumber(config['tarifa_base'])}', isDark),
                  _buildRow(context, 'Costo/Km', '\$${_formatNumber(config['costo_por_km'])}', isDark),
                  _buildRow(context, 'Costo/Min', '\$${_formatNumber(config['costo_por_minuto'])}', isDark),
                  _buildRow(context, 'Mínimo', '\$${_formatNumber(config['tarifa_minima'])}', isDark),
                  
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, height: 1),
                  const SizedBox(height: 12),
                  
                  // Stats row - neutral colors, not colorful
                  Row(
                    children: [
                      Expanded(child: _buildStat(context, 'Recargo H.P.', '${config['recargo_hora_pico'] ?? 0}%', isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStat(context, 'Rec. Noct.', '${config['recargo_nocturno'] ?? 0}%', isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStat(context, 'Comisión', '${config['comision_plataforma'] ?? 0}%', isDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
