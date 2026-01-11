import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/widgets/dialogs/logout_dialog.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/features/company/presentation/screens/company_data_screen.dart';
import 'package:viax/src/features/company/presentation/screens/company_notifications_screen.dart';
import 'package:viax/src/features/company/presentation/screens/company_security_screen.dart';

class CompanyProfileTab extends StatefulWidget {
  final Map<String, dynamic> user;

  const CompanyProfileTab({super.key, required this.user});

  @override
  State<CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<CompanyProfileTab> {
  bool _isLoggingOut = false;

  Future<void> _performLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await UserService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, RouteNames.welcome, (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;
    final confirmed = await LogoutDialog.show(context);

    if (confirmed == true) await _performLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = widget.user['nombre']?.toString() ?? 'Usuario';
    final userEmail = widget.user['email']?.toString() ?? 'empresa@viax.com';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserCard(userName, userEmail, isDark),
                const SizedBox(height: 24),
                _buildSectionTitle('Configuración', isDark),
                const SizedBox(height: 16),
                _buildOptionTile(
                  icon: Icons.business_rounded,
                  title: 'Datos de Empresa',
                  subtitle: 'NIT, Dirección, Teléfono',
                  isDark: isDark,
                  onTap: () {
                    final provider = context.read<CompanyProvider>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const CompanyDataScreen(),
                        ),
                      ),
                    );
                  },
                ),
                 _buildOptionTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notificaciones',
                  subtitle: 'Alertas de conductores',
                  isDark: isDark,
                   onTap: () {
                    final provider = context.read<CompanyProvider>();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const CompanyNotificationsScreen(),
                        ),
                      ),
                    );
                  },
                ),
                 _buildOptionTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Seguridad',
                  subtitle: 'Contraseña y accesos',
                  isDark: isDark,
                  onTap: () {
                    final provider = context.read<CompanyProvider>();
                    final userId = widget.user['id'];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: CompanySecurityScreen(userId: userId),
                        ),
                      ),
                    );
                  },
                ),
                 _buildOptionTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Soporte',
                  subtitle: 'Contactar ayuda',
                  isDark: isDark,
                  onTap: () {},
                ),
                const SizedBox(height: 32),
                _buildLogoutButton(isDark),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildUserCard(String name, String email, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white30 : Colors.black26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _isLoggingOut ? null : _confirmLogout,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoggingOut
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
            : const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
