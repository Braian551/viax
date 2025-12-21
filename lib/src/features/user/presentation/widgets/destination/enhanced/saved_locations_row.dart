import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SavedLocationsRow extends StatelessWidget {
  final bool isDark;

  const SavedLocationsRow({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _SavedLocationChip(icon: Icons.home_rounded, label: 'Casa'),
        SizedBox(width: 10),
        _SavedLocationChip(icon: Icons.work_rounded, label: 'Trabajo'),
        SizedBox(width: 10),
        _SavedLocationChip(icon: Icons.star_rounded, label: 'Favoritos'),
      ],
    );
  }
}

class _SavedLocationChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SavedLocationChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Cargar ubicación guardada
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}