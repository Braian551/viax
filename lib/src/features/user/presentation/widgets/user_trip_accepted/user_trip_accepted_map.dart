import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../global/services/mapbox_service.dart';
import '../../../../../theme/app_colors.dart';
import '../map_markers.dart';

class UserTripAcceptedMap extends StatelessWidget {
  final MapController mapController;
  final bool isDark;
  final LatLng pickupPoint;
  final List<LatLng> animatedRoute;

  final LatLng? conductorLocation;
  final double conductorHeading;
  final String? conductorVehicleType;

  final LatLng? clientLocation;
  final double clientHeading;
  final Animation<double> pulseAnimation;

  final Animation<double> waveAnimation;
  final String pickupLabel;

  const UserTripAcceptedMap({
    super.key,
    required this.mapController,
    required this.isDark,
    required this.pickupPoint,
    required this.animatedRoute,
    required this.conductorLocation,
    required this.conductorHeading,
    required this.conductorVehicleType,
    required this.clientLocation,
    required this.clientHeading,
    required this.pulseAnimation,
    required this.waveAnimation,
    required this.pickupLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: pickupPoint,
        initialZoom: 16.0,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        // Capa de tiles
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),

        // Sombra de la ruta (efecto de profundidad)
        if (animatedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: animatedRoute,
                strokeWidth: 8.0,
                color: Colors.black.withOpacity(0.15),
              ),
            ],
          ),

        // Ruta del conductor al punto de encuentro (animada)
        if (animatedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: animatedRoute,
                strokeWidth: 5.0,
                color: AppColors.primary,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ],
          ),

        // Marcadores
        MarkerLayer(
          markers: [
            // Marcador del conductor (primero, para que quede debajo)
            if (conductorLocation != null)
              Marker(
                point: conductorLocation!,
                width: 56,
                height: 56,
                child: DriverMarker(
                  vehicleType: conductorVehicleType ?? 'auto',
                  heading: conductorHeading,
                  size: 56,
                  showShadow: false,
                ),
              ),

            // Punto de encuentro (aumentado para que la etiqueta no se recorte)
            Marker(
              point: pickupPoint,
              width: 220,
              height: 140,
              child: PickupPointMarker(
                waveAnimation: waveAnimation,
                label: pickupLabel,
                showLabel: true,
              ),
            ),

            // Marcador del cliente con orientación (brújula) - encima de todo
            if (clientLocation != null)
              Marker(
                point: clientLocation!,
                width: 70,
                height: 70,
                child: _ClientMarker(
                  pulseAnimation: pulseAnimation,
                  heading: clientHeading,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ClientMarker extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final double heading;

  const _ClientMarker({
    required this.pulseAnimation,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, _) {
        return SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cono de luz/linterna (hacia donde mira el usuario)
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: heading * (math.pi / 180),
                  alignment: Alignment.bottomCenter,
                  child: ClipPath(
                    clipper: _BeamClipper(),
                    child: Container(
                      width: 50,
                      height: 35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary.withOpacity(0.5),
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Círculo de precisión GPS (halo exterior)
              Container(
                width: 28 + (pulseAnimation.value * 6),
                height: 28 + (pulseAnimation.value * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(
                    0.15 * (1 - pulseAnimation.value),
                  ),
                ),
              ),

              // Punto central azul
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BeamClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}
