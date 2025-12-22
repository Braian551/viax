import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Tipo de filtro disponible
enum TripFilterType {
  all,
  completed,
  cancelled,
}

/// Configuración de un filtro
class TripFilterConfig {
  final TripFilterType type;
  final String label;
  final String value;
  final IconData icon;

  const TripFilterConfig({
    required this.type,
    required this.label,
    required this.value,
    required this.icon,
  });

  static const List<TripFilterConfig> filters = [
    TripFilterConfig(
      type: TripFilterType.all,
      label: 'Todos',
      value: 'todos',
      icon: Icons.list_rounded,
    ),
    TripFilterConfig(
      type: TripFilterType.completed,
      label: 'Completados',
      value: 'completados',
      icon: Icons.check_circle_rounded,
    ),
    TripFilterConfig(
      type: TripFilterType.cancelled,
      label: 'Cancelados',
      value: 'cancelados',
      icon: Icons.cancel_rounded,
    ),
  ];
}

/// Barra de filtros horizontales con animaciones suaves
class TripFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const TripFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: TripFilterConfig.filters.map((filter) {
            final isSelected = selectedFilter == filter.value;
            return Padding(
              padding: EdgeInsets.only(
                right: filter != TripFilterConfig.filters.last ? 12 : 0,
              ),
              child: _FilterChip(
                config: filter,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => onFilterChanged(filter.value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final TripFilterConfig config;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.config,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
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

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary
                : widget.isDark
                    ? AppColors.darkCard.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.config.icon,
                  key: ValueKey('${widget.config.value}_${widget.isSelected}'),
                  color: widget.isSelected
                      ? Colors.white
                      : widget.isDark
                          ? Colors.white70
                          : AppColors.lightTextSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : widget.isDark
                          ? Colors.white70
                          : AppColors.lightTextSecondary,
                  fontSize: 14,
                  fontWeight:
                      widget.isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child: Text(widget.config.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
