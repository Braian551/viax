import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viax/src/features/company/presentation/providers/company_provider.dart';
import 'package:viax/src/theme/app_colors.dart';

class ReportsTopDrivers extends StatelessWidget {
  const ReportsTopDrivers({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<CompanyProvider>(
      builder: (context, provider, _) {
        final data = provider.reportsData;
        if (data == null || data.topDrivers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Top Conductores',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'Por viajes',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.lightTextHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Drivers list
              ...data.topDrivers.asMap().entries.map((entry) {
                final index = entry.key;
                final driver = entry.value;
                return _buildDriverItem(
                  context,
                  position: index + 1,
                  name: driver.nombre,
                  photoUrl: driver.fotoPerfil,
                  trips: driver.totalViajes,
                  earnings: driver.ingresos,
                  rating: driver.rating,
                  isDark: isDark,
                  isLast: index == data.topDrivers.length - 1,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverItem(
    BuildContext context, {
    required int position,
    required String name,
    String? photoUrl,
    required int trips,
    required double earnings,
    required double rating,
    required bool isDark,
    required bool isLast,
  }) {
    final medalColors = [
      Colors.amber, // Gold
      Colors.grey.shade400, // Silver
      Colors.brown.shade300, // Bronze
    ];

    final medalColor = position <= 3 ? medalColors[position - 1] : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Position badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      medalColor?.withValues(alpha: 0.2) ??
                      (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.1)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: medalColor != null
                      ? Icon(
                          Icons.workspace_premium_rounded,
                          color: medalColor,
                          size: 16,
                        )
                      : Text(
                          '$position',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: medalColor ?? Colors.transparent,
                    width: medalColor != null ? 2 : 0,
                  ),
                ),
                child: photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderAvatar(),
                        ),
                      )
                    : _buildPlaceholderAvatar(),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$trips viajes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '\$${_formatNumber(earnings)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar() {
    return const Center(
      child: Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
    );
  }

  String _formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
