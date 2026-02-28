import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:viax/src/features/conductor/services/conductor_earnings_service.dart';
import 'package:viax/src/theme/app_colors.dart';

class CommissionsTrendChart extends StatelessWidget {
  final bool isDark;
  final List<EarningsDayModel> days;
  final bool showTrips;

  const CommissionsTrendChart({
    super.key,
    required this.isDark,
    required this.days,
    required this.showTrips,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDays = [...days]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final values = sortedDays
        .map((day) => showTrips ? day.viajes.toDouble() : day.comision)
        .toList();

    if (values.isEmpty) {
      return SizedBox(
        height: 190,
        child: Center(
          child: Text(
            'Sin datos para mostrar',
            style: TextStyle(
              color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final maxValue = max<double>(values.reduce(max), showTrips ? 1 : 1000);

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: maxValue * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxValue * 1.2) / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: (maxValue * 1.2) / 4,
                getTitlesWidget: (value, meta) {
                  final label = showTrips
                      ? value.toStringAsFixed(0)
                      : NumberFormat.compactCurrency(
                          locale: 'es_CO',
                          symbol: '\$',
                          decimalDigits: 0,
                        ).format(value);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: values.length > 6 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedDays.length) {
                    return const SizedBox.shrink();
                  }

                  final date = DateTime.tryParse(sortedDays[index].fecha);
                  final label = date != null
                      ? DateFormat('dd/MM').format(date)
                      : sortedDays[index].fecha;

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => isDark
                  ? AppColors.darkCard.withValues(alpha: 0.95)
                  : Colors.white,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final day = sortedDays[index];
                  final valueLabel = showTrips
                      ? '${day.viajes} viajes'
                      : NumberFormat.currency(
                          locale: 'es_CO',
                          symbol: '\$',
                          decimalDigits: 0,
                        ).format(day.comision);

                  return LineTooltipItem(
                    '${day.fecha}\n$valueLabel',
                    TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                values.length,
                (index) => FlSpot(index.toDouble(), values[index]),
              ),
              isCurved: true,
              color: showTrips ? AppColors.info : AppColors.warning,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: values.length <= 12,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.4,
                  color: showTrips ? AppColors.info : AppColors.warning,
                  strokeWidth: 1,
                  strokeColor: isDark ? Colors.white : Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (showTrips ? AppColors.info : AppColors.warning)
                        .withValues(alpha: 0.28),
                    (showTrips ? AppColors.info : AppColors.warning)
                        .withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
