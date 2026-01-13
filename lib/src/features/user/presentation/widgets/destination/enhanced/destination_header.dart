import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../../../theme/app_colors.dart';

class DestinationHeader extends StatelessWidget {
  final bool isDark;
  final int stopsCount;
  final VoidCallback onBack;
  final VoidCallback onAddStop;

  const DestinationHeader({
    super.key,
    required this.isDark,
    required this.stopsCount,
    required this.onBack,
    required this.onAddStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _BackButton(isDark: isDark, onBack: onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '¿A dónde vamos?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ),
          if (stopsCount < 3) _AddStopButton(onAddStop: onAddStop),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;

  const _BackButton({required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? Colors.white : Colors.grey[800],
          size: 22,
        ),
      ),
    );
  }
}

class _AddStopButton extends StatelessWidget {
  final VoidCallback onAddStop;

  const _AddStopButton({required this.onAddStop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddStop,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 6),
            Text(
              'Parada',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}