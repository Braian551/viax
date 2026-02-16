import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;

import '../../../../../global/services/mapbox_service.dart';
import '../../../../../global/widgets/map_retry_wrapper.dart';
import '../../../../../theme/app_colors.dart';

class PickupMap extends StatelessWidget {
  final MapController mapController;
  final LatLng initialCenter;
  final LatLng? clientLocation;
  final double clientHeading;
  final bool isDark;
  final VoidCallback onMapMoveStart;
  final VoidCallback onMapMoveEnd;

  const PickupMap({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.clientLocation,
    required this.clientHeading,
    required this.isDark,
    required this.onMapMoveStart,
    required this.onMapMoveEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MapRetryWrapper(
      isDark: isDark,
      builder: ({required mapKey, required onMapReady, required onTileError}) => FlutterMap(
        key: mapKey,
        mapController: mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 17.0,
          minZoom: 10,
          maxZoom: 19,
          onMapReady: onMapReady,
          onPositionChanged: (position, hasGesture) {
            if (hasGesture) onMapMoveStart();
          },
          onMapEvent: (event) {
            if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
              onMapMoveEnd();
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
            userAgentPackageName: 'com.viax.app',
            errorTileCallback: (tile, error, stackTrace) => onTileError(error, stackTrace),
          ),
          if (clientLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: clientLocation!,
                  width: 70,
                  height: 70,
                  child: _ClientMarker(heading: clientHeading),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ClientMarker extends StatefulWidget {
  final double heading;
  const _ClientMarker({required this.heading});

  @override
  State<_ClientMarker> createState() => _ClientMarkerState();
}

class _ClientMarkerState extends State<_ClientMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: Transform.rotate(
                  angle: widget.heading * (math.pi / 180),
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
                            AppColors.primary.withValues(alpha: 0.5),
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 28 + (_pulseController.value * 6),
                height: 28 + (_pulseController.value * 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15 * (1 - _pulseController.value)),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
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