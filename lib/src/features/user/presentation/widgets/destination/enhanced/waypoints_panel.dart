
import 'package:flutter/material.dart';

class WaypointsPanel extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const WaypointsPanel({
    super.key,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.04), // Softer border
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), // Softer shadow
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}