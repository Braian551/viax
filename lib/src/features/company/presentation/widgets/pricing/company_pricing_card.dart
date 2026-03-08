import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/features/user/presentation/widgets/trip_preview/trip_price_formatter.dart';
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
    'mototaxi': 'Mototaxi',
    'taxi': 'Taxi',
    'carro': 'Carro',
  };

  static const Map<String, IconData> _vehicleTypeIcons = {
    'moto': Icons.two_wheeler_rounded,
    'mototaxi': Icons.electric_rickshaw_rounded,
    'taxi': Icons.local_taxi_rounded,
    'carro': Icons.directions_car_rounded,
  };

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final number = double.tryParse(value.toString()) ?? 0.0;
    return formatCurrency(number, withSymbol: false);
  }

  String _formatPercent(dynamic value) {
    if (value == null) return '0%';
    final num = double.tryParse(value.toString()) ?? 0;
    if (num == num.truncateToDouble()) {
      return '${num.toInt()}%';
    }
    return '${num.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipo = config['tipo_vehiculo'];
    final icon = _vehicleTypeIcons[tipo] ?? Icons.local_shipping_rounded;
    final nombre = _vehicleTypeNames[tipo] ?? tipo?.toString().toUpperCase() ?? 'Vehículo';
    final isGlobal = config['es_global'] == true || config['heredado'] == true;
    final needsConfig = config['requiere_configuracion'] == true;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header con gradiente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [AppColors.blue900.withValues(alpha: 0.5), AppColors.blue900.withValues(alpha: 0.2)]
                          : [AppColors.blue50, AppColors.blue50.withValues(alpha: 0.3)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                              AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isGlobal)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      needsConfig ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: needsConfig
                                          ? (isDark ? Colors.orange[200] : Colors.orange[700])
                                          : (isDark ? Colors.white38 : AppColors.lightTextSecondary),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      needsConfig ? 'Configuración pendiente' : 'Tarifa estándar',
                                      style: TextStyle(
                                        color: needsConfig
                                            ? (isDark ? Colors.orange[200] : Colors.orange[700])
                                            : (isDark ? Colors.white38 : AppColors.lightTextSecondary),
                                        fontSize: 11,
                                        fontWeight: needsConfig ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 17),
                      ),
                    ],
                  ),
                ),

                // Contenido con métricas
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetric(context, 'Base', '\$${_formatNumber(config['tarifa_base'])}', isDark),
                      ),
                      _buildDivider(isDark),
                      Expanded(
                        child: _buildMetric(context, 'Por Km', '\$${_formatNumber(config['costo_por_km'])}', isDark),
                      ),
                      _buildDivider(isDark),
                      Expanded(
                        child: _buildMetric(context, 'Por Min', '\$${_formatNumber(config['costo_por_minuto'])}', isDark),
                      ),
                      _buildDivider(isDark),
                      Expanded(
                        child: _buildMetric(context, 'Mínimo', '\$${_formatNumber(config['tarifa_minima'])}', isDark),
                      ),
                    ],
                  ),
                ),

                // Tags de porcentajes
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      _buildTag(context, 'H.P.', _formatPercent(config['recargo_hora_pico']), isDark),
                      const SizedBox(width: 6),
                      _buildTag(context, 'Noct.', _formatPercent(config['recargo_nocturno']), isDark),
                      const SizedBox(width: 6),
                      _buildTag(context, 'Com.', _formatPercent(config['comision_plataforma']), isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
    );
  }

  Widget _buildTag(BuildContext context, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.primary.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
