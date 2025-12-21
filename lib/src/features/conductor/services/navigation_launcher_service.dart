import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Servicio para abrir aplicaciones de navegación externas.
///
/// Proporciona métodos para iniciar navegación en Google Maps y Waze
/// con las coordenadas del destino especificado.
class NavigationLauncherService {
  /// Abre Google Maps con navegación a las coordenadas especificadas.
  static Future<bool> openGoogleMaps({
    required double destinationLat,
    required double destinationLng,
    double? originLat,
    double? originLng,
  }) async {
    String url;

    if (originLat != null && originLng != null) {
      // Con origen específico
      if (Platform.isAndroid) {
        url = 'google.navigation:q=$destinationLat,$destinationLng&mode=d';
      } else {
        url =
            'comgooglemaps://?saddr=$originLat,$originLng&daddr=$destinationLat,$destinationLng&directionsmode=driving';
      }
    } else {
      // Solo destino (usa ubicación actual como origen)
      if (Platform.isAndroid) {
        url = 'google.navigation:q=$destinationLat,$destinationLng&mode=d';
      } else {
        url =
            'comgooglemaps://?daddr=$destinationLat,$destinationLng&directionsmode=driving';
      }
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // Fallback a versión web de Google Maps
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&travelmode=driving',
    );

    if (await canLaunchUrl(webUrl)) {
      return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  /// Abre Waze con navegación a las coordenadas especificadas.
  static Future<bool> openWaze({
    required double destinationLat,
    required double destinationLng,
  }) async {
    // URL scheme de Waze
    final url = Uri.parse(
      'waze://?ll=$destinationLat,$destinationLng&navigate=yes',
    );

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }

    // Fallback a versión web de Waze
    final webUrl = Uri.parse(
      'https://waze.com/ul?ll=$destinationLat,$destinationLng&navigate=yes',
    );

    if (await canLaunchUrl(webUrl)) {
      return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  /// Muestra un selector de aplicación de navegación (Google Maps o Waze).
  static void showNavigationPicker({
    required BuildContext context,
    required double destinationLat,
    required double destinationLng,
    double? originLat,
    double? originLng,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NavigationPickerSheet(
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        originLat: originLat,
        originLng: originLng,
        isDark: isDark,
      ),
    );
  }
}

/// Widget para seleccionar la aplicación de navegación.
class _NavigationPickerSheet extends StatelessWidget {
  final double destinationLat;
  final double destinationLng;
  final double? originLat;
  final double? originLng;
  final bool isDark;

  const _NavigationPickerSheet({
    required this.destinationLat,
    required this.destinationLng,
    this.originLat,
    this.originLng,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Título
          Text(
            'Abrir navegación con',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey[900],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // Botones de navegación
          Row(
            children: [
              Expanded(
                child: _NavigationAppButton(
                  appName: 'Google Maps',
                  icon: Icons.map_rounded,
                  color: const Color(0xFF4285F4),
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(context);
                    final success =
                        await NavigationLauncherService.openGoogleMaps(
                          destinationLat: destinationLat,
                          destinationLng: destinationLng,
                          originLat: originLat,
                          originLng: originLng,
                        );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir Google Maps'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavigationAppButton(
                  appName: 'Waze',
                  icon: Icons.navigation_rounded,
                  color: const Color(0xFF33CCFF),
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(context);
                    final success = await NavigationLauncherService.openWaze(
                      destinationLat: destinationLat,
                      destinationLng: destinationLng,
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir Waze'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Botón cancelar
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationAppButton extends StatelessWidget {
  final String appName;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _NavigationAppButton({
    required this.appName,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 10),
              Text(
                appName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.grey[900],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
