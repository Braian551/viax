import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'user_block_action_button.dart';
import 'user_report_action_button.dart';

class TripUserProfileSheet {
  const TripUserProfileSheet._();

  static void show(
    BuildContext context, {
    required String title,
    required String name,
    String? subtitle,
    String? phone,
    String? email,
    double? rating,
    bool isDark = false,
    Widget? avatar,
    int? actorId,
    int? otherUserId,
    int? solicitudId,
    String? targetLabel,
  }) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  avatar ?? _DefaultAvatar(name: name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle ?? title,
                          style: TextStyle(color: secondaryColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.phone_rounded,
                label: 'Telefono',
                value: (phone ?? '').trim().isEmpty ? 'No disponible' : phone!.trim(),
                isDark: isDark,
              ),
              _InfoTile(
                icon: Icons.email_rounded,
                label: 'Correo',
                value: (email ?? '').trim().isEmpty ? 'No disponible' : email!.trim(),
                isDark: isDark,
              ),
              if (rating != null)
                _InfoTile(
                  icon: Icons.star_rounded,
                  label: 'Calificacion',
                  value: rating.toStringAsFixed(1),
                  isDark: isDark,
                ),
              if (actorId != null &&
                  otherUserId != null &&
                  otherUserId > 0 &&
                  targetLabel != null &&
                  targetLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    UserBlockActionButton(
                      actorId: actorId,
                      otherUserId: otherUserId,
                      solicitudId: solicitudId,
                      targetLabel: targetLabel,
                    ),
                    UserReportActionButton(
                      reporterUserId: actorId,
                      reportedUserId: otherUserId,
                      solicitudId: solicitudId,
                      targetLabel: targetLabel,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String name;

  const _DefaultAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
