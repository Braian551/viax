import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/map_provider.dart';
import '../widgets/osm_map_widget.dart';
import '../../../../global/services/auth/user_service.dart';
import '../../../../global/models/simple_location.dart';

class LocationPickerScreen extends StatefulWidget {
  final String? initialAddress;
  final LatLng? initialLocation;
  final String screenTitle;
  final bool showConfirmButton;

  const LocationPickerScreen({
    super.key,
    this.initialAddress,
    this.initialLocation,
    this.screenTitle = 'Seleccionar ubicación',
    this.showConfirmButton = true,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editableAddressController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _pinAnimationController;
  late AnimationController _pulseAnimationController;
  
  late Animation<double> _pinBounceAnimation;
  late Animation<double> _pulseAnimation;
  
  Timer? _mapMoveTimer;
  Timer? _moveDebounce;
  bool _isSearchFocused = false;
  bool _confirmed = false;
  bool _isMapMoving = false;
  // ignore: unused_field
  LatLng? _mapCenterCache;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _setupAnimations();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _setupAnimations() {
    // Animación del pin al mover el mapa
    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _pinBounceAnimation = Tween<double>(
      begin: 0.0,
      end: -12.0,
    ).animate(CurvedAnimation(
      parent: _pinAnimationController,
      curve: Curves.easeOutBack,
    ));
    
    // Animación de pulso para el pin
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _onSearchFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  void _initializeLocation() {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    if (widget.initialLocation != null) {
      mapProvider.selectLocation(widget.initialLocation!);
    }
    
    if (widget.initialAddress != null) {
      _searchController.text = widget.initialAddress!;
      _editableAddressController.text = widget.initialAddress!;
    }
    
    if (mapProvider.selectedAddress != null) {
      _editableAddressController.text = mapProvider.selectedAddress!;
    }

    if (widget.initialAddress == null && widget.initialLocation == null) {
      _loadSavedProfileLocation();
    }
  }

  void _loadSavedProfileLocation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = await UserService.getSavedSession();
      if (session != null && mounted) {
        final id = session['id'] as int?;
        final email = session['email'] as String?;
        final profile = await UserService.getProfile(userId: id, email: email);
        if (profile != null && profile['success'] == true) {
          final location = profile['location'];
          if (location != null) {
            final lat = double.tryParse(location['latitud'] ?? '') ?? 
                (location['latitud'] is num ? (location['latitud'] as num).toDouble() : null);
            final lng = double.tryParse(location['longitud'] ?? '') ?? 
                (location['longitud'] is num ? (location['longitud'] as num).toDouble() : null);
            final dir = location['direccion'] as String?;
            
            final mapProvider = Provider.of<MapProvider>(context, listen: false);
            if (lat != null && lng != null) {
              await mapProvider.selectLocation(LatLng(lat, lng));
            }
            if (dir != null && dir.isNotEmpty) {
              mapProvider.setSelectedAddress(dir);
              _editableAddressController.text = dir;
              _searchController.text = dir;
            }
          }
        }
      }
    });
  }

  void _onSearch(String query) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (query.length >= 3) {
      mapProvider.searchAddress(query);
    }
  }

  void _onSearchResultTap(SimpleLocation result) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    mapProvider.selectSearchResult(result);
    _searchController.text = result.address;
    _editableAddressController.text = result.address;
    _searchFocusNode.unfocus();
  }

  void _onMapMoveStart() {
    setState(() {
      _isMapMoving = true;
    });
    _mapMoveTimer?.cancel();
    _pinAnimationController.forward();
  }

  void _onMapMoveEnd() {
    _mapMoveTimer?.cancel();
    _mapMoveTimer = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _isMapMoving = false;
      });
      _pinAnimationController.reverse();
    });
  }

  void _handleMapMovedDebounced(LatLng center) {
    _moveDebounce?.cancel();
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    _moveDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        await mapProvider.selectLocation(center);
        if (mounted) {
          setState(() {
            _editableAddressController.text = mapProvider.selectedAddress ?? _editableAddressController.text;
            _searchController.text = _editableAddressController.text;
          });
        }
      } catch (_) {}
    });
  }

  void _saveLocation() async {
    final newAddress = _editableAddressController.text.trim();
    if (newAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección vacía'))
      );
      return;
    }

    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    
    final found = await mapProvider.geocodeAndSelect(newAddress);
    if (!found && mapProvider.selectedLocation != null) {
      await mapProvider.selectLocation(mapProvider.selectedLocation!);
    }

    final session = await UserService.getSavedSession();
    bool saved = false;
    if (session != null) {
      final uid = session['id'] as int?;
      saved = await UserService.updateUserLocation(
        userId: uid,
        address: newAddress,
        latitude: mapProvider.selectedLocation?.latitude,
        longitude: mapProvider.selectedLocation?.longitude,
        city: mapProvider.selectedCity,
        state: mapProvider.selectedState,
      );
    }

    if (saved) {
      setState(() {
        _confirmed = true;
      });
      _showConfirmedSnack();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar en el servidor'))
      );
    }
  }

  void _showConfirmedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.black),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ubicación guardada exitosamente',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFFF00),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    // Filter out duplicate locations by address if needed, or just display as is
    // Often addresses might be duplicated if using multiple sources or history
    final uniqueResults = <String, SimpleLocation>{};
    for (var r in mapProvider.searchResults) {
      uniqueResults[r.address] = r;
    }
    final displayResults = uniqueResults.values.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.screenTitle,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // Mapa con bordes redondeados
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: OSMMapWidget(
                      initialLocation: widget.initialLocation,
                      interactive: true,
                      onLocationSelected: (location) async {
                        _mapCenterCache = location;
                        await mapProvider.selectLocation(location);
                        _editableAddressController.text = mapProvider.selectedAddress ?? _editableAddressController.text;
                        _searchController.text = _editableAddressController.text;
                      },
                      onMapMoved: (center) {
                        _mapCenterCache = center;
                        _handleMapMovedDebounced(center);
                      },
                      onMapMoveStart: _onMapMoveStart,
                      onMapMoveEnd: _onMapMoveEnd,
                      showMarkers: false,
                    ),
                  ),
                ),
              ),
            ),

            // Barra de búsqueda moderna con efecto glass y animaciones suaves
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isSearchFocused 
                      ? const Color(0xFFFFFF00).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.15),
                    width: _isSearchFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: _isSearchFocused ? 24 : 16,
                      offset: const Offset(0, 8),
                      spreadRadius: _isSearchFocused ? 2 : 0,
                    ),
                    if (_isSearchFocused)
                      BoxShadow(
                        color: const Color(0xFFFFFF00).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.search_rounded,
                            color: _isSearchFocused 
                              ? const Color(0xFFFFFF00)
                              : Colors.white.withValues(alpha: 0.6),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearch,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar dirección...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: 1.0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  mapProvider.clearSearch();
                                  _searchFocusNode.unfocus();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Pin de ubicación profesional estilo Uber con animaciones suaves
            Center(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pinAnimationController, _pulseAnimationController]),
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _pinBounceAnimation.value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pin moderno inspirado en Uber
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Pulso animado de fondo (solo cuando no se mueve el mapa)
                              if (!_isMapMoving)
                                Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              
                              // Pin principal
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                      spreadRadius: 1,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFF00),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFFF00).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Indicador de punta (punto de referencia exacto)
                              Positioned(
                                bottom: -8,
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Sombra debajo del pin
                          const SizedBox(height: 4),
                          Transform.scale(
                            scale: _isMapMoving ? 0.8 : 1.0,
                            child: Container(
                              width: 24,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Tarjeta inferior profesional con efecto glass
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _confirmed 
                      ? const Color(0xFFFFFF00).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 2,
                    ),
                    if (_confirmed)
                      BoxShadow(
                        color: const Color(0xFFFFFF00).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de dirección mejorado
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _editableAddressController,
                        readOnly: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 8),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: const Color(0xFFFFFF00),
                              size: 22,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          hintText: 'Dirección seleccionada...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          filled: false,
                        ),
                      ),
                    ),
                    
                    // Indicador de estado confirmado
                    if (_confirmed)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFF00).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFFF00).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFF00),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ubicación confirmada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Botones de acción
                    if (!_confirmed)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            // Botón de guardar (principal)
                            Expanded(
                              flex: 3,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: 1.0,
                                child: ElevatedButton(
                                  onPressed: _saveLocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFFF00),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    shadowColor: const Color(0xFFFFFF00).withValues(alpha: 0.4),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Guardar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Botón de limpiar
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  mapProvider.clearSelection();
                                  _editableAddressController.clear();
                                  _searchController.clear();
                                  setState(() {
                                    _confirmed = false;
                                  });
                                },
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 24,
                                ),
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Resultados de búsqueda con diseño profesional
            if (displayResults.isNotEmpty && _isSearchFocused)
              Positioned(
                top: 84,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: displayResults.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        itemBuilder: (context, index) {
                          final r = displayResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              r.address,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () => _onSearchResultTap(r),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
