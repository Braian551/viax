import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_stats.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_menu_grid.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/promo_banner.dart';
import 'package:viax/src/features/company/services/company_platform_payment_service.dart';
import 'package:viax/src/features/company/presentation/widgets/vehicles/vehicle_management_sheet.dart';
import 'package:viax/src/features/company/presentation/screens/company_reports_screen.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';

class CompanyDashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToDrivers;
  final VoidCallback? onNavigateToPricing;
  final VoidCallback? onNavigateToDocumentos;
  final VoidCallback? onNavigateToCommissions;
  final VoidCallback? onNavigateToPlatformPayment;

  const CompanyDashboardTab({
    super.key,
    this.onNavigateToDrivers,
    this.onNavigateToPricing,
    this.onNavigateToDocumentos,
    this.onNavigateToCommissions,
    this.onNavigateToPlatformPayment,
  });

  @override
  State<CompanyDashboardTab> createState() => _CompanyDashboardTabState();
}

class _CompanyDashboardTabState extends State<CompanyDashboardTab> {
  bool _isLoadingPaymentContext = false;
  Map<String, dynamic>? _paymentContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaymentContext();
    });
  }

  Future<void> _loadPaymentContext() async {
    if (!mounted) return;
    setState(() => _isLoadingPaymentContext = true);
    try {
      final provider = context.read<CompanyProvider>();
      final result = await CompanyPlatformPaymentService.getDebtContext(
        empresaId: provider.empresaId,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _paymentContext =
              Map<String, dynamic>.from(result['data'] as Map? ?? {});
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context,
          message: 'No se pudo actualizar estado de pagos: $e',
          type: SnackbarType.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPaymentContext = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CompanyProvider>(
      builder: (context, provider, child) {
        // If critical data is missing, we might show loading, but
        // widgets handle their own loading usage where suitable.
        // Usually company profile is pre-loaded.

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // No AppBar here, Header provides the top section
            const SliverToBoxAdapter(child: DashboardHeader()),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            const SliverToBoxAdapter(child: DashboardStats()),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            SliverToBoxAdapter(child: _buildPaymentHealthCard(context)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: DashboardMenuGrid(
                onDriversTap: widget.onNavigateToDrivers,
                onDocumentsTap: widget.onNavigateToDocumentos,
                onPricingTap: widget.onNavigateToPricing,
                onCommissionsTap: widget.onNavigateToCommissions,
                onVehiclesTap: () => _showVehicleManagement(context),
                onReportsTap: () => _navigateToReports(context),
                onPlatformPaymentTap: widget.onNavigateToPlatformPayment,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: PromoBanner(onTap: () => _navigateToReports(context)),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        );
      },
    );
  }

  Widget _buildPaymentHealthCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deuda =
        double.tryParse(_paymentContext?['deuda_actual']?.toString() ?? '0') ??
            0;
    final estado = (_paymentContext?['estado_reporte'] ?? 'sin_reporte').toString();
    final cuenta =
        _paymentContext?['cuenta_transferencia'] as Map<String, dynamic>? ?? {};
    final hasCuenta = cuenta['configurada'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (deuda > 0 ? AppColors.error : AppColors.success)
                .withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  deuda > 0
                      ? Icons.account_balance_wallet_rounded
                      : Icons.verified_rounded,
                  color: deuda > 0 ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Salud de pagos con plataforma',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: _isLoadingPaymentContext
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _isLoadingPaymentContext ? null : _loadPaymentContext,
                  tooltip: 'Actualizar estado',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Deuda actual: ${deuda <= 0 ? 'Al día' : '\$${deuda.toStringAsFixed(0)}'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: deuda > 0 ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Último comprobante: ${estado.replaceAll('_', ' ')}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
              ),
            ),
            if (!hasCuenta) ...[
              const SizedBox(height: 10),
              Text(
                'Aún no hay cuenta/Nequi de recaudo configurado por el administrador.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: widget.onNavigateToPlatformPayment,
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Gestionar pago'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleManagement(BuildContext context) {
    final provider = context.read<CompanyProvider>();
    // provider.company returns the company details map
    final empresaId = provider.company?['id'] ?? provider.empresaId;

    // We will let the sheet load the enabled vehicles itself
    // or we could derive it from provider.pricing if loaded
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleManagementSheet(
        empresaId: empresaId,
        currentVehicleTypes: const [], // Sheet will load this
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    final provider = context.read<CompanyProvider>();
    final empresaId = provider.empresaId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CompanyProvider(empresaId: empresaId),
          child: CompanyReportsScreen(
            user: {'id': empresaId, 'empresa_id': empresaId},
          ),
        ),
      ),
    );
  }
}
