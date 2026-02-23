import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:viax/src/features/location_sharing/services/location_sharing_service.dart';
import 'package:viax/src/global/services/auth/user_service.dart';
import 'package:viax/src/global/services/mapbox_service.dart';
import 'package:viax/src/global/widgets/map_retry_wrapper.dart';
import 'package:viax/src/routes/route_names.dart';
import 'package:viax/src/theme/app_colors.dart';

/// Screen that displays a shared location in real-time.
/// Accessible to any user — no login required.
class SharedLocationViewScreen extends StatefulWidget {
  final String token;

  const SharedLocationViewScreen({super.key, required this.token});

  @override
  State<SharedLocationViewScreen> createState() =>
      _SharedLocationViewScreenState();
}

class _SharedLocationViewScreenState extends State<SharedLocationViewScreen>
    with SingleTickerProviderStateMixin {
  static const double _sheetMinSize = 0.15;
  static const double _sheetInitialSize = 0.28;
  static const double _sheetMaxSize = 0.45;

  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _pollTimer;
  SharedLocationData? _data;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _mapReady = false;
  bool _initialFitDone = false;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeEtaMinutes;
  String _lastRouteKey = '';
  double _sheetExtent = _sheetInitialSize;
  Timer? _fitDebounceTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _sheetController.addListener(_onSheetExtentChanged);
    _fetchLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchLocation();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fitDebounceTimer?.cancel();
    _sheetController.removeListener(_onSheetExtentChanged);
    _sheetController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSheetExtentChanged() {
    if (!_sheetController.isAttached) return;

    final nextExtent = _sheetController.size.clamp(
      _sheetMinSize,
      _sheetMaxSize,
    );
    if ((nextExtent - _sheetExtent).abs() < 0.005) return;

    setState(() {
      _sheetExtent = nextExtent;
    });

    final data = _data;
    if (!_mapReady || data == null || !data.hasLocation) return;
    if (data.destinationLat == null || data.destinationLng == null) return;

    _fitDebounceTimer?.cancel();
    _fitDebounceTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _fitMapToContent();
    });
  }

  double _mapBottomPadding() {
    final height = MediaQuery.maybeOf(context)?.size.height ?? 800;
    final basedOnSheet = (height * _sheetExtent) + 86;
    return basedOnSheet.clamp(220.0, 560.0);
  }

  double _centerButtonBottom() {
    final height = MediaQuery.maybeOf(context)?.size.height ?? 800;
    final basedOnSheet = (height * _sheetExtent) + 24;
    return basedOnSheet.clamp(140.0, 620.0);
  }

  Future<void> _fetchLocation() async {
    try {
      final result = await LocationSharingService.getLocation(widget.token);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No se pudo obtener la ubicación';
        });
        return;
      }

      if (result.expired) {
        _pollTimer?.cancel();
        setState(() {
          _data = result;
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'La sesión de compartir ha finalizado';
        });
        return;
      }

      setState(() {
        _data = result;
        _isLoading = false;
        _hasError = false;
      });

      // Fetch route if we have both origin and destination
      if (result.hasLocation &&
          result.destinationLat != null &&
          result.destinationLng != null) {
        _fetchRoute(
          LatLng(result.latitude!, result.longitude!),
          LatLng(result.destinationLat!, result.destinationLng!),
        );
      }

      // Fit map on first valid location
      if (!_initialFitDone && _mapReady && result.hasLocation) {
        _fitMapToContent();
        _initialFitDone = true;
      }
    } catch (e) {
      debugPrint('[SharedView] Error: $e');
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng destination) async {
    final key =
        '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}-'
        '${destination.latitude.toStringAsFixed(4)},${destination.longitude.toStringAsFixed(4)}';
    if (key == _lastRouteKey) return;
    _lastRouteKey = key;

    try {
      final route = await MapboxService.getRoute(
        waypoints: [origin, destination],
        alternatives: false,
        steps: false,
      );
      if (!mounted || route == null) return;

      setState(() {
        _routePoints = route.geometry;
        _routeDistanceKm = route.distanceKm;
        _routeEtaMinutes = route.durationMinutes.ceil();
      });
    } catch (e) {
      debugPrint('[SharedView] Route fetch error: $e');
    }
  }

  void _fitMapToContent() {
    final data = _data;
    if (data == null || !data.hasLocation) return;

    final points = <LatLng>[LatLng(data.latitude!, data.longitude!)];
    if (data.destinationLat != null && data.destinationLng != null) {
      points.add(LatLng(data.destinationLat!, data.destinationLng!));
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: EdgeInsets.fromLTRB(60, 140, 60, _mapBottomPadding()),
        ),
      );
    }
  }

  String _formatRemaining(int seconds) {
    if (seconds <= 0) return 'Expirado';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m} min';
  }

  Future<void> _exitSharedView() async {
    await LocationSharingService.markTokenDismissed(widget.token);

    if (!mounted) return;
    final session = await UserService.getSavedSession();
    if (!mounted) return;

    final route = session == null ? RouteNames.welcome : RouteNames.home;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: WillPopScope(
        onWillPop: () async {
          await _exitSharedView();
          return false;
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[100],
          body: _isLoading
              ? _buildLoading(isDark)
              : _hasError
              ? _buildError(isDark)
              : Stack(
                  children: [
                    // Map
                    Positioned.fill(child: _buildMap(isDark)),

                    // Top bar
                    Positioned(
                      top: statusBarHeight + 8,
                      left: 12,
                      right: 12,
                      child: _buildTopBar(isDark),
                    ),

                    // Center button
                    Positioned(
                      bottom: _centerButtonBottom(),
                      right: 16,
                      child: _buildCenterButton(isDark),
                    ),

                    // Bottom info panel
                    _buildBottomPanel(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(
            'Cargando ubicación...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey[600],
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _data?.expired == true
                    ? Icons.timer_off_rounded
                    : Icons.location_off_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _data?.expired == true
                  ? 'Sesión finalizada'
                  : 'Enlace no disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            if (_data?.sharerName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Compartido por ${_data!.sharerName}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _fetchLocation();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitSharedView,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ubicación en tiempo real',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
          ),
          if (_data != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatRemaining(_data!.remainingSeconds),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterButton(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _fitMapToContent,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location_rounded,
            color: isDark ? Colors.white : AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final data = _data!;
    final sharerPos = data.hasLocation
        ? LatLng(data.latitude!, data.longitude!)
        : null;

    return MapRetryWrapper(
      isDark: isDark,
      builder: ({required mapKey, required onMapReady, required onTileError}) =>
          FlutterMap(
            key: mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  sharerPos ??
                  const LatLng(6.2442, -75.5812), // Medellín fallback
              initialZoom: 14,
              minZoom: 4,
              maxZoom: 18,
              onMapReady: () {
                _mapReady = true;
                onMapReady();
                if (!_initialFitDone && data.hasLocation) {
                  _fitMapToContent();
                  _initialFitDone = true;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxService.getTileUrl(isDarkMode: isDark),
                userAgentPackageName: 'com.viax.app',
                errorTileCallback: (tile, error, stackTrace) =>
                    onTileError(error, stackTrace),
              ),

              // Route polyline
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: AppColors.primary,
                      borderStrokeWidth: 1.5,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // Sharer location
                  if (sharerPos != null)
                    Marker(
                      point: sharerPos,
                      width: 56,
                      height: 56,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, _) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: _SharerMarker(heading: data.heading),
                        ),
                      ),
                    ),

                  // Destination
                  if (data.destinationLat != null &&
                      data.destinationLng != null)
                    Marker(
                      point: LatLng(data.destinationLat!, data.destinationLng!),
                      width: 50,
                      height: 60,
                      child: const _DestinationMarker(),
                    ),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    final data = _data!;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _sheetInitialSize,
      minChildSize: _sheetMinSize,
      maxChildSize: _sheetMaxSize,
      snap: true,
      snapSizes: const [_sheetMinSize, _sheetInitialSize, _sheetMaxSize],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // User info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child:
                            data.sharerPhoto != null &&
                                data.sharerPhoto!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  UserService.getR2ImageUrl(data.sharerPhoto),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.sharerName ?? 'Usuario Viax',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Compartiendo ubicación',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (data.vehiclePlate != null &&
                          data.vehiclePlate!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            data.vehiclePlate!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Destination info
                if (data.destinationAddress != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.flag_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Destino',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  data.destinationAddress!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Route info (ETA + distance)
                if (_routeDistanceKm != null && _routeEtaMinutes != null) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_routeEtaMinutes min',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 20,
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.navigation_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_routeDistanceKm!.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Speed info
                if (data.speed > 0.5) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(data.speed * 3.6).toStringAsFixed(0)} km/h',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Viax branding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 14,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Viax — Viaja fácil, llega rápido',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white24 : Colors.grey[350],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Map Markers ────────────────────────────────────────────

class _SharerMarker extends StatelessWidget {
  final double heading;
  const _SharerMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * (3.14159 / 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
        ),
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
