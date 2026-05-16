import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:viax/src/features/user/data/models/saved_user_place.dart';

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
    return Row(
      children: [
        _SavedLocationChip(
          icon: Icons.home_rounded,
          label: 'Casa',
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.home != null,
          onTap: () => onTap(SavedPlaceType.home),
        ),
        const SizedBox(width: 10),
        _SavedLocationChip(
          icon: Icons.work_rounded,
          label: 'Trabajo',
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.work != null,
          onTap: () => onTap(SavedPlaceType.work),
        ),
        const SizedBox(width: 10),
        _SavedLocationChip(
          icon: Icons.star_rounded,
          label: 'Favoritos',
          isDark: isDark,
          isLoading: isLoading,
          hasValue: savedPlaces.favorites.isNotEmpty,
          badgeCount: savedPlaces.favorites.length,
          onTap: () => onTap(SavedPlaceType.favorite),
        ),
      ],
    );
  }
}

class _SavedLocationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final bool isLoading;
  final bool hasValue;
  final int badgeCount;
  final VoidCallback onTap;

  const _SavedLocationChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.isLoading,
    required this.hasValue,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget trailing;
    if (isLoading) {
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    } else if (badgeCount > 0) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$badgeCount',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else {
      trailing = Icon(
        hasValue ? Icons.check_circle_rounded : Icons.add_rounded,
        size: 16,
        color: hasValue ? colorScheme.primary : colorScheme.onSurfaceVariant,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.78)
                    : colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasValue
                      ? colorScheme.primary.withValues(alpha: 0.24)
                      : colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: hasValue
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasValue
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}