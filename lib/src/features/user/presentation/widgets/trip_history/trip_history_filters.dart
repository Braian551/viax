import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Modelo de filtro
class TripFilter {
  final String id;
  final String label;
  final IconData icon;

  const TripFilter({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Filtros horizontales animados
class TripHistoryFilters extends StatefulWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final bool isDark;

  const TripHistoryFilters({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.isDark = false,
  });

  @override
  State<TripHistoryFilters> createState() => _TripHistoryFiltersState();
}

class _TripHistoryFiltersState extends State<TripHistoryFilters>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final List<TripFilter> _filters = const [
    TripFilter(id: 'all', label: 'Todos', icon: Icons.list_rounded),
    TripFilter(id: 'completada', label: 'Completados', icon: Icons.check_circle_rounded),
    TripFilter(id: 'en_curso', label: 'En curso', icon: Icons.pending_rounded),
    TripFilter(id: 'cancelada', label: 'Cancelados', icon: Icons.cancel_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = widget.selectedFilter == filter.id;
            return _FilterChip(
              filter: filter,
              isSelected: isSelected,
              onTap: () => widget.onFilterChanged(filter.id),
              index: index,
              isDark: widget.isDark,
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final TripFilter filter;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;
  final bool isDark;

  const _FilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
    required this.index,
    this.isDark = false,
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
      duration: Duration(milliseconds: 300 + (widget.index * 50)),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getFilterColor() {
    switch (widget.filter.id) {
      case 'completada':
        return AppColors.success;
      case 'cancelada':
        return AppColors.error;
      case 'en_curso':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getFilterColor();
    final isDark = widget.isDark;
    final bgColor = isDark ? AppColors.darkCard : Colors.white;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? color : bgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isSelected ? color : color.withOpacity(isDark ? 0.4 : 0.3),
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(isDark ? 0.4 : 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.filter.icon,
                size: 16,
                color: widget.isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.filter.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
