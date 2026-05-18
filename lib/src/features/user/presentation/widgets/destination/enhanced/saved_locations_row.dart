import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/features/user/data/models/saved_user_place.dart';
import 'package:viax/src/theme/app_colors.dart';

class SavedLocationsRow extends StatelessWidget {
  final bool isDark;
  final SavedPlacesCollection savedPlaces;
  final bool isLoading;
  final ValueChanged<SavedPlaceType> onTap;

  const SavedLocationsRow({
    super.key,
    required this.isDark,
    required this.savedPlaces,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gap = MediaQuery.sizeOf(context).width < 360 ? 6.0 : 8.0;

    return Row(
      children: [
        _SavedLocationChip(
          icon: Icons.home_rounded,
          label: 'Casa',
          subtitle: savedPlaces.home?.location.address,
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.home != null,
          color: AppColors.primary,
          onTap: () => onTap(SavedPlaceType.home),
        ),
        SizedBox(width: gap),
        _SavedLocationChip(
          icon: Icons.work_rounded,
          label: 'Trabajo',
          subtitle: savedPlaces.work?.location.address,
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.work != null,
          color: AppColors.primaryDark,
          onTap: () => onTap(SavedPlaceType.work),
        ),
        SizedBox(width: gap),
        _SavedLocationChip(
          icon: Icons.star_rounded,
          label: 'Favoritos',
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.favorites.isNotEmpty,
          badgeCount: savedPlaces.favorites.length,
          color: AppColors.accent,
          onTap: () => onTap(SavedPlaceType.favorite),
        ),
      ],
    );
  }
}

class _SavedLocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final bool isLoading;
  final bool hasValue;
  final Color color;
  final int badgeCount;
  final VoidCallback onTap;

  const _SavedLocationChip({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.isDark,
    required this.isLoading,
    required this.hasValue,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final hasSubtitle = hasValue && (subtitle?.trim().isNotEmpty ?? false);
    final backgroundColor = hasValue
        ? color.withValues(alpha: isDark ? 0.16 : 0.10)
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.28 : 0.56,
          );
    final borderColor = hasValue
        ? color.withValues(alpha: isDark ? 0.42 : 0.24)
        : isDark
        ? colorScheme.outlineVariant.withValues(alpha: 0.28)
        : colorScheme.primary.withValues(alpha: 0.12);

    Widget? trailing;
    if (isLoading) {
      trailing = SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
      );
    } else if (badgeCount > 0) {
      final badgeLabel = badgeCount > 9 ? '9+' : '$badgeCount';
      trailing = SizedBox(
        width: 22,
        height: 22,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.24 : 0.16),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  badgeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (hasValue) {
      trailing = Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.22 : 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, color: color, size: 12),
      );
    }

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor.withValues(
                            alpha: hasValue ? 0.92 : 0.78,
                          ),
                          height: 1,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: textColor.withValues(
                              alpha: isDark ? 0.62 : 0.58,
                            ),
                            height: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
