import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Toggle switch personalizado para configuraciones
class SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsToggle({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
    );
  }
}
