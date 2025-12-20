import 'package:flutter/material.dart';
import '../../../../../../global/models/simple_location.dart';
import '../../../../../../global/services/location_suggestion_service.dart';
import '../../../../../../theme/app_colors.dart';

class WaypointTile extends StatelessWidget {
  final Key tileKey;
  final int index;
  final String label;
  final SimpleLocation? value;
  final String placeholder;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final bool isLoading;
  final VoidCallback onTap;
  final bool showDivider;

  const WaypointTile({
    super.key,
    required this.tileKey,
    required this.index,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final info = hasValue ? LocationSuggestionService.parseAddress(value!.address) : null;

    return Column(
      key: tileKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withOpacity(0.18),
                          iconColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: iconColor.withOpacity(0.2), width: 0.5),
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: iconColor.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasValue ? info!.name : placeholder,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                            color: hasValue
                                ? (isDark ? Colors.white : Colors.grey[900])
                                : (isDark ? Colors.white30 : Colors.grey[400]),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasValue && info!.subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              info.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white30 : Colors.grey[400],
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) WaypointsDivider(isDark: isDark),
      ],
    );
  }
}

class StopTile extends StatelessWidget {
  final Key tileKey;
  final int index;
  final int stopIndex;
  final SimpleLocation? stop;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool showDivider;

  const StopTile({
    super.key,
    required this.tileKey,
    required this.index,
    required this.stopIndex,
    required this.stop,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = stop != null;
    final info = hasValue ? LocationSuggestionService.parseAddress(stop!.address) : null;

    return Column(
      key: tileKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent.withOpacity(0.18),
                          AppColors.accent.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        '${stopIndex + 1}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARADA ${stopIndex + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent.withOpacity(0.8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasValue ? info!.name : 'Toca para seleccionar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                            color: hasValue
                                ? (isDark ? Colors.white : Colors.grey[900])
                                : (isDark ? Colors.white30 : Colors.grey[400]),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasValue && info!.subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              info.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: Colors.red[400]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) WaypointsDivider(isDark: isDark),
      ],
    );
  }
}

class WaypointsDivider extends StatelessWidget {
  final bool isDark;

  const WaypointsDivider({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}