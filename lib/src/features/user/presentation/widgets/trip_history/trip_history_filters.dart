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

/// Filtros horizontales animados con diseño premium
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
    TripFilter(id: 'all', label: 'Todos', icon: Icons.grid_view_rounded),
    TripFilter(id: 'completada', label: 'Completados', icon: Icons.check_circle_rounded),
    TripFilter(id: 'en_curso', label: 'En curso', icon: Icons.directions_car_rounded),
    TripFilter(id: 'cancelada', label: 'Cancelados', icon: Icons.cancel_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
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
        height: 50, // Slightly taller
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
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

class _FilterChip extends StatelessWidget {
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
    required this.isDark,
  });

  Color _getFilterColor() {
    switch (filter.id) {
      case 'completada':
        return const Color(0xFF4CAF50);
      case 'cancelada':
        return const Color(0xFFF44336);
      case 'en_curso':
        return const Color(0xFFFF9800);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getFilterColor();
    final inactiveBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);
    final inactiveText = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : inactiveBg,
          borderRadius: BorderRadius.circular(30), // Pill shape
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              size: 18,
              color: isSelected ? Colors.white : inactiveText,
            ),
            const SizedBox(width: 8),
            Text(
              filter.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : inactiveText,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
