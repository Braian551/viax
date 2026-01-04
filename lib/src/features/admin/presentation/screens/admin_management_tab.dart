import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

class AdminManagementTab extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const AdminManagementTab({
    super.key,
    required this.adminUser,
  });

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final adminId = int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Gestión del sistema',
            style: TextStyle(
              color: Theme.of(context).textTheme.displayMedium?.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Administra todos los aspectos de la plataforma',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          _buildSection(
            title: 'Usuarios',
            items: [
              _ManagementItem(
                title: 'Gestión de Usuarios',
                subtitle: 'Ver, editar y administrar todos los usuarios',
                icon: Icons.people_outline_rounded,
                accentColor: AppColors.blue600,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.adminUsers,
                    arguments: {'admin_id': adminId, 'admin_user': widget.adminUser},
                  );
                },
              ),
              _ManagementItem(
                title: 'Clientes',
                subtitle: 'Ver y gestionar clientes registrados',
                icon: Icons.person_outline_rounded,
                accentColor: AppColors.blue600,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.adminUsers,
                    arguments: {
                      'admin_id': adminId,
                      'admin_user': widget.adminUser,
                      'filter': 'clientes',
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Empresas',
            items: [
              _ManagementItem(
                title: 'Empresas de Transporte',
                subtitle: 'Registrar y gestionar empresas (conductores gestionados por cada empresa)',
                icon: Icons.business_rounded,
                accentColor: AppColors.primary,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.adminEmpresas,
                    arguments: {'admin_id': adminId, 'admin_user': widget.adminUser},
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Reportes y Auditoría',
            items: [
              _ManagementItem(
                title: 'Logs de Auditoría',
                subtitle: 'Historial completo de acciones del sistema',
                icon: Icons.history_rounded,
                accentColor: AppColors.warning,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.adminAuditLogs,
                    arguments: {'admin_id': adminId},
                  );
                },
              ),
              _ManagementItem(
                title: 'Reportes de Problemas',
                subtitle: 'Reportes y quejas de usuarios',
                icon: Icons.report_problem_rounded,
                accentColor: AppColors.error,
                onTap: () {
                  _showComingSoon();
                },
              ),
              _ManagementItem(
                title: 'Actividad del Sistema',
                subtitle: 'Monitoreo en tiempo real de la actividad',
                icon: Icons.monitor_heart_rounded,
                accentColor: AppColors.success,
                onTap: () {
                  _showComingSoon();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Configuración',
            items: [
              _ManagementItem(
                title: 'Ajustes Generales',
                subtitle: 'Configuración de la aplicación',
                icon: Icons.settings_rounded,
                accentColor: AppColors.blue600,
                onTap: () {
                  _showComingSoon();
                },
              ),
              _ManagementItem(
                title: 'Tarifas y Comisiones',
                subtitle: 'Gestionar precios y comisiones',
                icon: Icons.attach_money_rounded,
                accentColor: AppColors.primary,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.adminPricing,
                    arguments: {'admin_user': widget.adminUser},
                  );
                },
              ),
              _ManagementItem(
                title: 'Notificaciones Push',
                subtitle: 'Enviar notificaciones a usuarios',
                icon: Icons.notifications_active_rounded,
                accentColor: AppColors.accent,
                onTap: () {
                  _showComingSoon();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<_ManagementItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.displayMedium?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildManagementCard(item),
        )),
      ],
    );
  }

  Widget _buildManagementCard(_ManagementItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: item.accentColor.withValues(alpha: 0.1),
                highlightColor: item.accentColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.accentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(item.icon, color: item.accentColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Función en desarrollo'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ManagementItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  _ManagementItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });
}



