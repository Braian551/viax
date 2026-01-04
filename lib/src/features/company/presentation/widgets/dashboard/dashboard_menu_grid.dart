import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class DashboardMenuGrid extends StatelessWidget {
  final VoidCallback? onDriversTap;
  final VoidCallback? onDocumentsTap;
  final VoidCallback? onPricingTap;
  final VoidCallback? onReportsTap;

  const DashboardMenuGrid({
    super.key,
    this.onDriversTap,
    this.onDocumentsTap,
    this.onPricingTap,
    this.onReportsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel de Control',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildMenuItem(
                context,
                title: 'Conductores',
                subtitle: 'Gestionar flota',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                onTap: onDriversTap,
              ),
              _buildMenuItem(
                context,
                title: 'Documentos',
                subtitle: 'Verificar docs',
                icon: Icons.checklist_rtl_rounded,
                color: Colors.amber,
                onTap: onDocumentsTap,
              ),
              _buildMenuItem(
                context,
                title: 'Tarifas',
                subtitle: 'Configurar precios',
                icon: Icons.monetization_on_rounded,
                color: Colors.green,
                onTap: onPricingTap,
              ),
              _buildMenuItem(
                context,
                title: 'Reportes',
                subtitle: 'Ver estadísticas',
                icon: Icons.bar_chart_rounded,
                color: Colors.orange,
                onTap: onReportsTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.darkSurface.withValues(alpha: 0.5) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
