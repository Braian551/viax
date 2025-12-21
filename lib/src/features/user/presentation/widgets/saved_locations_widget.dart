import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_colors.dart';

/// Chip de ubicación guardada (Casa, Trabajo, Favoritos)
class SavedLocationChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  const SavedLocationChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<SavedLocationChip> createState() => _SavedLocationChipState();
}

class _SavedLocationChipState extends State<SavedLocationChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected
                    ? widget.color
                    : (isDark ? Colors.white70 : Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? widget.color
                      : (isDark ? Colors.white : Colors.grey[800]),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row de ubicaciones guardadas
class SavedLocationsRow extends StatelessWidget {
  final Function(String) onLocationSelected;

  const SavedLocationsRow({
    super.key,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          SavedLocationChip(
            icon: Icons.home_rounded,
            label: 'Casa',
            color: AppColors.primaryLight,
            onTap: () => onLocationSelected('home'),
          ),
          const SizedBox(width: 12),
          SavedLocationChip(
            icon: Icons.work_rounded,
            label: 'Trabajo',
            color: AppColors.primary,
            onTap: () => onLocationSelected('work'),
          ),
          const SizedBox(width: 12),
          SavedLocationChip(
            icon: Icons.star_rounded,
            label: 'Favoritos',
            color: AppColors.accent,
            onTap: () => onLocationSelected('favorites'),
          ),
        ],
      ),
    );
  }
}
