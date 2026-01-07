import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class DashboardMenuGrid extends StatelessWidget {
  final VoidCallback? onDriversTap;
  final VoidCallback? onDocumentsTap;
  final VoidCallback? onPricingTap;
  final VoidCallback? onReportsTap;
  final VoidCallback? onVehiclesTap;

  const DashboardMenuGrid({
    super.key,
    this.onDriversTap,
    this.onDocumentsTap,
    this.onPricingTap,
    this.onReportsTap,
    this.onVehiclesTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel de Control',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          
          // Organized Grid Layout
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      title: 'Conductores',
                      subtitle: 'Flota',
                      icon: Icons.groups_rounded,
                      color: AppColors.primary,
                      onTap: onDriversTap,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      title: 'Documentos',
                      subtitle: 'Verificar',
                      icon: Icons.checklist_rtl_rounded,
                      color: AppColors.warning,
                      onTap: onDocumentsTap,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      title: 'Tarifas',
                      subtitle: 'Precios',
                      icon: Icons.attach_money_rounded,
                      color: AppColors.success,
                      onTap: onPricingTap,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuCard(
                      context,
                      title: 'Vehículos',
                      subtitle: 'Tipos',
                      icon: Icons.directions_car_rounded,
                      color: AppColors.info,
                      onTap: onVehiclesTap,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMenuCard(
                context,
                title: 'Reportes',
                subtitle: 'Estadísticas y análisis',
                icon: Icons.bar_chart_rounded,
                color: Colors.deepOrange,
                onTap: onReportsTap,
                isDark: isDark,
                isFullWidth: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isFullWidth)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
