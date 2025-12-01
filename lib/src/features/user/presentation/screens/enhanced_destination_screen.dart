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
import '../widgets/map_location_picker_sheet.dart';
import 'trip_preview_screen.dart';

/// Pantalla de selección de destino
/// - Origen y destino: sugerencias inline debajo del input
/// - Paradas: bottom sheet con drag
class EnhancedDestinationScreen extends StatefulWidget {
  final String? initialSelection;

  const EnhancedDestinationScreen({
    super.key,
    this.initialSelection,
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
    await _getCurrentLocation();
    if (_userLocation != null) {
      setState(() => _showMap = true);
      _mapRevealController.forward();
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

  void _onReorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);
    });
    _updateRoute();
  }

  Future<void> _updateRoute() async {
    if (_selectedOrigin == null || _selectedDestination == null) {
      setState(() => _routePoints = []);
      return;
    }

    final waypoints = <LatLng>[
      _selectedOrigin!.toLatLng(),
      ..._stops.where((s) => s != null).map((s) => s!.toLatLng()),
      _selectedDestination!.toLatLng(),
    ];

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
      body: Stack(
        children: [
          // Mapa de fondo
          if (_showMap)
            FadeTransition(
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

          // Gradiente superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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

          // Contenido
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 12),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildMainContent(isDark),
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
              child: _buildConfirmButton(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark ? null : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '¿A dónde vamos?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
          ),
          // Botón + parada
          GestureDetector(
            onTap: _stops.length < 3 ? _addStop : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _stops.length < 3
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _stops.length < 3
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: _stops.length < 3 ? AppColors.primary : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Parada',
                    style: TextStyle(
                      color: _stops.length < 3 ? AppColors.primary : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    // Si hay paradas → todos usan bottom sheet con drag
    // Si NO hay paradas → origen y destino usan sugerencias inline
    final bool useDragMode = _stops.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card principal con origen/destino
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900]!.withOpacity(0.95) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ORIGEN
                if (useDragMode)
                  // Modo drag: tile simple que abre bottom sheet
                  _buildLocationTile(
                    label: 'Origen',
                    value: _selectedOrigin,
                    placeholder: '¿Desde dónde?',
                    icon: Icons.my_location_rounded,
                    iconColor: AppColors.primary,
                    isDark: isDark,
                    isLoading: _isGettingLocation,
                    onTap: _openOriginSheet,
                  )
                else
                  // Modo inline: campo con sugerencias debajo
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

                // PARADAS (siempre con drag cuando existen)
                if (_stops.isNotEmpty) ...[
                  _buildDivider(isDark),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stops.length,
                    onReorder: _onReorderStops,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      return Column(
                        key: ValueKey('stop_$index'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StopCard(
                            index: index,
                            stop: _stops[index],
                            isDark: isDark,
                            onTap: () => _openStopSheet(index),
                            onRemove: () => _removeStop(index),
                          ),
                          if (index < _stops.length - 1)
                            _buildDivider(isDark),
                        ],
                      );
                    },
                  ),
                ],

                _buildDivider(isDark),

                // DESTINO
                if (useDragMode)
                  // Modo drag: tile simple que abre bottom sheet
                  _buildLocationTile(
                    label: 'Destino',
                    value: _selectedDestination,
                    placeholder: '¿A dónde vamos?',
                    icon: Icons.flag_rounded,
                    iconColor: AppColors.primaryDark,
                    isDark: isDark,
                    onTap: _openDestinationSheet,
                  )
                else
                  // Modo inline: campo con sugerencias debajo
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
            ),
          ),

          const SizedBox(height: 16),

          // Lugares guardados
          _buildSavedLocationsRow(isDark),

          // Espacio para el botón si hay paradas
          if (_stops.isNotEmpty) const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLocationTile({
    required String label,
    required SimpleLocation? value,
    required String placeholder,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null;
    final info = hasValue 
        ? LocationSuggestionService.parseAddress(value.address) 
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? info!.name : placeholder,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                        color: hasValue
                            ? (isDark ? Colors.white : Colors.grey[900])
                            : (isDark ? Colors.white30 : Colors.grey[400]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasValue && info!.subtitle.isNotEmpty)
                      Text(
                        info.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 20),
      color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.1),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
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
        onTap: _goToTripPreview,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Continuar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
