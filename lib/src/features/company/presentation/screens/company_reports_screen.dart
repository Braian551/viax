import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_header.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_summary_cards.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_chart_card.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_top_drivers.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_vehicle_distribution.dart';
import 'package:viax/src/features/company/presentation/widgets/reports/reports_peak_hours.dart';
import 'package:viax/src/theme/app_colors.dart';

class CompanyReportsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyReportsScreen({super.key, required this.user});

  @override
  State<CompanyReportsScreen> createState() => _CompanyReportsScreenState();
}

class _CompanyReportsScreenState extends State<CompanyReportsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadReports();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: _buildAppBar(context, isDark),
      body: Consumer<CompanyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingReports && provider.reportsData == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.reportsError != null && provider.reportsData == null) {
            return _buildErrorState(context, provider);
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: RefreshIndicator(
              onRefresh: () => provider.loadReports(),
              color: AppColors.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Header con selector de periodo
                  SliverToBoxAdapter(
                    child: ReportsHeader(
                      selectedPeriod: provider.selectedReportPeriod,
                      onPeriodChanged: (period) =>
                          provider.setReportPeriod(period),
                      isLoading: provider.isLoadingReports,
                    ),
                  ),

                  // Tarjetas de resumen
                  if (provider.reportsData != null) ...[
                    const SliverToBoxAdapter(child: ReportsSummaryCards()),

                    // Gráfico de tendencias
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    const SliverToBoxAdapter(child: ReportsChartCard()),

                    // Top Conductores
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    const SliverToBoxAdapter(child: ReportsTopDrivers()),

                    // Distribución por vehículo
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    const SliverToBoxAdapter(
                      child: ReportsVehicleDistribution(),
                    ),

                    // Horas pico
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    const SliverToBoxAdapter(child: ReportsPeakHours()),

                    // Espacio final
                    const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : AppColors.lightTextPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Reportes Avanzados',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
          ),
          onPressed: () => context.read<CompanyProvider>().loadReports(),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, CompanyProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar reportes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.reportsError ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadReports(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
