import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../theme/app_colors.dart';

/// Widget que renderiza una ruta con efecto 3D estilo Uber/Didi
/// 
/// Incluye:
/// - Múltiples capas para efecto de profundidad
/// - Sombras y bordes para apariencia 3D
/// - Flecha de dirección animada
/// - Soporte para tema claro/oscuro
class Route3DOverlay {
  final List<LatLng> routePoints;
  final bool isDark;
  final bool showDirectionArrow;
  final bool animate;
  final Color? primaryColor;
  final double strokeWidth;

  const Route3DOverlay({
    required this.routePoints,
    required this.isDark,
    this.showDirectionArrow = true,
    this.animate = true,
    this.primaryColor,
    this.strokeWidth = 6.0,
  });

  /// Retorna la lista de capas para agregar al FlutterMap
  List<Widget> buildLayers() {
    if (routePoints.length < 2) return [];

    final color = primaryColor ?? AppColors.primary;

    return [
      // Capa 1: Sombra profunda exterior (efecto 3D base)
      PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: strokeWidth * 3,
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ],
      ),

      // Capa 2: Sombra media (efecto de elevación)
      PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: strokeWidth * 2.3,
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : AppColors.blue900.withValues(alpha: 0.20),
          ),
        ],
      ),

      // Capa 3: Borde exterior de la ruta (contorno 3D)
      PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: strokeWidth * 1.7,
            color: isDark ? AppColors.blue900 : AppColors.blue800,
          ),
        ],
      ),

      // Capa 4: Ruta principal (núcleo)
      PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: strokeWidth,
            color: color,
            borderColor: isDark
                ? AppColors.blue400.withValues(alpha: 0.7)
                : AppColors.blue600,
            borderStrokeWidth: 1.5,
          ),
        ],
      ),

      // Capa 5: Línea interior brillante (efecto de luz)
      PolylineLayer(
        polylines: [
          Polyline(
            points: routePoints,
            strokeWidth: strokeWidth * 0.35,
            color: isDark
                ? AppColors.blue200.withValues(alpha: 0.5)
                : AppColors.blue300.withValues(alpha: 0.4),
          ),
        ],
      ),
    ];
  }

  /// Retorna el marcador de flecha de dirección
  Widget? buildDirectionArrow() {
    if (!showDirectionArrow || routePoints.length < 2) return null;

    return MarkerLayer(
      markers: [
        Marker(
          point: routePoints.first,
          width: 44,
          height: 44,
          child: _DirectionArrowMarker(
            angle: _calculateAngle(routePoints[0], routePoints[1]),
            animate: animate,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  /// Calcular ángulo entre dos puntos para rotación de flecha
  static double _calculateAngle(LatLng p1, LatLng p2) {
    final dLng = p2.longitude - p1.longitude;
    final dLat = p2.latitude - p1.latitude;
    return math.atan2(dLng, dLat);
  }
}

/// Marcador de flecha de dirección animado
class _DirectionArrowMarker extends StatelessWidget {
  final double angle;
  final bool animate;
  final bool isDark;

  const _DirectionArrowMarker({
    required this.angle,
    required this.animate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final child = Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.blue700,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );

    if (!animate) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, _) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
    );
  }
}

/// Widget helper para construir marcadores de ruta
class RouteMarkers {
  /// Marcador de origen (conductor)
  static Widget buildDriverMarker({
    required bool isDark,
    required Animation<double> pulseAnimation,
  }) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulso exterior
            Container(
              width: 70 * pulseAnimation.value,
              height: 70 * pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                  alpha: 0.2 / pulseAnimation.value,
                ),
              ),
            ),
            // Pulso medio
            Container(
              width: 50 * pulseAnimation.value,
              height: 50 * pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                  alpha: 0.3 / pulseAnimation.value,
                ),
              ),
            ),
            // Sombra
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            // Círculo principal
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 3.5,
                ),
              ),
            ),
            // Ícono
            const Icon(
              Icons.directions_car,
              color: AppColors.primary,
              size: 26,
            ),
          ],
        );
      },
    );
  }

  /// Marcador de destino (cliente/pasajero)
  static Widget buildClientMarker({
    required Animation<double> pulseAnimation,
    bool animate = true,
  }) {
    final marker = Stack(
      alignment: Alignment.center,
      children: [
        // Pulso de fondo
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 60 * pulseAnimation.value,
              height: 60 * pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(
                  alpha: 0.3 / pulseAnimation.value,
                ),
              ),
            );
          },
        ),
        // Pin del pasajero
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.blue700,
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            // Sombra en el suelo
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 25,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ],
    );

    if (!animate) return marker;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: marker,
    );
  }
}
