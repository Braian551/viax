import 'package:flutter/material.dart';
import 'package:viax/src/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/shared/dashboard_widgets.dart';
import 'package:viax/src/widgets/shared/shimmer_loading.dart';

/// Pestaña de gestión del sistema para el administrador.
/// No incluye Conductores y Docs ya que eso lo gestiona cada empresa.
class AdminManagementTab extends StatefulWidget {
  final Map<String, dynamic> adminUser;

  const AdminManagementTab({
    super.key,
    required this.adminUser,
  });

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final adminId =
        int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Gestión del sistema',
            subtitle: 'Administra todos los aspectos de la plataforma',
          ),
          const SizedBox(height: 8),

          // — Usuarios —
          _buildSectionLabel('Usuarios'),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Gestión de Usuarios',
            subtitle: 'Ver, editar y administrar todos los usuarios',
            icon: Icons.people_outline_rounded,
            accentColor: AppColors.blue600,
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.adminUsers,
                arguments: {
                  'admin_id': adminId,
                  'admin_user': widget.adminUser,
                },
              );
            },
          ),
          const SizedBox(height: 12),
          ManagementMenuItem(
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

          const SizedBox(height: 28),

          // — Empresas —
          _buildSectionLabel('Empresas'),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Empresas de Transporte',
            subtitle:
                'Registrar y gestionar empresas (conductores gestionados por cada empresa)',
            icon: Icons.business_rounded,
            accentColor: AppColors.primary,
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.adminEmpresas,
                arguments: {
                  'admin_id': adminId,
                  'admin_user': widget.adminUser,
                },
              );
            },
          ),

          const SizedBox(height: 28),

          // — Finanzas —
          _buildSectionLabel('Finanzas'),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Cobros a Empresas',
            subtitle: 'Ver saldos pendientes y registrar pagos de empresas',
            icon: Icons.account_balance_wallet_rounded,
            accentColor: AppColors.success,
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.adminPlatformEarnings,
                arguments: {'admin_id': adminId},
              );
            },
          ),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Comprobantes de Pago',
            subtitle: 'Revisar comprobantes enviados por empresas',
            icon: Icons.receipt_long_rounded,
            accentColor: Colors.teal,
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.adminCompanyPaymentReports,
                arguments: {
                  'admin_id': adminId,
                  'admin_user': widget.adminUser,
                },
              );
            },
          ),

          const SizedBox(height: 28),

          // — Reportes y Auditoría —
          _buildSectionLabel('Reportes y Auditoría'),
          const SizedBox(height: 12),
          ManagementMenuItem(
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
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Reportes de Problemas',
            subtitle: 'Reportes y quejas de usuarios',
            icon: Icons.report_problem_rounded,
            accentColor: AppColors.error,
            onTap: () => _showComingSoon(),
          ),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Actividad del Sistema',
            subtitle: 'Monitoreo en tiempo real de la actividad',
            icon: Icons.monitor_heart_rounded,
            accentColor: AppColors.success,
            onTap: () => _showComingSoon(),
          ),

          const SizedBox(height: 28),

          // — Configuración —
          _buildSectionLabel('Configuración'),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Ajustes Generales',
            subtitle: 'Configuración de la aplicación',
            icon: Icons.settings_rounded,
            accentColor: AppColors.blue600,
            onTap: () => _showComingSoon(),
          ),
          const SizedBox(height: 12),
          ManagementMenuItem(
            title: 'Notificaciones Push',
            subtitle: 'Enviar notificaciones a usuarios',
            icon: Icons.notifications_active_rounded,
            accentColor: AppColors.accent,
            onTap: () {
              if (adminId <= 0) {
                _showComingSoon();
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(
                    userId: adminId,
                    currentUser: widget.adminUser,
                    userType: 'admin',
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
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
}
