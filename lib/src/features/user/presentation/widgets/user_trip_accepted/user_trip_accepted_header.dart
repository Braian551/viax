import 'package:flutter/material.dart';
import '../../../../../theme/app_colors.dart';
import '../glass_widgets.dart';

class UserTripAcceptedHeader extends StatelessWidget {
  final bool isDark;
  final String tripState;
  final String statusText;
  final String direccionOrigen;
  final VoidCallback onClose;

  const UserTripAcceptedHeader({
    super.key,
    required this.isDark,
    required this.tripState,
    required this.statusText,
    required this.direccionOrigen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            // Barra superior con glass effect
            Row(
              children: [
                // Botón cerrar con glass
                GlassPanel(
                  borderRadius: 14,
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Status badge con glass
                Expanded(
                  child: GlassPanel(
                    borderRadius: 25,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tripState == 'conductor_llego'
                              ? Icons.pin_drop_rounded
                              : tripState == 'en_curso'
                                  ? Icons.navigation_rounded
                                  : Icons.check_circle,
                          color: tripState == 'conductor_llego'
                              ? AppColors.accent
                              : AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: tripState == 'conductor_llego'
                                ? AppColors.accent
                                : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Card de instrucción con glass effect
            GlassPanel(
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_walk,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dirígete al punto de encuentro',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          direccionOrigen,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
