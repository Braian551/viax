import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/theme/app_colors.dart';
import '../providers/company_provider.dart';

class CompanyNotificationsScreen extends StatefulWidget {
  const CompanyNotificationsScreen({super.key});

  @override
  State<CompanyNotificationsScreen> createState() => _CompanyNotificationsScreenState();
}

class _CompanyNotificationsScreenState extends State<CompanyNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Load settings when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, 
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CompanyProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingSettings) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final settings = provider.settings;
          final bool emailEnabled = settings['notificaciones_email'] ?? true;
          final bool pushEnabled = settings['notificaciones_push'] ?? true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Preferencias de Contacto', isDark),
                const SizedBox(height: 16),
                
                // Email Notifications
                _buildSwitchTile(
                  title: 'Correo Electrónico',
                  subtitle: 'Recibe actualizaciones importantes y alertas de servicio por email.',
                  value: emailEnabled,
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  onChanged: (val) {
                    provider.updateSettings({'notificaciones_email': val});
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Push Notifications
                _buildSwitchTile(
                  title: 'Notificaciones Push',
                  subtitle: 'Recibe alertas instantáneas en tu dispositivo sobre tus conductores.',
                  value: pushEnabled,
                  icon: Icons.notifications_active_outlined,
                  isDark: isDark,
                  onChanged: (val) {
                    provider.updateSettings({'notificaciones_push': val});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppColors.primaryLight : AppColors.primary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required bool isDark,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkSurface.withValues(alpha: 0.5) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
        inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[50],
        inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value 
                    ? AppColors.primary 
                    : (isDark ? Colors.grey : Colors.grey[600]),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8, left: 40), // Align with text
          child: Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
