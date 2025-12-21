import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';
import '../models/trip_request_view.dart';
import 'route_3d_overlay.dart';

class ConductorSearchingMap extends StatefulWidget {
  const ConductorSearchingMap({
    super.key,
    required this.mapController,
    required this.currentLocation,
    required this.request,
    required this.routeToClient,
    required this.isDark,
  });

  final MapController mapController;
  final LatLng? currentLocation;
  final TripRequestView? request;
  final MapboxRoute? routeToClient;
  final bool isDark;

  @override
  State<ConductorSearchingMap> createState() => _ConductorSearchingMapState();
}

class _ConductorSearchingMapState extends State<ConductorSearchingMap>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _routeController;
  late Animation<double> _routeAnimation;
  List<LatLng> _animatedRoutePoints = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didUpdateWidget(covariant ConductorSearchingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = widget.routeToClient != null &&
        widget.routeToClient != oldWidget.routeToClient;

    if (routeChanged) {
      _animatedRoutePoints = [];
      _routeController.reset();
      _fitMapToRoute();
      _routeController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _routeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _routeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _routeController,
        curve: Curves.easeInOutCubic,
      ),
    )..addListener(_onRouteTick);
  }

  void _onRouteTick() {
    final route = widget.routeToClient;
    if (route == null || route.geometry.isEmpty) return;

    final totalPoints = route.geometry.length;
    final animatedCount =
        (totalPoints * _routeAnimation.value).round().clamp(0, totalPoints);

    if (animatedCount > 0) {
      setState(() {
        _animatedRoutePoints = route.geometry.sublist(0, animatedCount);
      });
    }
  }

  void _fitMapToRoute() {
    final route = widget.routeToClient;
    if (route == null || route.geometry.isEmpty) return;

    try {
      final bounds = LatLngBounds.fromPoints(route.geometry);
      widget.mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 350),
        ),
      );
    } catch (_) {
      // Silenciar errores de ajuste; no bloquear la vista de mapa.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
      );
    }

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.currentLocation!,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapboxService.getTileUrl(isDarkMode: widget.isDark),
          userAgentPackageName: 'com.example.ping_go',
        ),
        if (_animatedRoutePoints.length > 1)
          ...Route3DOverlay(
            routePoints: _animatedRoutePoints,
            isDark: widget.isDark,
            strokeWidth: 6.0,
          ).buildLayers(),
        if (_animatedRoutePoints.length > 2)
          Route3DOverlay(
            routePoints: _animatedRoutePoints,
            isDark: widget.isDark,
          ).buildDirectionArrow() ??
              const SizedBox.shrink(),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.currentLocation!,
              width: 100,
              height: 100,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 70 * _pulseAnimation.value,
                        height: 70 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(
                            alpha: 0.2 / _pulseAnimation.value,
                          ),
                        ),
                      ),
                      Container(
                        width: 50 * _pulseAnimation.value,
                        height: 50 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(
                            alpha: 0.3 / _pulseAnimation.value,
                          ),
                        ),
                      ),
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? AppColors.darkCard
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3.5,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.directions_car,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        if (widget.request != null)
          MarkerLayer(
            markers: [
              _buildPointMarker(
                point: widget.request!.origen,
                color: AppColors.primary,
                icon: Icons.person_pin_circle_rounded,
                label: 'Recoger',
              ),
              _buildPointMarker(
                point: widget.request!.destino,
                color: const Color(0xFF4CAF50),
                icon: Icons.flag_rounded,
                label: 'Destino',
              ),
            ],
          ),
      ],
    );
  }

  Marker _buildPointMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 110,
      height: 110,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 70 * _pulseAnimation.value,
                  height: 70 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(
                      alpha: 0.28 / _pulseAnimation.value,
                    ),
                  ),
                );
              },
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 25,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
