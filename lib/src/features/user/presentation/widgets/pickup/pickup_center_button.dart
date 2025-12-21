import 'package:flutter/material.dart';

import '../../../../../theme/app_colors.dart';

class PickupCenterButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final double bottomOffset;

  const PickupCenterButton({
    super.key,
    required this.isDark,
    required this.onTap,
    this.bottomOffset = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: Material(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(Icons.my_location, color: AppColors.primary, size: 24),
          ),
        ),
      ),
    );
  }
}