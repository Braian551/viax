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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _BackButton(isDark: isDark, onBack: onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '¿A dónde vamos?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.5,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.grey[800],
              size: 20,
            ),
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 4),
                Text(
                  'Parada',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}