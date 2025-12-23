import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';

/// Sección agrupada de configuración
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: isDark
                    ? Colors.white54
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard.withValues(alpha: 0.6)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(children.length, (index) {
                final isLast = index == children.length - 1;
                return Column(
                  children: [
                    children[index],
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(left: 74),
                        child: Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
