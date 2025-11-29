import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:viax/src/global/services/nominatim_service.dart';
import 'package:viax/src/theme/app_colors.dart';
import 'trip_preview_screen.dart';
import '../../../../global/models/simple_location.dart';

class RequestTripScreen extends StatefulWidget {
  final String? initialSelection; // 'pickup' or 'destination'

  const RequestTripScreen({
    super.key, 
    this.initialSelection,
  });

  @override
  State<RequestTripScreen> createState() => _RequestTripScreenState();
}

class _RequestTripScreenState extends State<RequestTripScreen> {
  Position? _currentPosition;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  String? _pickupAddress;
  String? _destinationAddress;
  bool _isLoadingLocation = true;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<NominatimResult> _searchResults = [];
  Timer? _debounceTimer;
  
  // Estado de selección: 'pickup' o 'destination'
  String? _selectingFor;

  @override
  void initState() {
    super.initState();
    _selectingFor = widget.initialSelection;
    _getCurrentLocation();
    _setupSearchListeners();
    
    // Si se abre para seleccionar destino, enfocar el campo automáticamente
    if (widget.initialSelection == 'destination') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }
  
  void _setupSearchListeners() {
    _searchController.addListener(() {
      _debounceSearch(_searchController.text);
    });
  }

  void _debounceSearch(String query) {
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await NominatimService.searchAddress(
        query,
        proximity: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Error buscando lugares: $e');
      if (mounted) {
        setState(() => _searchResults = []);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _pickupLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Actualizar dirección legible para el origen
      // Llamamos siempre a reverse geocode para asegurarnos de que _pickupAddress se rellene
      _getReverseGeocode(LatLng(position.latitude, position.longitude), true);
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getReverseGeocode(LatLng position, bool isPickup) async {
    try {
      final place = await NominatimService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      
      if (place != null && mounted) {
        setState(() {
          if (isPickup) {
            _pickupAddress = place.getFormattedAddress();
          } else {
            _destinationAddress = place.getFormattedAddress();
          }
        });
      }
    } catch (e) {
      print('Error en geocodificación inversa: $e');
    }
  }

  void _selectPlace(NominatimResult place) {
    setState(() {
      if (_selectingFor == 'pickup') {
        _pickupLocation = place.coordinates;
        _pickupAddress = place.getFormattedAddress();
      } else if (_selectingFor == 'destination') {
        _destinationLocation = place.coordinates;
        _destinationAddress = place.getFormattedAddress();
      }
      
      // Limpiar búsqueda y foco
      _searchController.clear();
      _searchResults = [];
      _selectingFor = null;
    });
    
    _searchFocusNode.unfocus();
  }

  Future<void> _useCurrentLocationAsDestination() async {
    if (_currentPosition == null) return;
    final latlng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    setState(() {
      _destinationLocation = latlng;
      _destinationAddress = _pickupAddress ?? 'Ubicación actual';
      _selectingFor = null;
    });
    // Refresh destination address with reverse geocode to get full address
    await _getReverseGeocode(latlng, false);
    _searchFocusNode.unfocus();
  }

  void _confirmTrip() {
    if (_pickupLocation == null) {
      _showSnackBar('Selecciona un punto de origen');
      return;
    }
    if (_destinationLocation == null) {
      _showSnackBar('Selecciona un punto de destino');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripPreviewScreen(
          origin: SimpleLocation(
            latitude: _pickupLocation!.latitude,
            longitude: _pickupLocation!.longitude,
            address: _pickupAddress ?? 'Origen',
          ),
          destination: SimpleLocation(
            latitude: _destinationLocation!.latitude,
            longitude: _destinationLocation!.longitude,
            address: _destinationAddress ?? 'Destino',
          ),
          vehicleType: 'moto',
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          '¿A dónde vas?',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Campo de origen
                _buildLocationField(
                  icon: Icons.my_location,
                  iconColor: AppColors.primary,
                  label: 'Origen',
                  value: _pickupAddress,
                  placeholder: 'Seleccionar origen',
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectingFor = 'pickup';
                      _searchController.text = '';
                      _searchResults = [];
                    });
                    _searchFocusNode.requestFocus();
                  },
                  onClear: _pickupLocation != null
                      ? () {
                          setState(() {
                            _pickupLocation = null;
                            _pickupAddress = null;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                
                // Campo de destino (Hero)
                Hero(
                  tag: 'search_destination_box',
                  child: Material(
                    color: Colors.transparent,
                    child: _buildLocationField(
                      icon: Icons.location_on,
                      iconColor: AppColors.error,
                      label: 'Destino',
                      value: _destinationAddress,
                      placeholder: '¿A dónde vamos?',
                      isDark: isDark,
                      isDestination: true, // Flag especial para el campo de destino
                      onTap: () {
                        setState(() {
                          _selectingFor = 'destination';
                          _searchController.text = '';
                          _searchResults = [];
                        });
                        _searchFocusNode.requestFocus();
                      },
                      onClear: _destinationLocation != null
                          ? () {
                              setState(() {
                                _destinationLocation = null;
                                _destinationAddress = null;
                              });
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Área de contenido dinámico: Resultados de búsqueda o Accesos rápidos
          Expanded(
            child: _selectingFor != null
                ? _buildSearchResults(isDark, textColor)
                : _buildQuickAccessAndSuggestions(isDark, textColor),
          ),
        ],
      ),
      bottomNavigationBar: _pickupLocation != null && _destinationLocation != null && _selectingFor == null
          ? ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkCard : Colors.white).withOpacity(0.9),
                    border: Border(
                      top: BorderSide(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: _confirmTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirmar ubicaciones',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLocationField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String? value,
    required String placeholder,
    required bool isDark,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isDestination = false,
  }) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final isEditing = _selectingFor == (isDestination ? 'destination' : 'pickup');
    
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Mismo padding que Home
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100], // Mismo color que Home
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEditing 
                    ? AppColors.primary.withOpacity(0.5) 
                    : AppColors.primary.withOpacity(0.06), // Mismo borde que Home
                width: isEditing ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isEditing) ...[
                  // Si estamos editando, mostramos el input real
                   Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16, // Mismo tamaño que Home
                      ),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[500], // Mismo color que Home
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                      child: Icon(Icons.close, color: textColor.withOpacity(0.5), size: 20),
                    ),
                ] else ...[
                  // Vista estática (simula el input de Home)
                  if (isDestination) ...[
                    // Icono de búsqueda para destino (igual que Home)
                    Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white70 : AppColors.primary,
                    ),
                  ] else ...[
                    // Punto para origen
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: TextStyle(
                        color: value != null ? textColor : (isDark ? Colors.white54 : Colors.grey[500]),
                        fontSize: 16,
                        fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (value != null && onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close, color: textColor.withOpacity(0.5), size: 20),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark, Color textColor) {
    final hasCurrent = _currentPosition != null;
    if (_searchResults.isEmpty && !hasCurrent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasCurrent) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _useCurrentLocationAsDestination(),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ubicación actual',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    // address removed by design to match Home's compact style
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Icon(Icons.search, size: 64, color: textColor.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              'Escribe para buscar...',
              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length + (hasCurrent ? 1 : 0),
      itemBuilder: (context, index) {
        // If we have current position and index == 0, show a special tile to use current location
        if (hasCurrent && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _useCurrentLocationAsDestination(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.my_location, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ubicación actual',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                // address removed by design to match Home's compact style
                              ],
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
        // otherwise map to search results. Adjust index when we included the current tile
        final resultIndex = hasCurrent ? index - 1 : index;
        final place = _searchResults[resultIndex];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectPlace(place),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.getShortName(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place.getFormattedAddress(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.5),
                                ),
                                maxLines: 2,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessAndSuggestions(bool isDark, Color textColor) {
    return Column(
      children: [
        // Accesos rápidos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildQuickAccess(Icons.my_location, 'Ubicación', isDark, onTap: _useCurrentLocationAsDestination),
              const SizedBox(width: 12),
              _buildQuickAccess(Icons.home, 'Casa', isDark),
              const SizedBox(width: 12),
              _buildQuickAccess(Icons.work, 'Trabajo', isDark),
              
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Aquí podrías poner historial reciente
        Expanded(
          child: Center(
            child: Text(
              'Tus lugares recientes aparecerán aquí',
              style: TextStyle(color: textColor.withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccess(IconData icon, String label, bool isDark, {VoidCallback? onTap}) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
