import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../global/models/simple_location.dart';
import '../../../../global/services/location_suggestion_service.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/destination/destination_widgets.dart';
import '../widgets/destination/enhanced/confirm_button.dart';
import '../widgets/destination/enhanced/destination_header.dart';
import '../widgets/destination/enhanced/inline_waypoints.dart';
import '../widgets/destination/enhanced/saved_locations_row.dart';
import '../widgets/destination/enhanced/waypoints_list.dart';
import '../widgets/destination/enhanced/waypoints_panel.dart';
import '../widgets/map_location_picker_sheet.dart';
import 'trip_preview_screen.dart';

/// Pantalla de selección de destino - Diseño moderno y minimalista
/// - Origen y destino: sugerencias inline debajo del input
/// - Paradas: bottom sheet con drag
class EnhancedDestinationScreen extends StatefulWidget {
  final String? initialSelection;
  final Position? preloadedPosition; // Posición precargada desde home

  const EnhancedDestinationScreen({
    super.key,
    this.initialSelection,
    this.preloadedPosition,
  });

  @override
  State<EnhancedDestinationScreen> createState() =>
      _EnhancedDestinationScreenState();
}

class _EnhancedDestinationScreenState extends State<EnhancedDestinationScreen>
    with TickerProviderStateMixin {
  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Locations
  SimpleLocation? _selectedOrigin;
  SimpleLocation? _selectedDestination;
  final List<SimpleLocation?> _stops = [];

  // State
  LatLng? _userLocation;
  bool _isGettingLocation = false;
  bool _showMap = false;
  List<LatLng> _routePoints = [];
  bool _hasOriginSelected = false;
  bool _hasDestinationSelected = false;

  // Suggestion service
  late LocationSuggestionService _suggestionService;

  // Animations
  late AnimationController _mainAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _mapRevealController;
  late Animation<double> _mapRevealAnimation;

  @override
  void initState() {
    super.initState();
    _suggestionService = LocationSuggestionService();
    _setupAnimations();
    _initializeLocation();
  }

  void _setupAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _mapRevealController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _mapRevealAnimation = CurvedAnimation(
      parent: _mapRevealController,
      curve: Curves.easeOutCubic,
    );

    _mainAnimationController.forward();
  }

  Future<void> _initializeLocation() async {
    // Si ya tenemos una posición precargada, usarla directamente
    if (widget.preloadedPosition != null) {
      _userLocation = LatLng(
        widget.preloadedPosition!.latitude,
        widget.preloadedPosition!.longitude,
      );
      _suggestionService.setUserContext(location: _userLocation);

      // Obtener dirección en paralelo
      _reverseGeocodeOrigin();

      setState(() => _showMap = true);
      _mapRevealController.forward();
      return;
    }

    // Si no hay posición precargada, obtenerla
    await _getCurrentLocation();
    if (_userLocation != null) {
      setState(() => _showMap = true);
      _mapRevealController.forward();
    }
  }

  /// Obtiene la dirección del origen en segundo plano
  Future<void> _reverseGeocodeOrigin() async {
    if (_userLocation == null) return;

    try {
      final address = await _suggestionService.reverseGeocode(
        _userLocation!.latitude,
        _userLocation!.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedOrigin = SimpleLocation(
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
            address: address ?? 'Mi ubicación',
          );
          _originController.text = _selectedOrigin!.address;
          // Marcar el origen como seleccionado para ocultar sugerencias automáticas
          _hasOriginSelected = true;
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding origin: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Habilita la ubicación');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permiso denegado');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Permiso denegado permanentemente');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _userLocation = LatLng(position.latitude, position.longitude);
      _suggestionService.setUserContext(location: _userLocation);

      final address = await _suggestionService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedOrigin = SimpleLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address ?? 'Mi ubicación',
          );
          _originController.text = _selectedOrigin!.address;
          // Marcar el origen como seleccionado para ocultar sugerencias automáticas
          _hasOriginSelected = true;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      setState(() => _isGettingLocation = false);
    }
  }

  void _onOriginSelected(SimpleLocation location) {
    setState(() {
      _selectedOrigin = location;
      _originController.text = location.address;
      _hasOriginSelected = true;
    });
    _originFocusNode.unfocus();
    _updateRoute();
    _checkAutoNavigate();
  }

  void _onDestinationSelected(SimpleLocation location) {
    setState(() {
      _selectedDestination = location;
      _destinationController.text = location.address;
      _hasDestinationSelected = true;
    });
    _destinationFocusNode.unfocus();
    _updateRoute();
    _checkAutoNavigate();
  }

  void _checkAutoNavigate() {
    // Si origen y destino están listos y NO hay paradas, ir automáticamente
    if (_selectedOrigin != null &&
        _selectedDestination != null &&
        _stops.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _goToTripPreview();
      });
    }
  }

  Future<void> _openMapForOrigin() async {
    _originFocusNode.unfocus();
    final result = await showMapLocationPicker(
      context: context,
      initialLocation: _selectedOrigin,
      userLocation: _userLocation,
      title: 'Origen',
      accentColor: AppColors.primary,
    );
    if (result != null && mounted) {
      _onOriginSelected(result);
    }
  }

  Future<void> _openMapForDestination() async {
    _destinationFocusNode.unfocus();
    final result = await showMapLocationPicker(
      context: context,
      initialLocation: _selectedDestination,
      userLocation: _userLocation,
      title: 'Destino',
      accentColor: AppColors.primaryDark,
    );
    if (result != null && mounted) {
      _onDestinationSelected(result);
    }
  }

  Future<void> _openOriginSheet() async {
    final result = await showLocationSearchSheet(
      context: context,
      title: 'Origen',
      icon: Icons.my_location_rounded,
      accentColor: AppColors.primary,
      currentValue: _selectedOrigin,
      userLocation: _userLocation,
      suggestionService: _suggestionService,
      isOrigin: true,
    );

    if (result != null && mounted) {
      _onOriginSelected(result);
    }
  }

  Future<void> _openDestinationSheet() async {
    final result = await showLocationSearchSheet(
      context: context,
      title: 'Destino',
      icon: Icons.flag_rounded,
      accentColor: AppColors.primaryDark,
      currentValue: _selectedDestination,
      userLocation: _userLocation,
      suggestionService: _suggestionService,
      isOrigin: false,
    );

    if (result != null && mounted) {
      _onDestinationSelected(result);
    }
  }

  void _addStop() {
    if (_stops.length >= 3) {
      HapticFeedback.heavyImpact();
      _showError('Máximo 3 paradas');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _stops.add(null));

    // Abrir sheet para la nueva parada
    Future.delayed(const Duration(milliseconds: 100), () {
      _openStopSheet(_stops.length - 1);
    });
  }

  Future<void> _openStopSheet(int index) async {
    final result = await showStopSearchSheet(
      context: context,
      stopNumber: index + 1,
      currentValue: _stops[index],
      userLocation: _userLocation,
      suggestionService: _suggestionService,
    );

    if (result != null && mounted) {
      setState(() => _stops[index] = result);
      _updateRoute();
    }
  }

  void _removeStop(int index) {
    HapticFeedback.lightImpact();
    setState(() => _stops.removeAt(index));
    _updateRoute();
  }

  /// Reordena todos los waypoints (origen, paradas, destino)
  /// El último siempre es destino, el primero siempre es origen
  void _onReorderAllWaypoints(int oldIndex, int newIndex) {
    HapticFeedback.mediumImpact();

    // Construir lista completa: [origen, ...paradas, destino]
    final allWaypoints = <SimpleLocation?>[
      _selectedOrigin,
      ..._stops,
      _selectedDestination,
    ];

    // Ajustar índice si se mueve hacia abajo
    if (newIndex > oldIndex) newIndex--;

    // Mover el elemento
    final item = allWaypoints.removeAt(oldIndex);
    allWaypoints.insert(newIndex, item);

    // Redistribuir: primero = origen, último = destino, medio = paradas
    setState(() {
      _selectedOrigin = allWaypoints.first;
      _selectedDestination = allWaypoints.last;
      _stops.clear();
      for (int i = 1; i < allWaypoints.length - 1; i++) {
        _stops.add(allWaypoints[i]);
      }

      // Actualizar controllers
      _originController.text = _selectedOrigin?.address ?? '';
      _destinationController.text = _selectedDestination?.address ?? '';
    });

    _updateRoute();
  }

  Future<void> _updateRoute() async {
    // Construir lista de waypoints disponibles
    final waypoints = <LatLng>[];

    if (_selectedOrigin != null) {
      waypoints.add(_selectedOrigin!.toLatLng());
    }

    for (final stop in _stops) {
      if (stop != null) {
        waypoints.add(stop.toLatLng());
      }
    }

    if (_selectedDestination != null) {
      waypoints.add(_selectedDestination!.toLatLng());
    }

    // Necesitamos al menos 2 puntos para una ruta
    if (waypoints.length < 2) {
      // Si hay al menos un punto, centrar el mapa en él
      if (waypoints.isNotEmpty) {
        _mapController.move(waypoints.first, 15);
      }
      setState(() => _routePoints = []);
      return;
    }

    try {
      final routeData = await MapboxService.getRoute(
        waypoints: waypoints,
        profile: 'driving',
      );

      if (routeData != null && mounted) {
        setState(() => _routePoints = routeData.geometry);
        _fitMapToRoute();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _routePoints = waypoints);
        _fitMapToRoute();
      }
    }
  }

  void _fitMapToRoute() {
    if (_routePoints.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (var point in _routePoints) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  void _goToTripPreview() {
    if (_selectedOrigin == null || _selectedDestination == null) return;

    HapticFeedback.mediumImpact();
    final validStops = _stops
        .where((s) => s != null)
        .cast<SimpleLocation>()
        .toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TripPreviewScreen(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
              stops: validStops,
              vehicleType: 'auto',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _mapRevealController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  bool get _isValid => _selectedOrigin != null && _selectedDestination != null;

  Widget _buildWaypointsSection({
    required bool isDark,
    required bool useDragMode,
    required double maxSuggestionsHeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WaypointsPanel(
            isDark: isDark,
            child: useDragMode
                ? _buildDragWaypoints(isDark)
                : _buildInlineWaypoints(isDark),
          ),
          const SizedBox(height: 16),
          if (!useDragMode && widget.initialSelection == null)
            SavedLocationsRow(isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildInlineWaypoints(bool isDark) {
    return InlineWaypoints(
      originController: _originController,
      destinationController: _destinationController,
      originFocusNode: _originFocusNode,
      destinationFocusNode: _destinationFocusNode,
      suggestionService: _suggestionService,
      userLocation: _userLocation,
      isDark: isDark,
      hasOriginSelected: _hasOriginSelected,
      hasDestinationSelected: _hasDestinationSelected,
      onOriginSelected: _onOriginSelected,
      onDestinationSelected: _onDestinationSelected,
      onOriginChanged: () => setState(() => _hasOriginSelected = false),
      onDestinationChanged: () =>
          setState(() => _hasDestinationSelected = false),
      reverseGeocode: (point) =>
          _suggestionService.reverseGeocode(point.latitude, point.longitude),
      openOriginMap: _openMapForOrigin,
      openDestinationMap: _openMapForDestination,
    );
  }

  Widget _buildDragWaypoints(bool isDark) {
    return WaypointsList(
      origin: _selectedOrigin,
      destination: _selectedDestination,
      stops: _stops,
      isDark: isDark,
      isGettingLocation: _isGettingLocation,
      onReorder: _onReorderAllWaypoints,
      onOriginTap: _openOriginSheet,
      onDestinationTap: _openDestinationSheet,
      onStopTap: _openStopSheet,
      onRemoveStop: _removeStop,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final useDragMode = _stops.isNotEmpty;
    final maxSuggestionsHeight = screenHeight * 0.5;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Mapa de fondo (interactivo)
            if (_showMap)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _mapRevealAnimation,
                  child: RouteMap(
                    mapController: _mapController,
                    userLocation: _userLocation,
                    origin: _selectedOrigin,
                    destination: _selectedDestination,
                    stops: _stops,
                    routePoints: _routePoints,
                    isDark: isDark,
                  ),
                ),
              ),

            // Gradiente superior (no bloquea gestos)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isDark ? Colors.black : Colors.white,
                        isDark
                          ? Colors.black.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Contenido superior (no ocupa todo el stack)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DestinationHeader(
                    isDark: isDark,
                    stopsCount: _stops.length,
                    onBack: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    onAddStop: _addStop,
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildWaypointsSection(
                        isDark: isDark,
                        useDragMode: useDragMode,
                        maxSuggestionsHeight: maxSuggestionsHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Botón confirmar (solo si hay paradas)
            if (_isValid && _stops.isNotEmpty)
              Positioned(
                bottom: bottomPadding + 24,
                left: 24,
                right: 24,
                child: ConfirmButton(
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _goToTripPreview();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
