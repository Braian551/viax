import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_stats.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_menu_grid.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/promo_banner.dart';
import 'package:viax/src/features/company/presentation/widgets/vehicles/vehicle_management_sheet.dart';
import 'package:viax/src/features/company/presentation/screens/company_reports_screen.dart';

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

            SliverToBoxAdapter(
              child: DashboardMenuGrid(
                onDriversTap: widget.onNavigateToDrivers,
                onDocumentsTap: widget.onNavigateToDocumentos,
                onPricingTap: widget.onNavigateToPricing,
                onVehiclesTap: () => _showVehicleManagement(context),
                onReportsTap: () => _navigateToReports(context),
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
