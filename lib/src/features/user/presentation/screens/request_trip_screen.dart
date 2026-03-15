import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/config/app_config.dart';
import '../../../../features/maps/data/datasources/map_remote_datasource.dart';
import '../../../../features/maps/data/models/location_model.dart';
import '../../data/local/search_history_service.dart';
import '../../../../global/models/simple_location.dart';
import '../../../../global/services/route_preview_cache.dart';
import '../../../../global/services/mapbox_service.dart';
import '../../../../global/services/google_places_service.dart';
import '../../../../global/services/landmark_resolver_service.dart';
import '../../../../global/services/poi_resolver_service.dart';
import '../../../../global/services/text_search_resolver_service.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../theme/app_colors.dart';
import 'trip_preview_screen.dart';
import 'location_picker_screen.dart';

class RequestTripScreen extends StatefulWidget {
  final String? initialSelection;
  
  const RequestTripScreen({
    super.key,
    this.initialSelection,
  });

  @override
  State<RequestTripScreen> createState() => _RequestTripScreenState();
}

class _RequestTripScreenState extends State<RequestTripScreen> with TickerProviderStateMixin {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  
  // Multiple stops state
  final List<SimpleLocation> _stops = [];
  final List<TextEditingController> _stopControllers = [];
  final List<FocusNode> _stopFocusNodes = [];
  
  Timer? _debounce;
  
  SimpleLocation? _selectedOrigin;
  SimpleLocation? _selectedDestination;

  List<SimpleLocation> _suggestions = [];
  List<SimpleLocation> _recentSearches = [];
  bool _isLoadingSuggestions = false;
  bool _isGettingLocation = false;
  bool _isProgrammaticChange = false;
  int? _currentUserId;
  SearchHistoryService? _searchHistoryService;
  final Map<String, int> _labelResolveTokens = {};

  late final http.Client _httpClient;
  late final MapRemoteDataSource _mapRemoteDataSource;
  
  // Track which field was last focused (for validation when focus is lost)
  String _lastFocusedField = 'origin';
  // Track which field is currently focused (for showing default options)
  String? _currentlyFocusedField;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _httpClient = http.Client();
    _mapRemoteDataSource = MapRemoteDataSourceImpl(
      client: _httpClient,
      baseUrl: AppConfig.baseUrl,
    );
    
    _setupAnimations();
    
    // Auto-fetch current location for origin (non-blocking)
    Future.microtask(() => _setCurrentLocation(targetField: 'origin'));
    Future.microtask(() async {
      await _loadCurrentUserId();
      await _loadRecentSearches();
    });

    _originController.addListener(() => _onTextChanged(targetField: 'origin'));
    _destinationController.addListener(() => _onTextChanged(targetField: 'destination'));
    
    // Track focus changes - handle both gained and lost focus
    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        // Gained focus - trigger field focused logic
        _onFieldFocused('origin');
      } else {
        // Lost focus - delay to allow new field to gain focus first
        Future.microtask(() {
          if (mounted && _currentlyFocusedField == 'origin') {
            setState(() => _currentlyFocusedField = null);
          }
        });
      }
    });
    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        // Gained focus - trigger field focused logic
        _onFieldFocused('destination');
      } else {
        // Lost focus - delay to allow new field to gain focus first
        Future.microtask(() {
          if (mounted && _currentlyFocusedField == 'destination') {
            setState(() => _currentlyFocusedField = null);
          }
        });
      }
    });
  }
  
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    
    for (var controller in _stopControllers) {
      controller.dispose();
    }
    for (var node in _stopFocusNodes) {
      node.dispose();
    }
    
    _debounce?.cancel();
    _httpClient.close();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final user = await UserService.getSavedSession();
      if (!mounted || user == null) return;
      final userId = user['id'] is int
          ? (user['id'] as int)
          : int.tryParse(user['id'].toString());
      if (userId != null && userId > 0) {
        setState(() {
          _currentUserId = userId;
          _searchHistoryService = SearchHistoryService(userId: userId);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentSearches() async {
    if (_searchHistoryService == null) return;
    try {
      var mapped = (await _searchHistoryService!.getRecentSearches())
          .map(
            (item) => SimpleLocation(
              latitude: item.lat,
              longitude: item.lng,
              address: item.address,
              placeName:
                  _formatAddressForDisplay(item.address.split(',').first.trim()),
              subtitle: _formatAddressForDisplay(item.address),
            ),
          )
          .toList();

      // Fallback opcional: hidratar cache local desde API si aún no hay historial.
      if (mapped.isEmpty && _currentUserId != null && _currentUserId! > 0) {
        final recent = await _mapRemoteDataSource.getRecentSearches(
          userId: _currentUserId!,
        );

        for (final loc in recent) {
          final address = loc.direccion ?? '';
          await _searchHistoryService!.saveSearch(
            address,
            loc.latitud,
            loc.longitud,
          );
        }

        mapped = (await _searchHistoryService!.getRecentSearches())
            .map(
              (item) => SimpleLocation(
                latitude: item.lat,
                longitude: item.lng,
                address: item.address,
                placeName: _formatAddressForDisplay(
                  item.address.split(',').first.trim(),
                ),
                subtitle: _formatAddressForDisplay(item.address),
              ),
            )
            .toList();
      }

      if (!mounted) return;

      setState(() {
        _recentSearches = mapped;
        if (_currentlyFocusedField != null && _suggestions.isEmpty) {
          _suggestions = List<SimpleLocation>.from(_recentSearches);
        }
      });
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(SimpleLocation location) async {
    if (_searchHistoryService == null) return;
    try {
      await _searchHistoryService!.saveSearch(
        location.address,
        location.latitude,
        location.longitude,
      );

      await _loadRecentSearches();

      // Mantener compatibilidad: sincronización best-effort al backend.
      if (_currentUserId != null && _currentUserId! > 0) {
      await _mapRemoteDataSource.saveRecentSearch(
        userId: _currentUserId!,
        location: LocationModel(
          latitud: location.latitude,
          longitud: location.longitude,
          direccion: location.address,
        ),
      );
      }
    } catch (_) {}
  }

  List<LatLng>? _currentPreviewWaypoints() {
    if (_selectedOrigin == null || _selectedDestination == null) {
      return null;
    }

    return [
      _selectedOrigin!.toLatLng(),
      ..._stops.map((stop) => stop.toLatLng()),
      _selectedDestination!.toLatLng(),
    ];
  }

  Future<MapboxRoute?> _prefetchPreviewRoute({
    bool awaitCompletion = false,
  }) async {
    final waypoints = _currentPreviewWaypoints();
    if (waypoints == null || waypoints.length < 2) {
      return null;
    }

    if (awaitCompletion) {
      return RoutePreviewCache.instance.getOrFetchRoute(waypoints: waypoints);
    }

    unawaited(RoutePreviewCache.instance.prefetchRoute(waypoints: waypoints));
    final cached = RoutePreviewCache.instance.getCachedRoute(waypoints: waypoints);
    return cached?.route;
  }

  bool get _isValid => _selectedOrigin != null && _selectedDestination != null && 
      (_stops.length == _stopControllers.length); // Basic validation

  void _addStop() {
    if (_stops.length >= 3) return; // Max 3 stops
    
    setState(() {
      _stops.add(SimpleLocation(latitude: 0, longitude: 0, address: '')); // Placeholder
      final controller = TextEditingController();
      final focusNode = FocusNode();
      
      controller.addListener(() => _onTextChanged(targetField: 'stop_${_stops.length - 1}'));
      // Handle both gained and lost focus
      focusNode.addListener(() {
         final index = _stopFocusNodes.indexOf(focusNode);
         if (index != -1) {
           if (focusNode.hasFocus) {
             // Gained focus
             _onFieldFocused('stop_$index');
           } else {
             // Lost focus - delay to allow new field to gain focus first
             final fieldName = 'stop_$index';
             Future.microtask(() {
               if (mounted && _currentlyFocusedField == fieldName) {
                 setState(() => _currentlyFocusedField = null);
               }
             });
           }
         }
      });
      
      _stopControllers.add(controller);
      _stopFocusNodes.add(focusNode);
    });
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
      _stopControllers[index].dispose();
      _stopControllers.removeAt(index);
      _stopFocusNodes[index].dispose();
      _stopFocusNodes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient or map placeholder if needed, for now just color
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [AppColors.darkSurface, AppColors.darkBackground]
                  : [AppColors.lightSurface, AppColors.lightBackground],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildInputs(isDark),
                          const SizedBox(height: 16),
                          _buildActionButtons(isDark),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildSuggestionsList(isDark),
                          ),
                          _buildBottomButton(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.7)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.4)),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded, 
                      color: isDark ? Colors.white : Colors.black87, 
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '¿A dónde vas?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_stops.length < 3)
            IconButton(
              onPressed: _addStop,
              icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? Colors.white : Colors.black87),
              tooltip: 'Agregar parada',
            ),
        ],
      ),
    );
  }

  void _onFieldFocused(String targetField) {
    _lastFocusedField = targetField;
    _currentlyFocusedField = targetField;
    unawaited(_ensureRecentSearchesForFocus());
    
    // Al enfocar, mostrar recientes mientras no haya texto para buscar.
    setState(() {
      _suggestions = List<SimpleLocation>.from(_recentSearches);
    });
    
    // Check if there is text to search
    String query = '';
    if (targetField == 'origin') {
      query = _originController.text.trim();
    } else if (targetField == 'destination') {
      query = _destinationController.text.trim();
    } else if (targetField.startsWith('stop_')) {
      final index = int.parse(targetField.split('_')[1]);
      if (index < _stopControllers.length) {
        query = _stopControllers[index].text.trim();
      }
    }

    // Only search if there is text. If empty, the UI automatically shows default options
    // because _suggestions is empty and we have focus.
    if (query.isNotEmpty) {
      _searchLocation(query, targetField);
    }
  }

  Future<void> _ensureRecentSearchesForFocus() async {
    if (_searchHistoryService == null) {
      await _loadCurrentUserId();
    }

    if (_recentSearches.isEmpty && _searchHistoryService != null) {
      await _loadRecentSearches();
    }

    if (!mounted) return;
    if (_currentlyFocusedField == null) return;

    final activeField = _currentlyFocusedField!;
    String query = '';
    if (activeField == 'origin') {
      query = _originController.text.trim();
    } else if (activeField == 'destination') {
      query = _destinationController.text.trim();
    } else if (activeField.startsWith('stop_')) {
      final index = int.tryParse(activeField.split('_')[1]);
      if (index != null && index >= 0 && index < _stopControllers.length) {
        query = _stopControllers[index].text.trim();
      }
    }

    if (query.isEmpty && _recentSearches.isNotEmpty) {
      setState(() {
        _suggestions = List<SimpleLocation>.from(_recentSearches);
      });
    }
  }

  void _onTextChanged({required String targetField}) {
    // Strict focus check: Don't search if user isn't focused on this field
    // This prevents auto-filled location from triggering search/spinner
    bool hasFocus = false;
    if (targetField == 'origin') {
      hasFocus = _originFocusNode.hasFocus;
    } else if (targetField == 'destination') {
      hasFocus = _destinationFocusNode.hasFocus;
    } else if (targetField.startsWith('stop_')) {
      final index = int.parse(targetField.split('_')[1]);
      if (index < _stopFocusNodes.length) {
        hasFocus = _stopFocusNodes[index].hasFocus;
      }
    }

    if (!hasFocus) return;

    if (_isProgrammaticChange) return;
    
    setState(() {}); // Rebuild to show/hide clear button
    
    String query = '';
    if (targetField == 'origin') {
      query = _originController.text.trim();
    } else if (targetField == 'destination') {
      query = _destinationController.text.trim();
    } else if (targetField.startsWith('stop_')) {
      final index = int.parse(targetField.split('_')[1]);
      query = _stopControllers[index].text.trim();
    }
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (query.isNotEmpty) {
        _searchLocation(query, targetField);
      } else {
        if (mounted) {
          setState(() => _suggestions = List<SimpleLocation>.from(_recentSearches));
        }
      }
    });
  }

  Widget _buildInputs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Origin (Fixed)
          Hero(
            tag: 'search_destination_box',
            child: Material(
              type: MaterialType.transparency,
              child: _buildLocationCard(
                controller: _originController,
                focusNode: _originFocusNode,
                hint: 'Tu ubicación actual',
                icon: Icons.my_location_rounded,
                iconColor: Colors.blueAccent,
                targetField: 'origin',
                isDark: isDark,
                isFirst: true,
                isLast: false,
                showConnector: true,
              ),
            ),
          ),
          
          // Stops (Draggable)
          if (_stopControllers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8), // Gap for visuals
              // Use explicit Container constraints or shrinkWrap in a column
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _stopControllers.length,
                onReorder: _onReorderStops,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        elevation: 10,
                        color: Colors.transparent,
                        shadowColor: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  // Key is crucial for ReorderableListView
                  return Container(
                    key: ValueKey('stop_${_stopControllers[index].hashCode}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: _buildLocationCard(
                      controller: _stopControllers[index],
                      focusNode: _stopFocusNodes[index],
                      hint: 'Parada ${index + 1}',
                      icon: Icons.stop_circle_outlined,
                      iconColor: Colors.orangeAccent,
                      targetField: 'stop_$index',
                      isDark: isDark,
                      isFirst: false,
                      isLast: false,
                      showConnector: true,
                      isDraggable: true,
                      onRemove: () => _removeStop(index),
                    ),
                  );
                },
              ),
            ),

          // Destination (Fixed)
          // Add margin/connector gap
          Container(
            margin: EdgeInsets.only(top: _stops.isEmpty ? 8 : 0),
            child: _buildLocationCard(
              controller: _destinationController,
              focusNode: _destinationFocusNode,
              hint: '¿A dónde quieres ir?',
              icon: Icons.location_on_rounded,
              iconColor: AppColors.primary,
              targetField: 'destination',
              isDark: isDark,
              isFirst: false,
              isLast: true,
              showConnector: false, // Last one doesn't need downwards connector
            ),
          ),
        ],
      ),
    );
  }

  void _onReorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);

      final controller = _stopControllers.removeAt(oldIndex);
      _stopControllers.insert(newIndex, controller);

      final node = _stopFocusNodes.removeAt(oldIndex);
      _stopFocusNodes.insert(newIndex, node);
      
      // Update listeners logic if strictly bound to index (usually closures capture refs, but index calculation might be stale)
      // Since _onTextChanged parses the targetField 'stop_X', we might need to handle that carefully.
      // Actually, standard Controller listeners might bind to closure-based index. 
      // Safest is to rebuild listeners or rely on rebuilding the UI which assigns 'stop_$index' correctly in _buildLocationCard.
    });
  }

  Widget _buildLocationCard({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required String targetField,
    required bool isDark,
    required bool isFirst,
    required bool isLast,
    bool showConnector = false,
    bool isDraggable = false,
    VoidCallback? onRemove,
  }) {

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glass Card
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.darkCard.withValues(alpha: 0.6) 
                    : AppColors.lightCard.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon Column (Icon + Connector)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: iconColor),
                      ),
                      if (showConnector)
                        Container(
                          width: 2,
                          height: 24, // Visual connector extending down
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // Drag Handle (if draggable)
                  if (isDraggable)
                     Padding(
                       padding: const EdgeInsets.only(right: 12),
                       child: Icon(
                         Icons.drag_indicator_rounded,
                         color: isDark ? Colors.white24 : Colors.black26,
                         size: 20,
                       ),
                     ),

                  // Input Field - focus listener handles showing options
                  Expanded(
                    child: TextFormField(
                      focusNode: focusNode,
                      controller: controller,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: ((_isLoadingSuggestions && focusNode.hasFocus) || (targetField == 'origin' && _isGettingLocation))
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                                ),
                              ),
                            )
                          : null,
                      ),
                    ),
                  ),
                  
                  // Clear/Remove Buttons
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        if (targetField == 'origin') _selectedOrigin = null;
                        if (targetField == 'destination') _selectedDestination = null;
                        if (targetField.startsWith('stop_')) {
                           int idx = int.parse(targetField.split('_')[1]);
                           _stops[idx] = SimpleLocation(latitude: 0, longitude: 0, address: '');
                        }
                        setState(() => _suggestions = []);
                        // Request focus will trigger the listener which shows options
                        focusNode.requestFocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),

                  if (onRemove != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.my_location_rounded,
              label: 'Mi ubicación',
              onTap: () {
                // Determine which field to set
                String target = 'origin';
                if (_destinationFocusNode.hasFocus) target = 'destination';
                for (int i = 0; i < _stopFocusNodes.length; i++) {
                  if (_stopFocusNodes[i].hasFocus) target = 'stop_$i';
                }
                _setCurrentLocation(targetField: target);
              },
              isLoading: _isGettingLocation,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.map_rounded,
              label: 'Mapa',
              onTap: () => _openMapPicker(null),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark) {
    // Use explicit state variable for reliable focus detection
    final focusedField = _currentlyFocusedField;
    final activeQuery = focusedField == null
        ? ''
        : _getActiveQueryForField(focusedField);
    final showQuickActions = focusedField != null && activeQuery.isEmpty;
    final effectiveSuggestions = (_suggestions.isEmpty &&
            focusedField != null &&
            _recentSearches.isNotEmpty)
        ? _recentSearches
        : _suggestions;

    // If there is focus and NO search results (empty query), show default options
    if (effectiveSuggestions.isEmpty && focusedField != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildDefaultActionItem(
              isDark: isDark,
              icon: Icons.my_location_rounded,
              title: 'Usar mi ubicación actual',
              subtitle: 'Usa el GPS para localizarte',
              onTap: () {
                FocusScope.of(context).unfocus();
                _setCurrentLocation(targetField: focusedField);
              },
            ),
            _buildDefaultActionItem(
              isDark: isDark,
              icon: Icons.map_rounded,
              title: 'Seleccionar en el mapa',
              subtitle: 'Elige el punto exacto en el mapa',
              onTap: () {
                FocusScope.of(context).unfocus();
                _openMapPicker(focusedField);
              },
            ),
          ],
        ),
      );
    }

    if (effectiveSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: effectiveSuggestions.length + (showQuickActions ? 2 : 0),
        itemBuilder: (context, index) {
          if (showQuickActions && index == 0) {
            return _buildDefaultActionItem(
              isDark: isDark,
              icon: Icons.my_location_rounded,
              title: 'Usar mi ubicación actual',
              subtitle: 'Usa el GPS para localizarte',
              onTap: () {
                FocusScope.of(context).unfocus();
                _setCurrentLocation(targetField: focusedField);
              },
            );
          }

          if (showQuickActions && index == 1) {
            return _buildDefaultActionItem(
              isDark: isDark,
              icon: Icons.map_rounded,
              title: 'Seleccionar en el mapa',
              subtitle: 'Elige el punto exacto en el mapa',
              onTap: () {
                FocusScope.of(context).unfocus();
                _openMapPicker(focusedField);
              },
            );
          }

          final suggestionIndex = showQuickActions ? index - 2 : index;
          final suggestion = effectiveSuggestions[suggestionIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  // Use _lastFocusedField porque al tocar la sugerencia el foco ya se perdió
                  final targetField = _lastFocusedField;
                  
                  debugPrint('📍 Seleccionando sugerencia para campo: $targetField');
                  debugPrint('📍 Sugerencia: ${suggestion.address}');
                  
                  // Validar duplicado antes de asignar
                  if (_isLocationDuplicate(suggestion, targetField)) {
                    debugPrint('🚫 Validación bloqueó la selección');
                    return;
                  }

                  setState(() {
                    if (targetField == 'origin') {
                      _selectedOrigin = suggestion;
                      _originController.text = _formatAddressForDisplay(suggestion.address);
                    } else if (targetField == 'destination') {
                      _selectedDestination = suggestion;
                      _destinationController.text = _formatAddressForDisplay(suggestion.address);
                    } else if (targetField.startsWith('stop_')) {
                       final i = int.parse(targetField.split('_')[1]);
                       if (i < _stops.length) {
                         _stops[i] = suggestion;
                         _stopControllers[i].text = _formatAddressForDisplay(suggestion.address);
                       }
                    }
                    _suggestions = [];
                    FocusScope.of(context).unfocus();
                  });

                  if (targetField == 'destination' || targetField == 'origin') {
                    unawaited(_prefetchPreviewRoute());
                  }

                  unawaited(
                    _enrichLocationLabel(
                      targetField: targetField,
                      baseLocation: suggestion,
                    ),
                  );

                  unawaited(_saveRecentSearch(suggestion));
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.displaySubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getActiveQueryForField(String field) {
    if (field == 'origin') {
      return _originController.text.trim();
    }
    if (field == 'destination') {
      return _destinationController.text.trim();
    }
    if (field.startsWith('stop_')) {
      final index = int.tryParse(field.split('_')[1]);
      if (index != null && index >= 0 && index < _stopControllers.length) {
        return _stopControllers[index].text.trim();
      }
    }
    return '';
  }

  Widget _buildBottomButton(bool isDark) {
    if (!_isValid) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                // Validación final: Origen y Destino
                if (_selectedOrigin != null && _selectedDestination != null) {
                  // Usamos el helper que ya tiene la lógica de 200m y Strings
                  // Pasamos 'destination' para que compare contra origin
                  if (_isLocationDuplicate(_selectedDestination!, 'destination')) {
                    return; 
                  }
                }

                if (_selectedOrigin != null) {
                  unawaited(_saveRecentSearch(_selectedOrigin!));
                }
                if (_selectedDestination != null) {
                  unawaited(_saveRecentSearch(_selectedDestination!));
                }

                // Filter out empty stops just in case
                final validStops = _stops.where((s) => s.latitude != 0 && s.longitude != 0).toList();

                final preloadedRoute = await _prefetchPreviewRoute(
                  awaitCompletion: true,
                ).timeout(
                  const Duration(milliseconds: 500),
                  onTimeout: () => null,
                );

                if (!mounted) return;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripPreviewScreen(
                      origin: _selectedOrigin!,
                      destination: _selectedDestination!,
                      stops: validStops, // Pass stops
                      vehicleType: 'auto',
                      preloadedRoute: preloadedRoute,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Confirmar ubicaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setCurrentLocation({required String targetField}) async {
    if (_isGettingLocation) return;
    if (!mounted) return;

    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Wrap Geolocator calls in try-catch to avoid uncaught exceptions pausing the debugger
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (e) {
        debugPrint('Error checking location service: $e');
        serviceEnabled = false;
      }

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Habilita la ubicación en el dispositivo')),
          );
        }
        return; // Finally block will handle state reset
      }

      try {
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permiso de ubicación denegado')),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado permanentemente')),
          );
        }
        return;
      }

      // Safe position fetch with timeout
      final Position position = await Geolocator.getCurrentPosition(
        // Use default accuracy to be safe, or specify if needed
        desiredAccuracy: LocationAccuracy.high, 
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Timeout getting location');
        },
      );

      // Verify widget is still mounted after async gap before using context or setState
      if (!mounted) return;

      final normalized = await GooglePlacesService.reverseGeocodeLocationData(
        position: LatLng(position.latitude, position.longitude),
        sourceType: 'gps',
      );
      final address = await _reverseGeocode(position.latitude, position.longitude);
      
      final location = SimpleLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address:
            normalized?.address ??
            address ??
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        municipality: normalized?.municipality,
        department: normalized?.department,
        country: normalized?.country,
        placeId: normalized?.placeId,
        sourceType: normalized?.sourceType ?? 'gps',
        placeType: 'gps',
      );
      
      if (mounted) {
        // Validar duplicado ANTES de actualizar el estado
        if (_isLocationDuplicate(location, targetField)) {
          return;
        }

        setState(() {
          if (targetField == 'origin') {
            _selectedOrigin = location;
            _isProgrammaticChange = true;
            _originController.text = location.address;
            _isProgrammaticChange = false;
          } else if (targetField == 'destination') {
            _selectedDestination = location;
            _isProgrammaticChange = true;
            _destinationController.text = location.address;
            _isProgrammaticChange = false;
          } else if (targetField.startsWith('stop_')) {
             final index = int.parse(targetField.split('_')[1]);
             if (index < _stops.length) {
               _stops[index] = location;
               _isProgrammaticChange = true;
               _stopControllers[index].text = location.address;
               _isProgrammaticChange = false;
             }
          }
        });

        unawaited(
          _enrichLocationLabel(
            targetField: targetField,
            baseLocation: location,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error or timeout getting location: $e');
      if (mounted) {
        // Optional: show error to user
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener la ubicación')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final streetPlace = await MapboxService.reverseGeocodeStreetOnly(
        position: LatLng(lat, lon),
      );
      if (streetPlace != null) {
        final streetAddress = streetPlace.placeName.isNotEmpty
            ? streetPlace.placeName
            : streetPlace.text;
        final formattedStreet = _formatAddressForDisplay(streetAddress);
        if (formattedStreet.trim().isNotEmpty) {
          return formattedStreet;
        }
      }

      final place = await MapboxService.reverseGeocode(
        position: LatLng(lat, lon),
      );
      if (place != null) {
        // Formatear la dirección para que sea más legible
        final addressToFormat = place.placeName.isNotEmpty ? place.placeName : place.text;
        return _formatAddressForDisplay(addressToFormat);
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return null;
  }
  
  /// Formatea una dirección para mostrarla al usuario de forma limpia
  /// Remueve códigos postales, abreviaturas técnicas, etc.
  String _formatAddressForDisplay(String rawAddress) {
    if (rawAddress.isEmpty) return rawAddress;
    
    // Dividir la dirección en partes
    final parts = rawAddress.split(',').map((e) => e.trim()).toList();
    
    // Filtrar partes que contienen solo números (códigos postales)
    // o que son demasiado cortas/técnicas
    final cleanParts = parts.where((part) {
      // Remover códigos postales (ej: "050013", "110111")
      if (RegExp(r'^\d{5,6}$').hasMatch(part)) return false;
      
      // Remover partes que empiezan con código postal seguido de ciudad
      if (RegExp(r'^\d{5,6}\s+').hasMatch(part)) {
        // Obtener la parte después del código postal
        return false;
      }
      
      // Mantener partes válidas
      return part.isNotEmpty;
    }).map((part) {
      // Limpiar códigos postales dentro de la parte
      // Ej: "050013 Medellín" -> "Medellín"
      final cleaned = part.replaceAll(RegExp(r'^\d{5,6}\s+'), '');
      return cleaned.trim();
    }).where((part) => part.isNotEmpty).toList();
    
    // Limitar a 3 partes para no mostrar demasiado
    final limitedParts = cleanParts.take(3).toList();
    
    // Unir las partes filtradas
    return limitedParts.join(', ');
  }

  bool _isLocationDuplicate(SimpleLocation newLoc, String targetField) {
    debugPrint('🔍 _isLocationDuplicate llamada: targetField=$targetField');
    debugPrint('🔍 newLoc: ${newLoc.address} (${newLoc.latitude}, ${newLoc.longitude})');
    debugPrint('🔍 _selectedOrigin: ${_selectedOrigin?.address}');
    debugPrint('🔍 _selectedDestination: ${_selectedDestination?.address}');
    
    SimpleLocation? otherLoc;
    String otherName = '';

    if (targetField == 'origin') {
      otherLoc = _selectedDestination;
      otherName = 'destino';
    } else if (targetField == 'destination') {
      otherLoc = _selectedOrigin;
      otherName = 'origen';
    } else {
      debugPrint('⚠️ targetField no reconocido: $targetField');
      return false;
    }

    if (otherLoc == null) {
      debugPrint('⚠️ otherLoc es null - no hay comparación posible');
      return false;
    }
    
    debugPrint('🔍 Comparando contra: ${otherLoc.address} (${otherLoc.latitude}, ${otherLoc.longitude})');

    // 1. Check Address Equality (exact match)
    if (newLoc.address.trim() == otherLoc.address.trim()) {
      debugPrint('🚫 Ubicación duplicada por dirección exacta: ${newLoc.address}');
      _showDuplicateAlert(otherName);
      return true;
    }

    // 2. Check Distance
    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(newLoc.latitude, newLoc.longitude),
      LatLng(otherLoc.latitude, otherLoc.longitude),
    );
      
    debugPrint('📏 Distancia entre puntos: ${distance}m (Umbral: 50m)');

    if (distance < 50) {
      debugPrint('🚫 Ubicación duplicada por distancia (<50m)');
      _showDuplicateAlert(otherName);
      return true;
    }
    
    debugPrint('✅ Validación pasada - ubicaciones diferentes');
    return false;
  }

  void _showDuplicateAlert(String otherName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación duplicada'),
        content: Text(
          'La ubicación seleccionada es muy cercana al $otherName. Por favor elige un punto diferente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query, String targetField) async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      // Usar origen como punto de referencia para proximidad y distancias
      final referencePoint = _selectedOrigin != null 
          ? LatLng(_selectedOrigin!.latitude, _selectedOrigin!.longitude) 
          : null;
      
      final places = await _mapRemoteDataSource.searchNearbyPlaces(
        referencePoint?.latitude ?? 0,
        referencePoint?.longitude ?? 0,
        query,
        50,
        userId: _currentUserId,
      );
      
      // Convertir a SimpleLocation con distancias y formato mejorado
      final Distance distanceCalculator = const Distance();
      
      final results = places.map((place) {
        // Calcular distancia si tenemos punto de referencia
        double? distanceKm;
        if (referencePoint != null) {
          distanceKm = distanceCalculator.as(
            LengthUnit.Kilometer,
            referencePoint,
            LatLng(place.latitud, place.longitud),
          );
        }

        final fullAddress = place.direccion ?? '';
        final parts = fullAddress.split(',').map((e) => e.trim()).toList();
        final placeName = parts.isNotEmpty
            ? _formatAddressForDisplay(parts.first)
            : _formatAddressForDisplay(fullAddress);
        final subtitle = parts.length > 1
            ? _formatAddressForDisplay(parts.sublist(1).join(', '))
            : '';
        final cleanAddress = _formatAddressForDisplay(fullAddress);
        
        return SimpleLocation(
          latitude: place.latitud,
          longitude: place.longitud,
          address: cleanAddress,
          placeName: placeName,
          subtitle: subtitle,
          distanceKm: distanceKm,
          placeType: 'search',
          sourceType: 'search',
        );
      }).where((e) => e.latitude != 0 && e.longitude != 0).toList();
      
      // Ordenar por distancia (más cercanos primero)
      if (referencePoint != null) {
        results.sort((a, b) {
          final distA = a.distanceKm ?? double.infinity;
          final distB = b.distanceKm ?? double.infinity;
          return distA.compareTo(distB);
        });
      }
      
      // Limitar a 10 resultados para alinear con backend.
      final limitedResults = results.take(10).toList();
      
      if (mounted) {
        // Verificar si el campo que solicitó la búsqueda sigue siendo el enfocado
        bool isFieldFocused = false;
        if (targetField == 'origin' && _originFocusNode.hasFocus) {
          isFieldFocused = true;
        } else if (targetField == 'destination' && _destinationFocusNode.hasFocus) isFieldFocused = true;
        else if (targetField.startsWith('stop_')) {
          final index = int.parse(targetField.split('_')[1]);
          if (index < _stopFocusNodes.length && _stopFocusNodes[index].hasFocus) isFieldFocused = true;
        }

        if (isFieldFocused) {
          setState(() => _suggestions = limitedResults);
        }
      }
    } catch (e) {
      debugPrint('Mapbox search error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }

  Future<void> _openMapPicker(String? targetFieldOverride) async {
    final targetField = targetFieldOverride ?? _lastFocusedField;
    
    LatLng? initialPos;
    // Try to get position from currently selected field or origin
    if (_selectedOrigin != null) {
      initialPos = LatLng(_selectedOrigin!.latitude, _selectedOrigin!.longitude);
    }
    
    final result = await Navigator.push<SimpleLocation>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialPosition: initialPos,
        ),
      ),
    );

    if (result != null && mounted) {
      debugPrint('🗺️ Ubicación desde mapa para campo: $targetField');
      debugPrint('🗺️ Resultado: ${result.address}');
      
      if (_isLocationDuplicate(result, targetField)) {
        debugPrint('🚫 Validación bloqueó la selección desde mapa');
        return;
      }

      setState(() {
        if (targetField == 'origin') {
          _selectedOrigin = result;
          _originController.text = result.address;
        } else if (targetField == 'destination') {
          _selectedDestination = result;
          _destinationController.text = result.address;
        } else if (targetField.startsWith('stop_')) {
          final i = int.parse(targetField.split('_')[1]);
          if (i < _stops.length) {
            _stops[i] = result;
            _stopControllers[i].text = result.address;
          }
        }
        _suggestions = [];
      });

      unawaited(
        _enrichLocationLabel(
          targetField: targetField,
          baseLocation: result,
        ),
      );
    }
  }

  int _nextLabelResolveToken(String targetField) {
    final next = (_labelResolveTokens[targetField] ?? 0) + 1;
    _labelResolveTokens[targetField] = next;
    return next;
  }

  bool _isLabelResolveTokenCurrent(String targetField, int token) {
    return _labelResolveTokens[targetField] == token;
  }

  Future<void> _enrichLocationLabel({
    required String targetField,
    required SimpleLocation baseLocation,
  }) async {
    final token = _nextLabelResolveToken(targetField);

    try {
      final latLng = baseLocation.toLatLng();
      final landmark = await LandmarkResolverService.resolveNearestLandmark(
        position: latLng,
      );
      final poi = await PoiResolverService.resolveNearestPoi(
        position: latLng,
      );
      final textSearchPoi = await TextSearchResolverService
          .resolveNearestTextSearchPoi(
        position: latLng,
      );

      if (!mounted || !_isLabelResolveTokenCurrent(targetField, token)) {
        return;
      }

      final landmarkName = landmark?.name.trim() ?? '';
      final poiName = poi?.name.trim() ?? '';
      final textSearchPoiName = textSearchPoi?.name.trim() ?? '';

      if (landmarkName.isEmpty &&
          poiName.isEmpty &&
          textSearchPoiName.isEmpty) {
        return;
      }

      final label = resolveDisplayLabel(
        landmarkName: landmarkName.isNotEmpty ? landmarkName : null,
        poiName: poiName.isNotEmpty ? poiName : null,
        textSearchPoiName:
            textSearchPoiName.isNotEmpty ? textSearchPoiName : null,
        route: null,
        streetNumber: null,
        neighborhood: null,
        sublocality: null,
        locality: baseLocation.municipality,
        administrativeAreaLevel2: baseLocation.municipality,
        administrativeAreaLevel1: baseLocation.department,
        isUrban: true,
      );

      final enriched = baseLocation.copyWith(
        address: label.fullText,
        placeName: label.label,
        subtitle: label.subtitle,
        placeType: landmarkName.isNotEmpty
          ? 'landmark'
          : (poiName.isNotEmpty ? 'poi' : 'text_search_poi'),
        placeId:
            landmark?.placeId ??
            poi?.placeId ??
          textSearchPoi?.placeId ??
            baseLocation.placeId,
      );

      setState(() {
        if (targetField == 'origin') {
          _selectedOrigin = enriched;
          _isProgrammaticChange = true;
          _originController.text = _formatAddressForDisplay(enriched.address);
          _isProgrammaticChange = false;
        } else if (targetField == 'destination') {
          _selectedDestination = enriched;
          _isProgrammaticChange = true;
          _destinationController.text = _formatAddressForDisplay(enriched.address);
          _isProgrammaticChange = false;
        } else if (targetField.startsWith('stop_')) {
          final index = int.parse(targetField.split('_')[1]);
          if (index < _stops.length) {
            _stops[index] = enriched;
            _isProgrammaticChange = true;
            _stopControllers[index].text = _formatAddressForDisplay(enriched.address);
            _isProgrammaticChange = false;
          }
        }
      });
    } catch (e) {
      debugPrint('[GeoResolver] label_enrich_error field=$targetField error=$e');
    }
  }

  Widget _buildDefaultActionItem({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26, 
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
