import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsHeader extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;
  final bool isLoading;

  const ReportsHeader({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  static const List<Map<String, String>> _periods = [
    {'value': '7d', 'label': '7 días'},
    {'value': '30d', 'label': '30 días'},
    {'value': '90d', 'label': '3 meses'},
    {'value': '1y', 'label': '1 año'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis de Rendimiento',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visualiza el desempeño de tu flota',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white60
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Period selector
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _periods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final period = _periods[index];
                final isSelected = period['value'] == selectedPeriod;
                return _buildPeriodChip(
                  context,
                  label: period['label']!,
                  value: period['value']!,
                  isSelected: isSelected,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(
    BuildContext context, {
    required String label,
    required String value,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => onPeriodChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white12
                      : Colors.grey.withValues(alpha: 0.2)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
