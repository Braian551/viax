import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsPeakHours extends StatelessWidget {
  const ReportsPeakHours({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final data = provider.reportsData;
        if (data == null) return const SizedBox.shrink();

        final peakHours = data.peakHours;
        final maxValue = peakHours.reduce(math.max);
        if (maxValue == 0) return const SizedBox.shrink();

        // Find peak hour
        int peakHourIndex = 0;
        for (int i = 0; i < peakHours.length; i++) {
          if (peakHours[i] > peakHours[peakHourIndex]) {
            peakHourIndex = i;
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
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
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Horas Pico',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'Hora con más demanda: ${_formatHour(peakHourIndex)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: AppColors.accent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${peakHours[peakHourIndex]} viajes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Heat map style chart
              _buildHourlyChart(context, peakHours, maxValue, isDark),
              const SizedBox(height: 16),
              // Time labels
              _buildTimeLabels(isDark),
              const SizedBox(height: 16),
              // Legend
              _buildLegend(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHourlyChart(
    BuildContext context,
    List<int> hours,
    int maxValue,
    bool isDark,
  ) {
    return SizedBox(
      height: 80,
      child: Row(
        children: hours.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          final intensity = maxValue > 0 ? value / maxValue : 0.0;

          // Color based on intensity
          Color barColor;
          if (intensity > 0.75) {
            barColor = AppColors.error;
          } else if (intensity > 0.5) {
            barColor = AppColors.warning;
          } else if (intensity > 0.25) {
            barColor = AppColors.accent;
          } else if (intensity > 0) {
            barColor = AppColors.primary.withValues(alpha: 0.5);
          } else {
            barColor = isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1);
          }

          return Expanded(
            child: Tooltip(
              message: '${_formatHour(index)}: $value viajes',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeLabels(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimeLabel('12am', isDark),
        _buildTimeLabel('6am', isDark),
        _buildTimeLabel('12pm', isDark),
        _buildTimeLabel('6pm', isDark),
        _buildTimeLabel('12am', isDark),
      ],
    );
  }

  Widget _buildTimeLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: isDark ? Colors.white38 : AppColors.lightTextHint,
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(
          'Bajo',
          AppColors.primary.withValues(alpha: 0.5),
          isDark,
        ),
        const SizedBox(width: 16),
        _buildLegendItem('Medio', AppColors.accent, isDark),
        const SizedBox(width: 16),
        _buildLegendItem('Alto', AppColors.warning, isDark),
        const SizedBox(width: 16),
        _buildLegendItem('Pico', AppColors.error, isDark),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }
}
