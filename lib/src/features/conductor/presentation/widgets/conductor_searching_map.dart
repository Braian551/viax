import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/services/mapbox_service.dart';
import '../../../../global/widgets/map_retry_wrapper.dart';
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
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _routeController;
  late final Animation<double> _routeAnimation;

  List<LatLng> _animatedRoutePoints = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    if (widget.routeToClient != null && widget.routeToClient!.geometry.isNotEmpty) {
      _fitMapToRoute();
      _routeController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ConductorSearchingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = widget.routeToClient != oldWidget.routeToClient;

    if (routeChanged) {
      _animatedRoutePoints = [];
      _routeController.reset();

      if (widget.routeToClient != null && widget.routeToClient!.geometry.isNotEmpty) {
        _fitMapToRoute();
        _routeController.forward();
      }
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

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
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
    if (route == null || route.geometry.isEmpty || !mounted) return;

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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLocation == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFFF00)),
      );
    }

    return MapRetryWrapper(
      isDark: widget.isDark,
      builder: ({required mapKey, required onMapReady, required onTileError}) => FlutterMap(
        key: mapKey,
        mapController: widget.mapController,
        options: MapOptions(
          initialCenter: widget.currentLocation!,
          initialZoom: 15,
          onMapReady: onMapReady,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: MapboxService.getTileUrl(isDarkMode: widget.isDark),
            userAgentPackageName: 'com.example.ping_go',
            errorTileCallback: (tile, error, stackTrace) => onTileError(error, stackTrace),
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
                            color: widget.isDark ? AppColors.darkCard : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (widget.request != null)
                _buildPointMarker(
                  point: widget.request!.origen,
                  color: AppColors.warning,
                  icon: Icons.location_on_rounded,
                  label: 'Origen',
                ),
              if (widget.request != null)
                _buildPointMarker(
                  point: widget.request!.destino,
                  color: AppColors.error,
                  icon: Icons.flag_rounded,
                  label: 'Destino',
                ),
            ],
          ),
        ],
      ),
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
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60 * _pulseAnimation.value,
                height: 60 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18 / _pulseAnimation.value),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Positioned(
                top: 72,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
