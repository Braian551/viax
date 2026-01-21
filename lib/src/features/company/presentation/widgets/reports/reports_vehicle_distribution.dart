import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsVehicleDistribution extends StatelessWidget {
  const ReportsVehicleDistribution({super.key});

  static const _vehicleIcons = {
    'moto': Icons.two_wheeler_rounded,
    'motocarro': Icons.electric_rickshaw_rounded,
    'taxi': Icons.local_taxi_rounded,
    'carro': Icons.directions_car_rounded,
    'camioneta': Icons.airport_shuttle_rounded,
    'camion_pequeño': Icons.local_shipping_rounded,
    'camion_grande': Icons.fire_truck_rounded,
    'mudanza': Icons.rv_hookup_rounded,
  };

  static const _vehicleColors = [
    AppColors.primary,
    Colors.orange,
    AppColors.success,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final data = provider.reportsData;
        if (data == null || data.vehicleDistribution.isEmpty) {
          return const SizedBox.shrink();
        }

        final totalViajes = data.vehicleDistribution.fold<int>(
          0,
          (sum, v) => sum + v.viajes,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.08),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Distribución por Vehículo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Pie chart
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _PieChartPainter(
                        data: data.vehicleDistribution
                            .map((v) => v.viajes.toDouble())
                            .toList(),
                        colors: List.generate(
                          data.vehicleDistribution.length,
                          (i) => _vehicleColors[i % _vehicleColors.length],
                        ),
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.vehicleDistribution.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final vehicle = entry.value;
                        final percentage = totalViajes > 0
                            ? (vehicle.viajes / totalViajes * 100)
                            : 0.0;
                        final color =
                            _vehicleColors[index % _vehicleColors.length];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vehicle.nombre,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Vehicle cards
              ...data.vehicleDistribution.asMap().entries.map((entry) {
                final index = entry.key;
                final vehicle = entry.value;
                final color = _vehicleColors[index % _vehicleColors.length];
                final icon =
                    _vehicleIcons[vehicle.tipo] ?? Icons.local_shipping_rounded;

                return _buildVehicleCard(
                  context,
                  name: vehicle.nombre,
                  icon: icon,
                  trips: vehicle.viajes,
                  earnings: vehicle.ingresos,
                  color: color,
                  isDark: isDark,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleCard(
    BuildContext context, {
    required String name,
    required IconData icon,
    required int trips,
    required double earnings,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$trips viajes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                '\$${_formatNumber(earnings)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  final bool isDark;

  _PieChartPainter({
    required this.data,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = data.fold<double>(0, (sum, value) => sum + value);

    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        startAngle,
        sweepAngle - 0.02, // Small gap between segments
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Center circle
    final centerPaint = Paint()
      ..color = isDark ? AppColors.darkSurface : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - 28, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.colors != colors;
  }
}
