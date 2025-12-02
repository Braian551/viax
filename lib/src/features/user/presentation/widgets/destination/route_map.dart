import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../global/models/simple_location.dart';
import '../../../../../global/services/mapbox_service.dart';
import '../../../../../theme/app_colors.dart';

/// Mapa con la ruta y marcadores - usa MapboxService como en home
class RouteMap extends StatelessWidget {
  final MapController mapController;
  final LatLng? userLocation;
  final SimpleLocation? origin;
  final SimpleLocation? destination;
  final List<SimpleLocation?> stops;
  final List<LatLng> routePoints;
  final bool isDark;

  const RouteMap({
    super.key,
    required this.mapController,
    this.userLocation,
    this.origin,
    this.destination,
    required this.stops,
    required this.routePoints,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: userLocation ?? const LatLng(6.2442, -75.5812),
        initialZoom: 15,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tiles - usa MapboxService como en home
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
          userAgentPackageName: 'com.viax.app',
        ),
        // Ruta
        if (routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              // Sombra
              Polyline(
                points: routePoints,
                strokeWidth: 10,
                color: AppColors.primary.withOpacity(0.2),
              ),
              // Línea principal
              Polyline(
                points: routePoints,
                strokeWidth: 5,
                color: AppColors.primary,
              ),
            ],
          ),
        // Marcadores
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Ubicación del usuario con halo (como en home)
    if (userLocation != null && origin == null) {
      markers.add(Marker(
        point: userLocation!,
        width: 60,
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            // Punto central
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    // Origen
    if (origin != null) {
      markers.add(Marker(
        point: origin!.toLatLng(),
        width: 40,
        height: 40,
        child: _OriginMarker(),
      ));
    }

    // Paradas
    for (int i = 0; i < stops.length; i++) {
      if (stops[i] != null) {
        markers.add(Marker(
          point: stops[i]!.toLatLng(),
          width: 32,
          height: 32,
          child: _StopMarker(number: i + 1),
        ));
      }
    }

    // Destino
    if (destination != null) {
      markers.add(Marker(
        point: destination!.toLatLng(),
        width: 44,
        height: 44,
        child: _DestinationMarker(),
      ));
    }

    return markers;
  }
}

class _OriginMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  final int number;
  const _StopMarker({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}
