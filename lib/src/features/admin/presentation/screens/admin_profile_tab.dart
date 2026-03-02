import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/legal/legal_links_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/dialogs/logout_dialog.dart';
import 'package:viax/src/widgets/shared/glass_container.dart';
import 'package:viax/src/widgets/shared/dashboard_widgets.dart';
import 'package:viax/src/widgets/shared/shimmer_loading.dart';

class AdminProfileTab extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const AdminProfileTab({super.key, required this.adminUser});

  @override
  State<AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<AdminProfileTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final adminName =
        widget.adminUser['nombre']?.toString() ?? 'Administrador';
    final adminEmail = widget.adminUser['correo_electronico'] ??
        widget.adminUser['email'] ??
        'admin@viax.com';
    final adminPhone = widget.adminUser['telefono'] ??
        widget.adminUser['phone'] ??
        'No especificado';
    final fotoUrl = widget.adminUser['foto_perfil']?.toString() ?? '';
    final photoUrl = fotoUrl.isNotEmpty
        ? UserService.getR2ImageUrl(fotoUrl)
        : '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(adminName, adminEmail, photoUrl),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Información personal'),
          _buildInfoCard(
            icon: Icons.person_outline_rounded,
            title: 'Nombre completo',
            value: adminName,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.email_outlined,
            title: 'Correo electrónico',
            value: adminEmail.toString(),
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.phone_outlined,
            title: 'Teléfono',
            value: adminPhone.toString(),
            color: AppColors.success,
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Acciones rápidas'),
          _buildQuickActions(),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Configuración'),
          _buildSettingsSection(),
          const SizedBox(height: 28),
          _buildLogoutButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      String name, String email, String photoUrl) {
    return AccentGlassContainer(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Row(
        children: [
          ProfileAvatar(
            photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
            fallbackName: name,
            size: 72,
            backgroundColor: AppColors.primary,
            fallbackIcon: Icons.admin_panel_settings_rounded,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Administrador',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return AccentGlassContainer(
      accentColor: color,
      padding: const EdgeInsets.all(18),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones',
                color: AppColors.warning,
                onTap: () => _showComingSoon(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.security_rounded,
                title: 'Seguridad',
                color: AppColors.accent,
                onTap: () => _showComingSoon(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AccentGlassContainer(
      accentColor: color,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      children: [
        _buildSettingItem(
          icon: Icons.edit_outlined,
          title: 'Editar perfil',
          onTap: () => _showComingSoon(),
        ),
        const SizedBox(height: 10),
        _buildSettingItem(
          icon: Icons.lock_outline_rounded,
          title: 'Cambiar contraseña',
          onTap: () => _showComingSoon(),
        ),
        const SizedBox(height: 10),
        _buildSettingItem(
          icon: Icons.notifications_outlined,
          title: 'Preferencias de notificaciones',
          onTap: () => _showComingSoon(),
        ),
        const SizedBox(height: 10),
        _buildSettingItem(
          icon: Icons.info_outline_rounded,
          title: 'Acerca de',
          onTap: () => _showAboutDialog(),
        ),
        const SizedBox(height: 10),
        _buildSettingItem(
          icon: Icons.description_outlined,
          title: 'Términos y Condiciones',
          onTap: _openAdminTerms,
        ),
        const SizedBox(height: 10),
        _buildSettingItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Política de Privacidad',
          onTap: _openAdminPrivacy,
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AccentGlassContainer(
      accentColor: AppColors.error,
      padding: const EdgeInsets.symmetric(vertical: 18),
      borderRadius: 20,
      onTap: () async {
        final shouldLogout = await LogoutDialog.show(context);

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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
          SizedBox(width: 12),
          Text(
            'Cerrar sesión',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Función en desarrollo',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAdminTerms() async {
    final opened = await LegalLinksService.openTerms(
      role: LegalRole.administrador,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Términos y Condiciones'),
        ),
      );
    }
  }

  Future<void> _openAdminPrivacy() async {
    final opened = await LegalLinksService.openPrivacy(
      role: LegalRole.administrador,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Política de Privacidad'),
        ),
      );
    }
  }

  void _showAboutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.95)
                    : AppColors.lightSurface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkDivider.withValues(alpha: 0.3)
                      : AppColors.lightDivider.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 60,
                      height: 60,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Viax Admin',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versión 1.0.0',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Panel de administración del sistema Viax',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
