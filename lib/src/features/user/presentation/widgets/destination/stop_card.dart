import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/location_suggestion_service.dart';
import '../../../../../theme/app_colors.dart';

/// Card para una parada intermedia
/// Incluye drag handle y botón de eliminar
class StopCard extends StatelessWidget {
  final int index;
  final SimpleLocation? stop;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const StopCard({
    super.key,
    required this.index,
    this.stop,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = stop != null;
    final info = hasValue 
        ? LocationSuggestionService.parseAddress(stop!.address) 
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Número
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parada ${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? info!.name : 'Toca para seleccionar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                        color: hasValue
                            ? (isDark ? Colors.white : Colors.grey[900])
                            : (isDark ? Colors.white30 : Colors.grey[400]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasValue && info!.subtitle.isNotEmpty)
                      Text(
                        info.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Eliminar
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onRemove();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.red[400],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
