import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'admin_dashboard_tab.dart';
import 'admin_management_tab.dart';
import 'admin_statistics_wrapper.dart';
import 'admin_profile_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const AdminHomeScreen({
    super.key,
    required this.adminUser,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

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
  }

  @override
  Widget build(BuildContext context) {
    final adminName = widget.adminUser['nombre']?.toString() ?? 'Administrador';
    // final isDark = Theme.of(context).brightness == Brightness.dark; // unused local variable removed
    
    // Debug: verificar admin_user en HomeScreen
    print('AdminHomeScreen: adminUser recibido: ${widget.adminUser}');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(adminName),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: [
            AdminDashboardTab(
              adminUser: widget.adminUser,
              onNavigateToTab: _onNavigateToTab,
            ),
            AdminManagementTab(adminUser: widget.adminUser),
            AdminStatisticsScreen(adminUser: widget.adminUser),
            AdminProfileTab(adminUser: widget.adminUser),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildModernAppBar(String adminName) {
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
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : AppColors.lightSurface.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Panel Admin',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  adminName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_selectedIndex == 0)
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded, 
                color: AppColors.primary, 
                size: 22
              ),
              onPressed: () {
                setState(() {});
              },
              tooltip: 'Actualizar',
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.logout_rounded, 
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), 
              size: 22
            ),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => _buildLogoutDialog(),
              );

              if (shouldLogout == true && mounted) {
                await UserService.clearSession();
                
                if (!mounted) return;
                
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.welcome,
                  (route) => false,
                );
              }
            },
            tooltip: 'Cerrar sesión',
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
            decoration: BoxDecoration(
            color: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.95)
              : AppColors.lightSurface.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider,
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
                  _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildNavItem(1, Icons.settings_rounded, 'Gestión'),
                  _buildNavItem(2, Icons.bar_chart_rounded, 'Estadísticas'),
                  _buildNavItem(3, Icons.person_rounded, 'Perfil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavigateToTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                  ? Theme.of(context).colorScheme.onPrimary 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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

  Widget _buildLogoutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.95)
                : AppColors.lightSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                  ? AppColors.darkDivider
                  : AppColors.lightDivider,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Cerrar sesión?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Estás seguro de que deseas cerrar sesión?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



