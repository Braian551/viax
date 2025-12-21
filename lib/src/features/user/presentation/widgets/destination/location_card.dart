import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/location_suggestion_service.dart';

/// Card para un campo de ubicación (origen/destino)
/// Muestra sugerencias inline debajo cuando está en modo edición
class LocationCard extends StatelessWidget {
  final String label;
  final String placeholder;
  final IconData icon;
  final Color iconColor;
  final SimpleLocation? value;
  final bool isEditing;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const LocationCard({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.iconColor,
    this.value,
    this.isEditing = false,
    this.isLoading = false,
    required this.isDark,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final info = hasValue 
        ? LocationSuggestionService.parseAddress(value!.address) 
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isEditing 
              ? iconColor.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isEditing 
              ? Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // Icono
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? info!.name : placeholder,
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
              // Acción
              if (hasValue && onClear != null)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onClear?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
