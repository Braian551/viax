import 'package:flutter/material.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Fallback visual cuando el mapa no está disponible.
/// 
/// Muestra un mensaje informativo con opción de reintentar.
class MapFallback extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const MapFallback({
    super.key,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [Colors.grey[900]!, Colors.black]
              : [Colors.grey[200]!, Colors.grey[100]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Mapa no disponible',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
