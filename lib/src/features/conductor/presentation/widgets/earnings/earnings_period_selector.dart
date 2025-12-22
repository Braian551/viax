import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Tipos de período para filtrar ganancias
enum EarningsPeriodType {
  today,
  week,
  month,
}

/// Configuración de un período
class EarningsPeriodConfig {
  final EarningsPeriodType type;
  final String label;
  final String description;

  const EarningsPeriodConfig({
    required this.type,
    required this.label,
    required this.description,
  });

  static const List<EarningsPeriodConfig> periods = [
    EarningsPeriodConfig(
      type: EarningsPeriodType.today,
      label: 'Hoy',
      description: 'Ganancias de hoy',
    ),
    EarningsPeriodConfig(
      type: EarningsPeriodType.week,
      label: 'Semana',
      description: 'Últimos 7 días',
    ),
    EarningsPeriodConfig(
      type: EarningsPeriodType.month,
      label: 'Mes',
      description: 'Últimos 30 días',
    ),
  ];
}

/// Selector de período con animaciones
class EarningsPeriodSelector extends StatelessWidget {
  final EarningsPeriodType selectedPeriod;
  final ValueChanged<EarningsPeriodType> onPeriodChanged;

  const EarningsPeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.8)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: EarningsPeriodConfig.periods.map((period) {
          return _PeriodButton(
            config: period,
            isSelected: selectedPeriod == period.type,
            isDark: isDark,
            onTap: () => onPeriodChanged(period.type),
          );
        }).toList(),
      ),
    );
  }
}

class _PeriodButton extends StatefulWidget {
  final EarningsPeriodConfig config;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.config,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PeriodButton> createState() => _PeriodButtonState();
}

class _PeriodButtonState extends State<_PeriodButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.config.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.white
                    : widget.isDark
                        ? Colors.white70
                        : AppColors.lightTextSecondary,
                fontSize: 14,
                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
