import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/widgets/snackbars/custom_snackbar.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';
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

class _AdminDashboardTabState extends State<AdminDashboardTab> with AutomaticKeepAliveClientMixin {
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
    setState(() => _isLoading = true);

    try {
      print('AdminDashboardTab: adminUser completo: ${widget.adminUser}');
      
      final adminId = int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;
      
      print('AdminDashboardTab: Cargando datos para adminId: $adminId');
      
      final response = await AdminService.getDashboardStats(adminId: adminId);
      
      print('AdminDashboardTab: Response recibida: $response');

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _dashboardData = response['data'];
          _isLoading = false;
        });
      } else {
        final errorMsg = response['message'] ?? 'No se pudieron cargar las estadísticas';
        _showError(errorMsg);
        setState(() {
          _dashboardData = _getDefaultDashboardData();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('AdminDashboardTab Error: $e');
      _showError('Error al cargar datos: $e');
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
    CustomSnackbar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final adminName = widget.adminUser['nombre']?.toString() ?? 'Administrador';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _buildShimmerLoading();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildWelcomeSection(adminName),
            const SizedBox(height: 30),
            _buildStatsGrid(),
            const SizedBox(height: 30),
            _buildRecentActivity(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildShimmerBox(height: 60, width: 200),
          const SizedBox(height: 24),
          _buildShimmerBox(height: 24, width: 180),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: List.generate(4, (index) => _buildShimmerBox(height: 140)),
          ),
          const SizedBox(height: 30),
          _buildShimmerBox(height: 24, width: 150),
          const SizedBox(height: 16),
          Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildShimmerBox(height: 80, width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSurface : AppColors.lightDivider,
      highlightColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    AppColors.primaryGlow(opacity: 0.3, blur: 12, spread: 0),
                  ],
                ),
                child: Icon(greetingIcon, color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminName,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.displayMedium?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final users = _dashboardData?['usuarios'] ?? {};
    final solicitudes = _dashboardData?['solicitudes'] ?? {};
    final ingresos = _dashboardData?['ingresos'] ?? {};
    final reportes = _dashboardData?['reportes'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard en vivo',
          style: TextStyle(
            color: Theme.of(context).textTheme.displayMedium?.color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildModernStatCard(
              title: 'Usuarios',
              value: (users['total_usuarios'] ?? 0).toString(),
              subtitle: 'Activos: ${users['usuarios_activos'] ?? 0}',
              icon: Icons.people_rounded,
              gradientColors: [AppColors.blue600, AppColors.blue800],
              onTap: () {
                final adminId = int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;
                Navigator.pushNamed(
                  context,
                  RouteNames.adminUsers,
                  arguments: {'admin_id': adminId, 'admin_user': widget.adminUser},
                );
              },
            ),
            _buildModernStatCard(
              title: 'Solicitudes',
              value: (solicitudes['total_solicitudes'] ?? 0).toString(),
              subtitle: 'Hoy: ${solicitudes['solicitudes_hoy'] ?? 0}',
              icon: Icons.assignment_rounded,
              gradientColors: [AppColors.accent, AppColors.accentDark],
              onTap: () {
                widget.onNavigateToTab?.call(2);
              },
            ),
            _buildModernStatCard(
              title: 'Ingresos',
              value: '\$${_formatNumber(ingresos['ingresos_totales'])}',
              subtitle: 'Hoy: \$${_formatNumber(ingresos['ingresos_hoy'])}',
              icon: Icons.attach_money_rounded,
              gradientColors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
              onTap: () {
                widget.onNavigateToTab?.call(2);
              },
            ),
            _buildModernStatCard(
              title: 'Reportes',
              value: (reportes['reportes_pendientes'] ?? 0).toString(),
              subtitle: 'Pendientes',
              icon: Icons.report_problem_rounded,
              gradientColors: [AppColors.warning, AppColors.error],
              onTap: () {
                final adminId = int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;
                Navigator.pushNamed(
                  context,
                  RouteNames.adminAuditLogs,
                  arguments: {'admin_id': adminId},
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Tarjeta de Ganancias de Plataforma (full width)
        _buildPlatformEarningsCard(),
      ],
    );
  }

  Widget _buildPlatformEarningsCard() {
    return GestureDetector(
      onTap: () {
        final adminId = int.tryParse(widget.adminUser['id']?.toString() ?? '0') ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlatformEarningsScreen(adminId: adminId),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ganancias Plataforma',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.displayMedium?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ver cuentas por cobrar de empresas',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: gradientColors[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: gradientColors[0].withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: gradientColors[0].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: gradientColors[0], size: 20),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.displayMedium?.color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actividades = _dashboardData?['actividades_recientes'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad reciente',
          style: TextStyle(
            color: Theme.of(context).textTheme.displayMedium?.color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (actividades.isEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.6)
                    : AppColors.lightSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.primary.withValues(alpha: 0.5),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin actividad reciente',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las acciones del sistema aparecerán aquí',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.6)
                    : AppColors.lightSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                    width: 1.5,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: actividades.length > 5 ? 5 : actividades.length,
                  separatorBuilder: (_, __) => Divider(
                    color: isDark 
                      ? AppColors.darkDivider.withValues(alpha: 0.3)
                      : AppColors.lightDivider.withValues(alpha: 0.3),
                    height: 1,
                    indent: 72,
                  ),
                  itemBuilder: (context, index) {
                    final actividad = actividades[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        actividad['descripcion'] ?? 'Sin descripción',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${actividad['nombre'] ?? ''} ${actividad['apellido'] ?? ''} â€¢ ${_formatDate(actividad['fecha_creacion'])}',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(0);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return 'Hace ${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return 'Hace ${diff.inHours}h';
      } else {
        return 'Hace ${diff.inDays}d';
      }
    } catch (e) {
      return dateStr;
    }
  }
}



