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
          
          // Compact horizontal list of menu items
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCompactMenuItem(
                context,
                title: 'Conductores',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                onTap: onDriversTap,
                isDark: isDark,
              ),
              _buildCompactMenuItem(
                context,
                title: 'Documentos',
                icon: Icons.checklist_rtl_rounded,
                color: AppColors.warning,
                onTap: onDocumentsTap,
                isDark: isDark,
              ),
              _buildCompactMenuItem(
                context,
                title: 'Tarifas',
                icon: Icons.attach_money_rounded,
                color: AppColors.success,
                onTap: onPricingTap,
                isDark: isDark,
              ),
              _buildCompactMenuItem(
                context,
                title: 'Vehículos',
                icon: Icons.directions_car_rounded,
                color: AppColors.info,
                onTap: onVehiclesTap,
                isDark: isDark,
              ),
              _buildCompactMenuItem(
                context,
                title: 'Reportes',
                icon: Icons.bar_chart_rounded,
                color: Colors.deepOrange,
                onTap: onReportsTap,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
