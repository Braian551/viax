import 'dart:async';
import 'dart:ui';

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
  String? _activeField; // 'origin', 'destination', null

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
    _setupFocusListeners();
    _initializeLocation();
  }

  void _setupAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOutCubic,
    ));

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

  void _setupFocusListeners() {
    _originFocusNode.addListener(() {
      setState(() {
        _activeField = _originFocusNode.hasFocus ? 'origin' : _activeField;
        if (!_originFocusNode.hasFocus && _activeField == 'origin') {
          _activeField = null;
        }
      });
    });

    _destinationFocusNode.addListener(() {
      setState(() {
        _activeField = _destinationFocusNode.hasFocus ? 'destination' : _activeField;
        if (!_destinationFocusNode.hasFocus && _activeField == 'destination') {
          _activeField = null;
        }
      });
    });
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isGettingLocation = false);
    }
  }

  void _onOriginSelected(SimpleLocation location) {
    setState(() {
      _selectedOrigin = location;
      _originController.text = location.address;
      _activeField = null;
    });
    _originFocusNode.unfocus();
    _updateRoute();
    _checkAutoNavigate();
  }

  void _onDestinationSelected(SimpleLocation location) {
    setState(() {
      _selectedDestination = location;
      _destinationController.text = location.address;
      _activeField = null;
    });
    _destinationFocusNode.unfocus();
    _updateRoute();
    _checkAutoNavigate();
  }

  void _checkAutoNavigate() {
    // Si origen y destino están listos y NO hay paradas, ir automáticamente
    if (_selectedOrigin != null && _selectedDestination != null && _stops.isEmpty) {
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
    final validStops = _stops.where((s) => s != null).cast<SimpleLocation>().toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TripPreviewScreen(
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
          stops: validStops,
          vehicleType: 'carro',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          // Quitar foco al tocar fuera
          FocusScope.of(context).unfocus();
        },
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
                      isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.7),
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
                _buildHeader(isDark),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildMainContent(isDark),
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
              child: _buildConfirmButton(isDark),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Botón atrás con efecto glass
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white : Colors.grey[800],
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Título
          Expanded(
            child: Text(
              '¿A dónde vamos?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Botón agregar parada con efecto glass
          if (_stops.length < 3)
            GestureDetector(
              onTap: _addStop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Parada',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    // Si hay paradas → todos usan bottom sheet con drag (reordenable)
    // Si NO hay paradas → origen y destino usan sugerencias inline
    final bool useDragMode = _stops.isNotEmpty;

    // Calcular altura máxima disponible para sugerencias
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSuggestionsHeight = screenHeight * 0.5; // Máximo 50% de la pantalla

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSuggestionsHeight),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card principal con efecto glass
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.black.withOpacity(0.5) 
                          : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: useDragMode 
                        ? _buildDragModeContent(isDark)
                        : _buildInlineModeContent(isDark),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lugares guardados (solo en modo inline)
              if (!useDragMode) _buildSavedLocationsRow(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Modo inline: origen y destino con sugerencias debajo
  Widget _buildInlineModeContent(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ORIGEN
        Padding(
          padding: const EdgeInsets.all(16),
          child: InlineSuggestions(
            controller: _originController,
            focusNode: _originFocusNode,
            suggestionService: _suggestionService,
            userLocation: _userLocation,
            isOrigin: true,
            isDark: isDark,
            accentColor: AppColors.primary,
            placeholder: 'Origen - ¿Desde dónde?',
            onLocationSelected: _onOriginSelected,
            onUseCurrentLocation: () async {
              if (_userLocation != null) {
                final address = await _suggestionService.reverseGeocode(
                  _userLocation!.latitude,
                  _userLocation!.longitude,
                );
                _onOriginSelected(SimpleLocation(
                  latitude: _userLocation!.latitude,
                  longitude: _userLocation!.longitude,
                  address: address ?? 'Mi ubicación',
                ));
              }
            },
            onOpenMap: _openMapForOrigin,
          ),
        ),
        _buildDivider(isDark),
        // DESTINO
        Padding(
          padding: const EdgeInsets.all(16),
          child: InlineSuggestions(
            controller: _destinationController,
            focusNode: _destinationFocusNode,
            suggestionService: _suggestionService,
            userLocation: _userLocation,
            isOrigin: false,
            isDark: isDark,
            accentColor: AppColors.primaryDark,
            placeholder: 'Destino - ¿A dónde?',
            onLocationSelected: _onDestinationSelected,
            onOpenMap: _openMapForDestination,
          ),
        ),
      ],
    );
  }

  /// Modo drag: todos reordenables (origen, paradas, destino)
  Widget _buildDragModeContent(bool isDark) {
    // Total de items: origen (1) + paradas + destino (1)
    final totalItems = 1 + _stops.length + 1;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalItems,
      onReorder: _onReorderAllWaypoints,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          shadowColor: AppColors.primary.withOpacity(0.3),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        // index 0 = origen
        // index 1 hasta _stops.length = paradas
        // index último = destino
        
        if (index == 0) {
          // ORIGEN
          return _buildDraggableWaypointTile(
            key: const ValueKey('origin'),
            index: index,
            label: 'Origen',
            value: _selectedOrigin,
            placeholder: '¿Desde dónde?',
            icon: Icons.my_location_rounded,
            iconColor: AppColors.primary,
            isDark: isDark,
            isLoading: _isGettingLocation,
            onTap: _openOriginSheet,
            showDivider: true,
          );
        } else if (index == totalItems - 1) {
          // DESTINO
          return _buildDraggableWaypointTile(
            key: const ValueKey('destination'),
            index: index,
            label: 'Destino',
            value: _selectedDestination,
            placeholder: '¿A dónde vamos?',
            icon: Icons.flag_rounded,
            iconColor: AppColors.primaryDark,
            isDark: isDark,
            onTap: _openDestinationSheet,
            showDivider: false,
          );
        } else {
          // PARADA
          final stopIndex = index - 1;
          return _buildDraggableStopTile(
            key: ValueKey('stop_$stopIndex'),
            index: index,
            stopIndex: stopIndex,
            stop: _stops[stopIndex],
            isDark: isDark,
            onTap: () => _openStopSheet(stopIndex),
            onRemove: () => _removeStop(stopIndex),
            showDivider: true,
          );
        }
      },
    );
  }

  Widget _buildDraggableWaypointTile({
    required Key key,
    required int index,
    required String label,
    required SimpleLocation? value,
    required String placeholder,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isLoading = false,
    required VoidCallback onTap,
    required bool showDivider,
  }) {
    final hasValue = value != null;
    final info = hasValue 
        ? LocationSuggestionService.parseAddress(value.address) 
        : null;

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                children: [
                  // Drag handle con contenedor glass sutil
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icono con gradiente
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          iconColor.withOpacity(0.18),
                          iconColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: iconColor.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: iconColor.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasValue ? info!.name : placeholder,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                            color: hasValue
                                ? (isDark ? Colors.white : Colors.grey[900])
                                : (isDark ? Colors.white30 : Colors.grey[400]),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasValue && info!.subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              info.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white30 : Colors.grey[400],
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) _buildDivider(isDark),
      ],
    );
  }

  Widget _buildDraggableStopTile({
    required Key key,
    required int index,
    required int stopIndex,
    required SimpleLocation? stop,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool showDivider,
  }) {
    final hasValue = stop != null;
    final info = hasValue 
        ? LocationSuggestionService.parseAddress(stop.address) 
        : null;

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                children: [
                  // Drag handle con contenedor glass sutil
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.05) 
                            : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Número con gradiente
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent.withOpacity(0.18),
                          AppColors.accent.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${stopIndex + 1}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARADA ${stopIndex + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent.withOpacity(0.8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasValue ? info!.name : 'Toca para seleccionar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                            color: hasValue
                                ? (isDark ? Colors.white : Colors.grey[900])
                                : (isDark ? Colors.white30 : Colors.grey[400]),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasValue && info!.subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              info.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Eliminar con estilo mejorado
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) _buildDivider(isDark),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSavedLocationsRow(bool isDark) {
    return Row(
      children: [
        _buildSavedLocationChip(
          icon: Icons.home_rounded,
          label: 'Casa',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildSavedLocationChip(
          icon: Icons.work_rounded,
          label: 'Trabajo',
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _buildSavedLocationChip(
          icon: Icons.star_rounded,
          label: 'Favoritos',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildSavedLocationChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Cargar ubicación guardada
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: isDark ? Colors.white60 : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _goToTripPreview();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continuar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
