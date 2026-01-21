import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/dialogs/dialog_helper.dart';

import 'tabs/company_dashboard_tab.dart';
import 'tabs/company_profile_tab.dart';
import 'company_drivers_screen.dart'; // Contains CompanyDriversTab
import 'company_pricing_screen.dart'; // Contains CompanyPricingTab
import 'company_conductores_documentos_screen.dart';
import 'company_commissions_screen.dart';

class CompanyHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyHomeScreen({
    super.key,
    required this.user,
  });

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanyDetails();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavigateToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    // Refresh stats if navigating to dashboard tab
    if (index == 0) {
      context.read<CompanyProvider>().loadDashboardStats();
    }
  }

  void _navigateToDocumentos() {
    final empresaId = widget.user['empresa_id'] ?? widget.user['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyConductoresDocumentosScreen(
          user: widget.user,
          empresaId: empresaId,
        ),
      ),
    ).then((_) {
      // Refresh stats when returning from documentos screen
      if (mounted) {
        context.read<CompanyProvider>().loadDashboardStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, child) {
        final companyData = provider.company;
        final companyName = companyData?['nombre'] ?? 'Empresa';
        final logoUrl = companyData?['logo_url'];

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: _buildModernAppBar(context, companyName, logoUrl, isDark),
          body: SafeArea(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _selectedIndex = index);
              },
              children: [
                CompanyDashboardTab(
                  onNavigateToDrivers: () => _onNavigateToTab(1),
                  onNavigateToPricing: () => _onNavigateToTab(2),
                  onNavigateToDocumentos: () => _navigateToDocumentos(),
                  onNavigateToCommissions: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CompanyCommissionsScreen(user: widget.user),
                      ),
                    ).then((_) {
                       if (mounted) context.read<CompanyProvider>().loadDashboardStats();
                    });
                  },
                ),
                CompanyDriversTab(user: widget.user),
                CompanyPricingTab(user: widget.user),
                CompanyProfileTab(user: widget.user),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(isDark),
        );
      },
    );
  }

  PreferredSizeWidget _buildModernAppBar(BuildContext context, String companyName, String? logoUrl, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildLogo(logoUrl, isDark),
      ),
      title: Text(
        companyName,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogo(String? logoUrl, bool isDark) {
    if (logoUrl != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            logoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholderLogo(isDark),
          ),
        ),
      );
    }
    return _buildPlaceholderLogo(isDark);
  }

  Widget _buildPlaceholderLogo(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.business_rounded,
        color: isDark ? Colors.white : AppColors.primary,
        size: 20,
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, 'Inicio', isDark),
                  _buildNavItem(1, Icons.group_rounded, 'Conductores', isDark),
                  _buildNavItem(2, Icons.attach_money_rounded, 'Tarifas', isDark),
                  _buildNavItem(3, Icons.person_rounded, 'Perfil', isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedIndex == index;
    final color = isSelected 
        ? AppColors.primary 
        : (isDark ? Colors.white54 : Colors.black54);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavigateToTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
