// lib/src/features/admin/presentation/screens/statistics_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:viax/src/global/services/admin/admin_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsScreen extends StatefulWidget {
  final int adminId;

  const StatisticsScreen({
    super.key,
    required this.adminId,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _selectedPeriod = '7d';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStats();
  }

  // Theme colors
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _surfaceColor => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _onSurfaceColor => Theme.of(context).colorScheme.onSurface;
  Color get _onSurfaceVariantColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _outlineColor => Theme.of(context).colorScheme.outline;
  Color get _onPrimaryColor => Theme.of(context).colorScheme.onPrimary;
  
  // Theme-aware accent colors for stat cards
  Color get _statCardColor1 => Theme.of(context).colorScheme.secondary;
  Color get _statCardColor2 => Theme.of(context).colorScheme.tertiary;
  Color get _statCardColor3 => const Color(0xFFf5576c); // Keep this one as it's a specific red for warnings/errors
  Color get _statCardColor4 => _primaryColor;

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    final response = await AdminService.getDashboardStats(adminId: widget.adminId);
    
    if (!mounted) return;
    
    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _stats = response['data'];
        _isLoading = false;
      });
      _animationController.forward(from: 0);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: _isLoading ? _buildShimmerLoading() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _backgroundColor.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _surfaceColor.withValues(alpha: 0.1),
        ),
        child: IconButton(
          icon: Icon(Icons.close, color: _onSurfaceColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: _onPrimaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estadísticas',
                  style: TextStyle(
                    color: _onPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Métricas y análisis',
                  style: TextStyle(
                    color: _onPrimaryColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _surfaceColor.withValues(alpha: 0.1),
          ),
          child: IconButton(
            icon: Icon(Icons.refresh_rounded, color: _primaryColor),
            onPressed: _loadStats,
            tooltip: 'Actualizar',
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShimmerBox(height: 60),
            const SizedBox(height: 20),
            _buildShimmerBox(height: 300),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: List.generate(4, (_) => _buildShimmerBox(height: 100)),
            ),
            const SizedBox(height: 20),
            _buildShimmerBox(height: 200),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height, double? width}) {
    return Shimmer.fromColors(
      baseColor: _surfaceColor.withValues(alpha: 0.3),
      highlightColor: _surfaceColor.withValues(alpha: 0.5),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: _onSurfaceColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RefreshIndicator(
          color: _primaryColor,
          backgroundColor: _surfaceColor,
          onRefresh: _loadStats,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),
                  _buildRegistrosChart(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildDistributionChart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outlineColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              _buildPeriodButton('7 días', '7d'),
              _buildPeriodButton('30 días', '30d'),
              _buildPeriodButton('Todo', 'all'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!mounted) return;
          setState(() => _selectedPeriod = value);
          _loadStats();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? _onPrimaryColor : _onSurfaceVariantColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrosChart() {
    final registros = _stats?['registros_ultimos_7_dias'] ?? [];
    
    if (registros.isEmpty) {
      return _buildEmptyState();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outlineColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registros Recientes',
                          style: TextStyle(
                            color: _onSurfaceColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Últimos 7 días',
                          style: TextStyle(
                            color: _onSurfaceVariantColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: _outlineColor.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= 0 && value.toInt() < registros.length) {
                              final fecha = registros[value.toInt()]['fecha']?.toString() ?? '';
                              final parts = fecha.split('-');
                              if (parts.length >= 2) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${parts[2]}/${parts[1]}',
                                    style: TextStyle(
                                      color: _onSurfaceVariantColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5,
                          reservedSize: 40,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: _onSurfaceVariantColor,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (registros.length - 1).toDouble(),
                    minY: 0,
                    maxY: _getMaxValue(registros) * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _getChartSpots(registros),
                        isCurved: true,
                        color: _primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: _primaryColor,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _primaryColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _getChartSpots(List<dynamic> registros) {
    return List.generate(
      registros.length,
      (index) {
        final cantidad = int.tryParse(registros[index]['cantidad']?.toString() ?? '0') ?? 0;
        return FlSpot(index.toDouble(), cantidad.toDouble());
      },
    );
  }

  double _getMaxValue(List<dynamic> registros) {
    double max = 0;
    for (var registro in registros) {
      final cantidad = int.tryParse(registro['cantidad']?.toString() ?? '0') ?? 0;
      if (cantidad > max) max = cantidad.toDouble();
    }
    return max == 0 ? 10 : max;
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outlineColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _onSurfaceColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: _onSurfaceVariantColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay datos disponibles',
                style: TextStyle(
                  color: _onSurfaceVariantColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Las estadísticas aparecerán aquí',
                style: TextStyle(
                          color: _onSurfaceColor.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final users = _stats?['usuarios'] ?? {};
    final solicitudes = _stats?['solicitudes'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Métricas generales',
          style: TextStyle(
            color: _onSurfaceColor,
            fontSize: 18,
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
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Usuarios',
              users['total_usuarios']?.toString() ?? '0',
              Icons.people_rounded,
              _statCardColor1,
            ),
            _buildStatCard(
              'Clientes',
              users['total_clientes']?.toString() ?? '0',
              Icons.person_rounded,
              _statCardColor2,
            ),
            _buildStatCard(
              'Conductores',
              users['total_conductores']?.toString() ?? '0',
              Icons.local_taxi_rounded,
              _statCardColor3,
            ),
            _buildStatCard(
              'Solicitudes',
              solicitudes['total_solicitudes']?.toString() ?? '0',
              Icons.receipt_long_rounded,
              _statCardColor4,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outlineColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: _onSurfaceColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        color: _onSurfaceVariantColor,
                        fontSize: 11,
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

  Widget _buildDistributionChart() {
    final solicitudes = _stats?['solicitudes'] ?? {};
    final completadas = int.tryParse(solicitudes['completadas']?.toString() ?? '0') ?? 0;
    final canceladas = int.tryParse(solicitudes['canceladas']?.toString() ?? '0') ?? 0;
    final enProceso = int.tryParse(solicitudes['en_proceso']?.toString() ?? '0') ?? 0;
    final total = completadas + canceladas + enProceso;

    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _outlineColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statCardColor1.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.pie_chart_rounded,
                      color: _statCardColor1,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Distribución de Solicitudes',
                          style: TextStyle(
                            color: _onSurfaceColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Estado actual',
                          style: TextStyle(
                            color: _onSurfaceVariantColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              value: completadas.toDouble(),
                              title: '${((completadas / total) * 100).toStringAsFixed(0)}%',
                              color: _statCardColor2, // Green for completed
                              radius: 50,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: canceladas.toDouble(),
                              title: '${((canceladas / total) * 100).toStringAsFixed(0)}%',
                              color: _statCardColor3, // Red for cancelled
                              radius: 50,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: enProceso.toDouble(),
                              title: '${((enProceso / total) * 100).toStringAsFixed(0)}%',
                              color: _primaryColor,
                              radius: 50,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Completadas', completadas, _statCardColor2),
                        const SizedBox(height: 12),
                        _buildLegendItem('Canceladas', canceladas, _statCardColor3),
                        const SizedBox(height: 12),
                        _buildLegendItem('En Proceso', enProceso, _primaryColor),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _onSurfaceVariantColor,
                  fontSize: 11,
                ),
              ),
              Text(
                value.toString(),
                style: TextStyle(
                  color: _onSurfaceColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}




