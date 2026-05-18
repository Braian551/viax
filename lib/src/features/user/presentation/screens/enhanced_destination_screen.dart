import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../global/models/location_data.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../global/services/google_places_service.dart';
import '../../../../global/services/location_suggestion_service.dart';
import '../../../../global/services/route_preview_cache.dart';
import '../../../../routes/route_names.dart';
import '../../data/models/saved_user_place.dart';
import '../../services/saved_places_service.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/destination/destination_widgets.dart';
import '../widgets/destination/enhanced/confirm_button.dart';
import '../widgets/destination/enhanced/destination_header.dart';
import '../widgets/destination/enhanced/inline_waypoints.dart';
import '../widgets/destination/enhanced/saved_locations_row.dart';
import '../widgets/destination/enhanced/waypoints_list.dart';
import '../widgets/destination/enhanced/waypoints_panel.dart';
import '../widgets/map_location_picker_sheet.dart';
import 'saved_place_name_screen.dart';
import 'trip_preview_screen.dart';

enum _WaypointFocusTarget { origin, destination }
enum _FavoriteShortcutAction { add, manage }

/// Pantalla de selección de destino - Diseño moderno y minimalista
/// - Origen y destino: sugerencias inline debajo del input
/// - Paradas: hoja inferior con arrastre
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
  // Controladores
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  // Ubicaciones
  SimpleLocation? _selectedOrigin;
  SimpleLocation? _selectedDestination;
  final List<SimpleLocation?> _stops = [];

  // Estado
  LatLng? _userLocation;
  bool _isGettingLocation = false;
  bool _hasOriginSelected = false;
  bool _hasDestinationSelected = false;
  bool _isLoadingSavedPlaces = true;
  late _WaypointFocusTarget _preferredFocusTarget;
  SavedPlacesCollection _savedPlaces = const SavedPlacesCollection.empty();

  // Servicio de sugerencias
  late LocationSuggestionService _suggestionService;

  // Animaciones
  late AnimationController _mainAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _suggestionService = LocationSuggestionService();
    _preferredFocusTarget = widget.initialSelection == 'origin'
        ? _WaypointFocusTarget.origin
        : _WaypointFocusTarget.destination;
    _originFocusNode.addListener(_handleOriginFocusChange);
    _destinationFocusNode.addListener(_handleDestinationFocusChange);
    _setupAnimations();
    _initializeLocation();
    _loadSavedPlaces();
    _scheduleInitialFieldSelection();
  }

  Future<void> _loadSavedPlaces({bool forceRefresh = false}) async {
    try {
      final places = await SavedPlacesService.loadForCurrentUser(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _savedPlaces = places;
        _isLoadingSavedPlaces = false;
      });
    } catch (e) {
      debugPrint('Error loading saved places: $e');
      if (!mounted) return;

      setState(() => _isLoadingSavedPlaces = false);
    }
  }

  IconData _iconForSavedPlaceType(SavedPlaceType type) {
    switch (type) {
      case SavedPlaceType.home:
        return Icons.home_rounded;
      case SavedPlaceType.work:
        return Icons.work_rounded;
      case SavedPlaceType.favorite:
        return Icons.star_rounded;
    }
  }

  String _titleForSavedPlaceType(SavedPlaceType type) {
    switch (type) {
      case SavedPlaceType.home:
        return 'Casa';
      case SavedPlaceType.work:
        return 'Trabajo';
      case SavedPlaceType.favorite:
        return 'Favorito';
    }
  }

  Color _accentColorForSavedPlaceType(SavedPlaceType type) {
    switch (type) {
      case SavedPlaceType.home:
        return AppColors.primary;
      case SavedPlaceType.work:
        return AppColors.primaryDark;
      case SavedPlaceType.favorite:
        return AppColors.accent;
    }
  }

  Future<String?> _requestFavoriteName({
    required SimpleLocation location,
    SavedUserPlace? existing,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SavedPlaceNameScreen(
          address: location.address,
          initialName: existing?.name ?? location.displayName,
          title: 'Cual es su nombre?',
        ),
      ),
    );
  }

  Future<SavedUserPlace?> _openSavedPlaceEditor(
    SavedPlaceType type, {
    SavedUserPlace? existing,
  }) async {
    final location = await showLocationSearchSheet(
      context: context,
      title: _titleForSavedPlaceType(type),
      icon: _iconForSavedPlaceType(type),
      accentColor: _accentColorForSavedPlaceType(type),
      currentValue: existing?.location,
      userLocation: _userLocation,
      suggestionService: _suggestionService,
      isOrigin: false,
      otherLocation: _selectedOrigin,
    );

    if (location == null || !mounted) return null;

    String? savedName;
    if (type == SavedPlaceType.favorite) {
      savedName = await _requestFavoriteName(location: location, existing: existing);
      if (savedName == null || savedName.trim().isEmpty) {
        return null;
      }
    }

    try {
      final savedPlace = await SavedPlacesService.savePlace(
        type: type,
        location: location,
        placeId: existing?.id,
        savedName: savedName,
      );
      await _loadSavedPlaces(forceRefresh: true);
      return savedPlace;
    } catch (e) {
      debugPrint('Error saving saved place: $e');
      if (mounted) {
        _showError(
          type == SavedPlaceType.favorite
              ? 'No pudimos guardar el favorito'
              : 'No pudimos guardar la direccion',
        );
      }
      return null;
    }
  }

  Future<void> _applySavedDestination(SavedUserPlace place) async {
    if (_selectedOrigin == null) {
      await _useCurrentLocationForOrigin();
    }

    if (!mounted || _selectedOrigin == null) return;

    _onDestinationSelected(place.selectionLocation);
  }

  Future<SavedUserPlace?> _openFavoriteShortcutSheet() async {
    if (_savedPlaces.favorites.isEmpty) {
      return _openSavedPlaceEditor(SavedPlaceType.favorite);
    }

    final selection = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Favoritos',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context, _FavoriteShortcutAction.add);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _savedPlaces.favorites.length,
                    separatorBuilder: (context, index) => Divider(
                      color: colorScheme.outlineVariant,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final place = _savedPlaces.favorites[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.place_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        title: Text(place.name),
                        subtitle: Text(
                          place.location.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, place),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, _FavoriteShortcutAction.manage);
                  },
                  child: const Text('Administrar mis lugares'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selection is SavedUserPlace) {
      return selection;
    }

    if (selection == _FavoriteShortcutAction.add) {
      return _openSavedPlaceEditor(SavedPlaceType.favorite);
    }

    if (selection == _FavoriteShortcutAction.manage) {
      if (!mounted) return null;
      await Navigator.pushNamed(context, RouteNames.favoritePlaces);
      await _loadSavedPlaces(forceRefresh: true);
    }

    return null;
  }

  Future<void> _handleSavedLocationTap(SavedPlaceType type) async {
    if (_isLoadingSavedPlaces) return;

    if (type == SavedPlaceType.favorite) {
      final selectedFavorite = await _openFavoriteShortcutSheet();
      if (selectedFavorite != null) {
        await _applySavedDestination(selectedFavorite);
      }
      return;
    }

    final existing = _savedPlaces.byType(type);
    if (existing != null) {
      await _applySavedDestination(existing);
      return;
    }

    final created = await _openSavedPlaceEditor(type);
    if (created != null) {
      await _applySavedDestination(created);
    }
  }

  FocusNode _focusNodeForTarget(_WaypointFocusTarget target) {
    return target == _WaypointFocusTarget.origin
        ? _originFocusNode
        : _destinationFocusNode;
  }

  void _handleOriginFocusChange() {
    if (!_originFocusNode.hasFocus) return;
    _preferredFocusTarget = _WaypointFocusTarget.origin;
  }

  void _handleDestinationFocusChange() {
    if (!_destinationFocusNode.hasFocus) return;
    _preferredFocusTarget = _WaypointFocusTarget.destination;
  }

  void _requestPreferredFocus({bool onlyIfNotFocused = true}) {
    if (!mounted) return;

    final preferredFocusNode = _focusNodeForTarget(_preferredFocusTarget);
    if (onlyIfNotFocused && preferredFocusNode.hasFocus) {
      return;
    }

    preferredFocusNode.requestFocus();
  }

  void _schedulePreferredFocusAfterTransition({bool onlyIfNotFocused = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final route = ModalRoute.of(context);
      final animation = route?.animation;

      if (animation == null || animation.status == AnimationStatus.completed) {
        _requestPreferredFocus(onlyIfNotFocused: onlyIfNotFocused);
        return;
      }

      late AnimationStatusListener statusListener;
      statusListener = (status) {
        if (status != AnimationStatus.completed) return;

        animation.removeStatusListener(statusListener);
        _requestPreferredFocus(onlyIfNotFocused: onlyIfNotFocused);
      };

      animation.addStatusListener(statusListener);
    });
  }

  void _handleFieldTap(_WaypointFocusTarget target) {
    _preferredFocusTarget = target;

    final preferredFocusNode = _focusNodeForTarget(target);
    if (!preferredFocusNode.hasFocus) {
      preferredFocusNode.requestFocus();
    }
  }

  void _applyResolvedOrigin(SimpleLocation originLocation) {
    if (!mounted) return;

    setState(() {
      _selectedOrigin = originLocation;
      _originController.text = originLocation.address;
      _hasOriginSelected = true;
    });

    _schedulePreferredFocusAfterTransition();
  }

  void _scheduleInitialFieldSelection() {
    _schedulePreferredFocusAfterTransition(onlyIfNotFocused: false);
  }

  void _focusDestinationAfterOriginSelection() {
    _preferredFocusTarget = _WaypointFocusTarget.destination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _destinationFocusNode.requestFocus();
    });
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
      return;
    }

    // Si no hay posición precargada, obtenerla
    await _getCurrentLocation();
    if (_userLocation != null) {
      // Ubicación lista
    }
  }

  /// Obtiene la dirección del origen en segundo plano
  Future<void> _reverseGeocodeOrigin() async {
    if (_userLocation == null) return;

    try {
      final originLocation = await _buildNormalizedLocation(_userLocation!);
      _applyResolvedOrigin(originLocation);
    } catch (e) {
      debugPrint('Error reverse geocoding origin: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;
    if (!mounted) return;

    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (e) {
        debugPrint('Error checking location service: $e');
      }

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

      // Agregar tiempo máximo de espera al obtener la ubicación
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy
                  .medium, // Reduce precisión para ganar estabilidad
            ),
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Timeout getting location');
            },
          );

      if (!mounted) return;

      _userLocation = LatLng(position.latitude, position.longitude);
      _suggestionService.setUserContext(location: _userLocation);

      final originLocation = await _buildNormalizedLocation(_userLocation!);
      _applyResolvedOrigin(originLocation);
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Permite mostrar un error si la ubicación tarda demasiado
      if (mounted && e is TimeoutException) {
        // _showError('Tiempo de espera agotado al obtener ubicación');
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<SimpleLocation> _buildNormalizedLocation(LatLng point) async {
    LocationData? normalized;
    try {
      normalized = await GooglePlacesService.reverseGeocodeLocationData(
        position: point,
        sourceType: 'gps',
      );
    } catch (e) {
      debugPrint('Error normalizing location: $e');
    }

    String address = normalized?.address?.trim() ?? '';
    if (address.isEmpty) {
      final fallback = await _suggestionService.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      address = (fallback ?? '').trim();
    }

    if (address.isEmpty) {
      address = 'Mi ubicación actual';
    }

    return SimpleLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      address: address,
      municipality: normalized?.municipality,
      department: normalized?.department,
      country: normalized?.country,
      placeId: normalized?.placeId,
      sourceType: normalized?.sourceType ?? 'gps',
      placeType: normalized?.isUrban == true ? 'address' : 'place',
    );
  }

  Future<void> _useCurrentLocationForOrigin() async {
    LatLng? current = _userLocation;

    if (current == null) {
      await _getCurrentLocation();
      current = _userLocation;
    }

    if (current == null) {
      _showError('No pudimos obtener tu ubicación actual');
      return;
    }

    final location = await _buildNormalizedLocation(current);
    if (!mounted) return;
    _onOriginSelected(location);
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
    if (!_hasDestinationSelected) {
      _focusDestinationAfterOriginSelection();
    }
    _checkAutoNavigate();
  }

  void _onDestinationSelected(SimpleLocation location) {
    setState(() {
      _selectedDestination = location;
      _destinationController.text = location.address;
      _hasDestinationSelected = true;
    });
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
      otherLocation: _selectedDestination, // Para validar duplicados
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
      otherLocation: _selectedOrigin, // Para validar duplicados
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

    // Abrir la hoja para la nueva parada
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
    }
  }

  void _removeStop(int index) {
    HapticFeedback.lightImpact();
    setState(() => _stops.removeAt(index));
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
  }

  Future<void> _goToTripPreview() async {
    if (_selectedOrigin == null || _selectedDestination == null) return;

    HapticFeedback.mediumImpact();
    final validStops = _stops
        .where((s) => s != null)
        .cast<SimpleLocation>()
        .toList();

    final waypoints = [
      _selectedOrigin!.toLatLng(),
      ...validStops.map((stop) => stop.toLatLng()),
      _selectedDestination!.toLatLng(),
    ];

    final preloadedRoute = await RoutePreviewCache.instance
        .getOrFetchRoute(waypoints: waypoints)
        .timeout(const Duration(milliseconds: 500), onTimeout: () => null);

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TripPreviewScreen(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
              stops: validStops,
              vehicleType: 'auto',
              preloadedRoute: preloadedRoute,
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
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.removeListener(_handleOriginFocusChange);
    _destinationFocusNode.removeListener(_handleDestinationFocusChange);
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
          if (!useDragMode)
            SavedLocationsRow(
              isDark: isDark,
              savedPlaces: _savedPlaces,
              isLoading: _isLoadingSavedPlaces,
              onTap: _handleSavedLocationTap,
            ),
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
      onUseCurrentLocation: _useCurrentLocationForOrigin,
      onOriginChanged: () => setState(() => _hasOriginSelected = false),
      onDestinationChanged: () =>
          setState(() => _hasDestinationSelected = false),
      onOriginFieldTap: () => _handleFieldTap(_WaypointFocusTarget.origin),
      onDestinationFieldTap: () =>
          _handleFieldTap(_WaypointFocusTarget.destination),
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
      body: Stack(
        children: [
          // Fondo visual sin interacción para no forzar el cierre del teclado.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.darkBackground,
                          AppColors.darkSurface,
                          AppColors.darkSurface,
                        ]
                      : [
                          AppColors.lightBackground,
                          Colors.white,
                          AppColors.lightSurface,
                        ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Contenido superior
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
    );
  }
}
