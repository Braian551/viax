import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsSummaryCards extends StatelessWidget {
  const ReportsSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final data = provider.reportsData;
        if (data == null) return const SizedBox.shrink();

        final tripStats = data.tripStats;
        final earningsStats = data.earningsStats;
        final trends = data.trends;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Primera fila - Viajes e Ingresos
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Viajes Totales',
                      value: tripStats.total.toString(),
                      subtitle: '${tripStats.completados} completados',
                      icon: Icons.route_rounded,
                      color: AppColors.primary,
                      trend: trends.viajes,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Ingresos',
                      value:
                          '\$${_formatNumber(earningsStats.ingresosTotales)}',
                      subtitle:
                          'Prom: \$${earningsStats.ingresoPromedio.toStringAsFixed(0)}',
                      icon: Icons.attach_money_rounded,
                      color: AppColors.success,
                      trend: trends.ingresos,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Segunda fila - Tasa de completados y Distancia
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Tasa Éxito',
                      value: '${tripStats.tasaCompletados}%',
                      subtitle: '${tripStats.cancelados} cancelados',
                      icon: Icons.check_circle_rounded,
                      color: tripStats.tasaCompletados >= 80
                          ? AppColors.success
                          : (tripStats.tasaCompletados >= 60
                                ? AppColors.warning
                                : AppColors.error),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Distancia Total',
                      value: '${_formatNumber(tripStats.distanciaTotal)} km',
                      subtitle:
                          'Prom: ${tripStats.distanciaPromedio.toStringAsFixed(1)} km',
                      icon: Icons.straighten_rounded,
                      color: AppColors.accent,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tercera fila - Conductores y Ganancia Neta
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Conductores',
                      value: data.driverStats.activos.toString(),
                      subtitle: '${data.driverStats.total} total',
                      icon: Icons.people_rounded,
                      color: Colors.orangeAccent,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      title: 'Ganancia Neta',
                      value: '\$${_formatNumber(earningsStats.gananciaNeta)}',
                      subtitle:
                          'Comisión: \$${earningsStats.comisionEmpresa.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    dynamic trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (trend != null) _buildTrendBadge(trend, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : AppColors.lightTextHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge(dynamic trend, bool isDark) {
    final isPositive = trend.isPositive;
    final color = isPositive ? AppColors.success : AppColors.error;
    final icon = isPositive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 2),
          Text(
            '${trend.cambioPorcentaje.abs().toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
