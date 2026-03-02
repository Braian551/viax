import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:viax/src/widgets/shared/glass_container.dart';
import 'package:viax/src/widgets/shared/dashboard_widgets.dart';
import 'package:viax/src/widgets/shared/shimmer_loading.dart';
import 'platform_earnings_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  final Map<String, dynamic> adminUser;
  final Function(int)? onNavigateToTab;

  const AdminDashboardTab({
    super.key,
    required this.adminUser,
    this.onNavigateToTab,
  });

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final adminId =
          int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

      final response = await AdminService.getDashboardStats(adminId: adminId);

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _dashboardData = response['data'];
          _isLoading = false;
        });
      } else {
        final errorMsg =
            response['message'] ?? 'No se pudieron cargar las estadísticas';
        _showError(errorMsg);
        setState(() {
          _dashboardData = _getDefaultDashboardData();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error al cargar datos');
      setState(() {
        _dashboardData = _getDefaultDashboardData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultDashboardData() {
    return {
      'usuarios': {
        'total_usuarios': 0,
        'total_clientes': 0,
        'total_conductores': 0,
        'usuarios_activos': 0,
        'registros_hoy': 0,
      },
      'solicitudes': {
        'total_solicitudes': 0,
        'completadas': 0,
        'canceladas': 0,
        'en_proceso': 0,
        'solicitudes_hoy': 0,
      },
      'ingresos': {
        'ingresos_totales': 0,
        'ingresos_hoy': 0,
      },
      'reportes': {
        'reportes_pendientes': 0,
      },
      'actividades_recientes': [],
      'registros_ultimos_7_dias': [],
    };
  }

  void _showError(String message) {
    if (mounted) CustomSnackbar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final adminName =
        widget.adminUser['nombre']?.toString() ?? 'Administrador';

    if (_isLoading) {
      return const DashboardShimmer();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(adminName),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Dashboard en vivo'),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildPlatformEarningsCard(),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Actividad reciente'),
            _buildRecentActivity(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String adminName) {
    final hour = DateTime.now().hour;
    String greeting = 'Buenos días';
    IconData greetingIcon = Icons.wb_sunny_rounded;

    if (hour >= 12 && hour < 18) {
      greeting = 'Buenas tardes';
      greetingIcon = Icons.wb_cloudy_rounded;
    } else if (hour >= 18) {
      greeting = 'Buenas noches';
      greetingIcon = Icons.nightlight_round;
    }

    return AccentGlassContainer(
      accentColor: AppColors.primary,
      padding: const EdgeInsets.all(22),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(greetingIcon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  adminName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final users = _dashboardData?['usuarios'] ?? {};
    final solicitudes = _dashboardData?['solicitudes'] ?? {};
    final ingresos = _dashboardData?['ingresos'] ?? {};
    final reportes = _dashboardData?['reportes'] ?? {};

    final adminId =
        int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 4 : 2;
        final childAspectRatio =
            crossAxisCount == 4 ? 1.1 : (constraints.maxWidth - 54) / 2 / 155;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: childAspectRatio,
          children: [
            StatCard(
              title: 'Usuarios',
              value: (users['total_usuarios'] ?? 0).toString(),
              subtitle: 'Activos: ${users['usuarios_activos'] ?? 0}',
              icon: Icons.people_rounded,
              color: AppColors.blue600,
              onTap: () {
                Navigator.pushNamed(context, RouteNames.adminUsers,
                    arguments: {
                      'admin_id': adminId,
                      'admin_user': widget.adminUser,
                    });
              },
            ),
            StatCard(
              title: 'Solicitudes',
              value: (solicitudes['total_solicitudes'] ?? 0).toString(),
              subtitle: 'Hoy: ${solicitudes['solicitudes_hoy'] ?? 0}',
              icon: Icons.assignment_rounded,
              color: AppColors.accent,
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            StatCard(
              title: 'Ingresos',
              value: '\$${_formatNumber(ingresos['ingresos_totales'])}',
              subtitle: 'Hoy: \$${_formatNumber(ingresos['ingresos_hoy'])}',
              icon: Icons.attach_money_rounded,
              color: AppColors.success,
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            StatCard(
              title: 'Reportes',
              value: (reportes['reportes_pendientes'] ?? 0).toString(),
              subtitle: 'Pendientes',
              icon: Icons.report_problem_rounded,
              color: AppColors.warning,
              onTap: () {
                Navigator.pushNamed(context, RouteNames.adminAuditLogs,
                    arguments: {'admin_id': adminId});
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlatformEarningsCard() {
    final adminId =
        int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;

    return ActionCard(
      title: 'Ganancias Plataforma',
      subtitle: 'Ver cuentas por cobrar de empresas',
      icon: Icons.account_balance_rounded,
      color: AppColors.primary,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlatformEarningsScreen(adminId: adminId),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    final actividades = _dashboardData?['actividades_recientes'] ?? [];

    if (actividades.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none_rounded,
        title: 'Sin actividad reciente',
        subtitle: 'Las acciones del sistema aparecerán aquí',
      );
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 22,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: actividades.length > 5 ? 5 : actividades.length,
        separatorBuilder: (_, __) => Divider(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          height: 1,
          indent: 72,
        ),
        itemBuilder: (context, index) {
          final actividad = actividades[index];
          return _buildActivityItem(actividad);
        },
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> actividad) {
    final tipo = actividad['tipo']?.toString().toUpperCase() ?? '';
    Color iconColor = AppColors.primary;
    IconData iconData = Icons.notifications_active_rounded;

    if (tipo.contains('LOGIN') || tipo.contains('SESSION')) {
      iconColor = AppColors.success;
      iconData = Icons.login_rounded;
    } else if (tipo.contains('REGISTER') || tipo.contains('REGISTRO')) {
      iconColor = AppColors.accent;
      iconData = Icons.person_add_rounded;
    } else if (tipo.contains('ERROR') || tipo.contains('FAIL')) {
      iconColor = AppColors.error;
      iconData = Icons.error_outline_rounded;
    } else if (tipo.contains('UPDATE') || tipo.contains('EDIT')) {
      iconColor = AppColors.warning;
      iconData = Icons.edit_rounded;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(iconData, color: iconColor, size: 22),
      ),
      title: Text(
        actividad['descripcion'] ?? 'Sin descripción',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${actividad['nombre'] ?? ''} ${actividad['apellido'] ?? ''} • ${_formatDate(actividad['fecha_creacion'])}',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ),
      trailing: tipo.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tipo.length > 10 ? tipo.substring(0, 10) : tipo,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Ahora';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
