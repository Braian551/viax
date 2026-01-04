import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_stats.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/dashboard_menu_grid.dart';
import 'package:viax/src/features/company/presentation/widgets/dashboard/promo_banner.dart';

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
            const SliverToBoxAdapter(
              child: DashboardHeader(),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            
            const SliverToBoxAdapter(
              child: DashboardStats(),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
            
            SliverToBoxAdapter(
              child: DashboardMenuGrid(
                onDriversTap: widget.onNavigateToDrivers,
                onDocumentsTap: widget.onNavigateToDocumentos,
                onPricingTap: widget.onNavigateToPricing,
                onReportsTap: () {
                  // Todo: Reports Tab
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente: Reportes avanzados')),
                  );
                },
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            
            SliverToBoxAdapter(
              child: PromoBanner(
                onTap: widget.onNavigateToPricing,
              ),
            ),
            
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 100),
            ),
          ],
        );
      },
    );
  }
}
