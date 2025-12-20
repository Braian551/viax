import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

class UserTripAcceptedFocusButton extends StatelessWidget {
  final bool isDark;
  final bool isFocusedOnClient;
  final VoidCallback onTap;

  const UserTripAcceptedFocusButton({
    super.key,
    required this.isDark,
    required this.isFocusedOnClient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.grey[900] : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              isFocusedOnClient ? Icons.zoom_out_map : Icons.my_location,
              key: ValueKey(isFocusedOnClient),
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
