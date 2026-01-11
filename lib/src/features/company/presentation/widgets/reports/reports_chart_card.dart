import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/features/company/domain/models/company_reports_model.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsChartCard extends StatefulWidget {
  const ReportsChartCard({super.key});

  @override
  State<ReportsChartCard> createState() => _ReportsChartCardState();
}

class _ReportsChartCardState extends State<ReportsChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _showIngresos = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final data = provider.reportsData;
        if (data == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tendencias',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  // Toggle viajes/ingresos
                  _buildToggle(isDark),
                ],
              ),
              const SizedBox(height: 24),
              // Chart
              SizedBox(
                height: 180,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _ChartPainter(
                        chartData: data.chartData,
                        showIngresos: _showIngresos,
                        progress: _animation.value,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              _buildLegend(data.chartData, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            label: 'Viajes',
            isSelected: !_showIngresos,
            onTap: () {
              setState(() => _showIngresos = false);
              _animationController.reset();
              _animationController.forward();
            },
            isDark: isDark,
          ),
          _buildToggleButton(
            label: 'Ingresos',
            isSelected: _showIngresos,
            onTap: () {
              setState(() => _showIngresos = true);
              _animationController.reset();
              _animationController.forward();
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(ChartData chartData, bool isDark) {
    if (chartData.labels.isEmpty) {
      return Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : AppColors.lightTextHint,
          ),
        ),
      );
    }

    final total = _showIngresos
        ? chartData.ingresos.fold<double>(0, (a, b) => a + b)
        : chartData.viajes.fold<int>(0, (a, b) => a + b).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          color: AppColors.primary,
          label: _showIngresos ? 'Total Ingresos' : 'Total Viajes',
          value: _showIngresos
              ? '\$${_formatNumber(total)}'
              : total.toInt().toString(),
          isDark: isDark,
        ),
        const SizedBox(width: 24),
        _buildLegendItem(
          color: AppColors.accent,
          label: 'Promedio',
          value: _showIngresos
              ? '\$${(total / math.max(1, chartData.labels.length)).toStringAsFixed(0)}'
              : (total / math.max(1, chartData.labels.length)).toStringAsFixed(
                  1,
                ),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
    required bool isDark,
  }) {
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
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppColors.lightTextHint,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}

class _ChartPainter extends CustomPainter {
  final ChartData chartData;
  final bool showIngresos;
  final double progress;
  final bool isDark;

  _ChartPainter({
    required this.chartData,
    required this.showIngresos,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.labels.isEmpty) return;

    final data = showIngresos
        ? chartData.ingresos
        : chartData.viajes.map((e) => e.toDouble()).toList();

    if (data.isEmpty) return;

    final maxValue = data.reduce(math.max);
    if (maxValue == 0) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.3),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final gridPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw chart
    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y =
          size.height - (data[i] / maxValue) * size.height * 0.9 * progress;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve
        final prevPoint = points[i - 1];
        final midX = (prevPoint.dx + x) / 2;
        path.cubicTo(midX, prevPoint.dy, midX, y, x, y);
        fillPath.cubicTo(midX, prevPoint.dy, midX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = isDark ? AppColors.darkSurface : Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 5, dotBorderPaint);
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showIngresos != showIngresos ||
        oldDelegate.chartData != chartData;
  }
}
