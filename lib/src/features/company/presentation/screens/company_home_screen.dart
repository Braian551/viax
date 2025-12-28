import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'company_drivers_screen.dart';
import 'company_pricing_screen.dart';

class CompanyHomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const CompanyHomeScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final companyName = user['nombre']?.toString() ?? 'Empresa';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, companyName),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildWelcomeHeader(context, companyName),
              const SizedBox(height: 32),
              
              Text(
                'Gestión',
                style: TextStyle(
                  fontSize: 20,
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
                  _buildDashboardCard(
                    context, 
                    'Conductores', 
                    Icons.people_alt_rounded, 
                    AppColors.primary,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CompanyDriversScreen(user: user)),
                    ),
                  ),
                  _buildDashboardCard(
                    context, 
                    'Tarifas', 
                    Icons.attach_money_rounded, 
                    const Color(0xFF34C759),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CompanyPricingScreen(user: user)),
                    ),
                  ),
                  _buildDashboardCard(
                    context, 
                    'Vehículos', 
                    Icons.directions_car_filled_rounded, 
                    const Color(0xFF5E5CE6),
                    () {
                      // TODO: Implement vehicle management or link to CompanyDriversScreen filtered
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gestionar vehículos desde Conductores por ahora')),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    context, 
                    'Reportes', 
                    Icons.bar_chart_rounded, 
                    const Color(0xFFFF9F0A),
                    () {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente')),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildStatsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String companyName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                ? AppColors.darkSurface.withValues(alpha: 0.8)
                : AppColors.lightSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.business_rounded, color: AppColors.primary),
        ),
      ),
      title: Text(
        'Panel Empresa',
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: Theme.of(context).colorScheme.onSurface
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error),
          onPressed: () async {
             await UserService.clearSession();
             if (!context.mounted) return;
             Navigator.pushNamedAndRemoveUntil(context, RouteNames.login, (route) => false);
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido,',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        Text(
          name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Gestiona tus flotas y configura precios personalizados para maximizar tus ganancias.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
