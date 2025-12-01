import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../../global/models/simple_location.dart';
import '../../../../theme/app_colors.dart';

/// Widget de mapa con selector de ubicación estilo DiDi/Uber
/// Se muestra como un DraggableScrollableSheet expandible
class MapLocationPickerSheet extends StatefulWidget {
  final SimpleLocation? initialLocation;
  final LatLng? userLocation;
  final String title;
  final Color accentColor;
  final Function(SimpleLocation) onLocationSelected;
  final VoidCallback? onClose;

  const MapLocationPickerSheet({
    super.key,
    this.initialLocation,
    this.userLocation,
    this.title = 'Seleccionar ubicación',
    this.accentColor = const Color(0xFF2196F3), // AppColors.primary
    required this.onLocationSelected,
    this.onClose,
  });

  @override
  State<MapLocationPickerSheet> createState() => _MapLocationPickerSheetState();
}

class _MapLocationPickerSheetState extends State<MapLocationPickerSheet>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late LatLng _currentCenter;
  String _address = 'Cargando dirección...';
  bool _isLoadingAddress = false;
  bool _isMoving = false;
  bool _isMapReady = false;
  
  late AnimationController _pinAnimationController;
  late Animation<double> _pinBounceAnimation;
  late Animation<double> _pinShadowAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    
    // Inicializar posición
    if (widget.initialLocation != null) {
      _currentCenter = widget.initialLocation!.toLatLng();
      _address = widget.initialLocation!.address;
    } else if (widget.userLocation != null) {
      _currentCenter = widget.userLocation!;
    } else {
      _currentCenter = const LatLng(6.2442, -75.5812); // Default Medellín
    }
    
    _setupAnimations();
  }

  void _setupAnimations() {
    // Animación del pin cuando se mueve
    _pinAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pinBounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _pinShadowAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(
        parent: _pinAnimationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Pulso del marcador del usuario
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _pulseController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getAddress(LatLng point) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      setState(() => _isLoadingAddress = true);
      
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}',
        );
        final resp = await http.get(url, headers: {
          'User-Agent': 'ViaxApp/1.0 (student_project_demo)',
        });
        
        if (resp.statusCode == 200 && mounted) {
          final data = json.decode(resp.body);
          setState(() {
            _address = data['display_name'] ?? 'Dirección desconocida';
          });
        }
      } catch (e) {
        debugPrint('Error fetching address: $e');
        if (mounted) {
          setState(() => _address = 'Error obteniendo dirección');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingAddress = false);
        }
      }
    });
  }

  void _centerOnUserLocation() async {
    HapticFeedback.mediumImpact();
    
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentCenter = latLng;
      });
      
      _mapController.move(latLng, 17);
      _getAddress(latLng);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _confirmLocation() {
    HapticFeedback.mediumImpact();
    
    final location = SimpleLocation(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
      address: _address,
    );
    
    widget.onLocationSelected(location);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          Expanded(
            child: Stack(
              children: [
                _buildMap(isDark),
                _buildCenterPin(),
                _buildMyLocationButton(isDark),
              ],
            ),
          ),
          _buildBottomPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onClose?.call();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentCenter,
          initialZoom: 16.0,
          onMapReady: () {
            setState(() => _isMapReady = true);
            _getAddress(_currentCenter);
          },
          onPositionChanged: (position, hasGesture) {
            if (hasGesture && _isMapReady) {
              if (!_isMoving) {
                _pinAnimationController.forward();
              }
              setState(() {
                _isMoving = true;
                _currentCenter = position.center;
              });
            }
          },
          onMapEvent: (event) {
            if (event is MapEventMoveEnd && _isMapReady) {
              _pinAnimationController.reverse();
              setState(() => _isMoving = false);
              _getAddress(_currentCenter);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: isDark
                ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.example.viax',
          ),
          // Marcador de ubicación del usuario si existe
          if (widget.userLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.userLocation!,
                  width: 60,
                  height: 60,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulso exterior
                          Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(
                                  0.3 * (1.5 - _pulseAnimation.value),
                                ),
                              ),
                            ),
                          ),
                          // Punto central
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCenterPin() {
    return Center(
      child: AnimatedBuilder(
        animation: _pinAnimationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _pinBounceAnimation.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                // Flecha hacia abajo
                CustomPaint(
                  size: const Size(20, 12),
                  painter: _TrianglePainter(color: widget.accentColor),
                ),
                const SizedBox(height: 4),
                // Sombra del pin
                Transform.scale(
                  scale: _pinShadowAnimation.value,
                  child: Container(
                    width: 12,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Offset para centrar visualmente
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyLocationButton(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: GestureDetector(
        onTap: _centerOnUserLocation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location_rounded,
            color: widget.accentColor,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: widget.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación seleccionada',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isMoving || _isLoadingAddress
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.accentColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isMoving ? 'Moviendo...' : 'Buscando...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _address,
                              key: ValueKey(_address),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.grey[900],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isMoving || _isLoadingAddress ? null : _confirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                disabledBackgroundColor: widget.accentColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirmar ubicación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter para el triángulo del pin
class _TrianglePainter extends CustomPainter {
  final Color color;
  
  _TrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mostrar el sheet de selección de ubicación en mapa
Future<SimpleLocation?> showMapLocationPicker({
  required BuildContext context,
  SimpleLocation? initialLocation,
  LatLng? userLocation,
  String title = 'Seleccionar ubicación',
  Color accentColor = const Color(0xFF2196F3), // AppColors.primary
}) async {
  SimpleLocation? result;
  
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) => MapLocationPickerSheet(
      initialLocation: initialLocation,
      userLocation: userLocation,
      title: title,
      accentColor: accentColor,
      onLocationSelected: (location) {
        result = location;
        Navigator.pop(context);
      },
    ),
  );
  
  return result;
}
