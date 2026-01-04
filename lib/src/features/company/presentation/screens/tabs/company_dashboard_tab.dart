import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyDashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToDrivers;
  final VoidCallback? onNavigateToPricing;
  final VoidCallback? onNavigateToDocumentos;

  const CompanyDashboardTab({
    super.key,
    this.onNavigateToDrivers,
    this.onNavigateToPricing,
    this.onNavigateToDocumentos,
  });

  @override
  State<CompanyDashboardTab> createState() => _CompanyDashboardTabState();
}

class _CompanyDashboardTabState extends State<CompanyDashboardTab> {
  // We can keep specific state here if needed, or rely on Provider

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoadingCompany;
        final errorMessage = provider.errorMessage;

        if (isLoading) {
             return const Center(child: CircularProgressIndicator());
        }

        if (errorMessage != null) {
          return Center(
            child: Text(
              'Error loading dashboard: $errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSection(isDark),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Panel de Control', isDark),
                    const SizedBox(height: 16),
                    _buildDashboardGrid(context),
                    const SizedBox(height: 32),
                    _buildPromoSection(isDark),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final isLoading = provider.isLoadingStats;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      provider.viajesHoy.toString(),
                      'Viajes Hoy',
                      Icons.route_rounded,
                      Colors.blue,
                    ),
                    _buildStatItem(
                      provider.totalConductores.toString(),
                      'Conductores',
                      Icons.people_rounded,
                      Colors.orange,
                    ),
                    _buildStatItem(
                      provider.gananciasDisplay,
                      'Ganancias',
                      Icons.payments_rounded,
                      Colors.green,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.0, // Ajustado para evitar overflow
      children: [
        _buildModernDashboardCard(
          context,
          'Conductores',
          'Gestionar flota',
          Icons.group_rounded,
          AppColors.primary,
          widget.onNavigateToDrivers ?? () {},
        ),
        _buildModernDashboardCard(
          context,
          'Documentos',
          'Verificar docs',
          Icons.description_rounded,
          Colors.amber,
          widget.onNavigateToDocumentos ?? () {},
        ),
        _buildModernDashboardCard(
          context,
          'Tarifas',
          'Configurar precios',
          Icons.attach_money_rounded,
          Colors.green,
          widget.onNavigateToPricing ?? () {},
        ),
        _buildModernDashboardCard(
          context,
          'Reportes',
          'Estadísticas',
          Icons.bar_chart_rounded,
          Colors.orange,
          () {},
        ),
      ],
    );
  }

  Widget _buildModernDashboardCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
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
              child: Icon(icon, color: color, size: 24),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimiza tus Ganancias',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configura tarifas personalizadas para aumentar ingresos.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}
