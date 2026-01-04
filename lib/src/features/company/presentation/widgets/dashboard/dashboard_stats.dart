import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingStats) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark 
                ? AppColors.darkSurface.withValues(alpha: 0.5) 
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                value: provider.viajesHoy.toString(),
                label: 'Viajes Hoy',
                icon: Icons.directions_car_filled_rounded,
                color: Colors.blueAccent,
              ),
              _buildDivider(context),
              _buildStatItem(
                context,
                value: provider.totalConductores.toString(),
                label: 'Conductores',
                icon: Icons.people_alt_rounded,
                color: Colors.orangeAccent,
              ),
              _buildDivider(context),
              _buildStatItem(
                context,
                value: provider.gananciasDisplay,
                label: 'Ganancias',
                icon: Icons.attach_money_rounded,
                color: Colors.greenAccent,
                isMoney: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    bool isMoney = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: isMoney ? 16 : 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
    );
  }
}
